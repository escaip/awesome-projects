---
name: Catalog Dedupe Audit
on:
  schedule: bi-weekly
  workflow_dispatch:
permissions:
  contents: read
  issues: read
tools:
  bash: ["cat", "grep", "yq", "sort", "uniq", "wc", "date"]
  github:
    toolsets: [repos, issues]
safe-outputs:
  create-issue:
    title-prefix: "[catalog-audit] "
    labels: [catalog, automated]
    close-older-issues: true
    max: 1
  noop:
---

# Catalog Dedupe Audit

You are the catalog quality auditor for Europe South - Awesome Projects.

## Goal

Audit `workloads/repositories.yaml` and open exactly one issue when the catalog needs maintainer attention. If the catalog is healthy, call `noop` with a concise success message.

## Checks

Review `workloads/repositories.yaml` for the following. Each check has a stable ID in parentheses; use that ID when applying the allowlist below.

1. Invalid YAML or unexpected schema. (`invalid-schema`)
2. Duplicate repository URLs, case-insensitive and ignoring trailing slashes. (`duplicate-url`)
3. Entries missing any required field: `name`, `url`, `description`, `categories`, `group`, or `tags`. (`missing-field`)
4. Empty descriptions, empty category lists, empty tag lists, or blank tag values. (`empty-field`)
5. Unknown categories. Allowed categories are `apps`, `infra`, `data`, and `security`. (`unknown-category`)
6. Group/category mismatches: (`group-category-mismatch`)
   - `GitHub Related` and `AI Related` entries should include `apps` unless there is a clear reason.
   - `Infrastructure` entries should include `infra` or `security`.
   - `Data Engineering` entries should include `data`.
7. GitHub URLs that are inaccessible, archived, private, deleted, or not in canonical `https://github.com/owner/repo` form. (`non-canonical-url` for the canonical-form problem; `inaccessible-repo` for inaccessible, archived, private, or deleted repositories.)
8. Tags that are overly generic, duplicated within an entry, or inconsistent with nearby entries. (`generic-tags`)

## Finding Identity

Every finding has a stable ID of the form `check:subject`:

- `check` is the stable check ID listed above (e.g. `duplicate-url`, `inaccessible-repo`, `invalid-schema`).
- `subject` identifies what the finding is about:
  - Use `owner/repo` (lowercase, from the canonical GitHub URL) for findings tied to one repository entry.
  - Use a short descriptor such as `catalog` for catalog-wide or schema-level findings that are not tied to a single entry.

The same finding must always produce the same ID across runs, so an acceptance keeps matching it. Examples: `duplicate-url:owner/repo`, `inaccessible-repo:owner/repo`, `invalid-schema:catalog`.

## Allowlisted Exceptions

Findings can be suppressed in two ways. A finding is suppressed if it matches **either** mechanism; do not report a suppressed finding and do not count it toward the issue-creation threshold.

### 1. Central allowlist (`workloads/audit-allowlist.yaml`)

Read `workloads/audit-allowlist.yaml`. It contains an `accepted` list of records:

```yaml
accepted:
  - check: duplicate-url
    subject: "owner/repo"      # or '*' to suppress this check everywhere
    reason: "..."
    accepted_by: "@maintainer"
    accepted_at: "2026-06-30"
    until: "2026-12-31"         # optional
```

Suppress a finding when an `accepted` record matches it:

- `check` equals the finding's check ID, **and**
- `subject` equals the finding's subject (case-insensitive), or `subject` is `*` (matches any subject for that check), **and**
- the record has not expired: either `until` is absent, or today's date (use `date +%F`) is on or before `until`.

Ignore records whose `until` date is in the past — report those findings again so they can be re-reviewed.

### 2. Per-entry `audit.ignore` (in `workloads/repositories.yaml`)

An entry may opt out of specific checks by including an `audit` block, for example:

```yaml
    audit:
      ignore:
        - non-canonical-url
      reason: "Why this exception is intentional."
```

When evaluating each entry:

- If a finding's check ID appears in that entry's `audit.ignore` list, **suppress the finding**.
- Apply suppression per check ID only. The entry must still be flagged for any other check whose ID is not listed.
- The `audit` block itself is valid schema. Never report it as an unexpected field under `invalid-schema`.
- Treat a missing or empty `audit.ignore` list as "no exceptions".

## Issue Creation Rules

Create an issue only when there are actionable findings.

The issue title should be specific, for example:

`[catalog-audit] Catalog health findings for YYYY-MM-DD`

The issue body must include:

- A short summary count of findings.
- A grouped findings table with these columns: **Finding ID** (`check:subject`), repository name, URL, problem, and recommended fix.
- An "Accepting findings" note telling maintainers they can suppress any finding permanently by commenting on this issue:
  `/accept <finding-id> — <reason>` (optionally `until=YYYY-MM-DD` to make it expire). Multiple IDs may be comma-separated. This records the acceptance in `workloads/audit-allowlist.yaml` so the finding is not reported again.
- A short note that this was produced by the scheduled catalog audit.

Do not create more than one issue. The `create-issue` safe output is configured to close older open issues from this same workflow, so the latest report remains canonical.

## No Findings

If no action is needed, you MUST call the `noop` tool with a message like:

`No action needed: catalog audit found no duplicate URLs, schema issues, or inaccessible repositories.`
