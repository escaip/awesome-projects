---
name: Catalog Audit Accept
on:
  slash_command:
    name: accept
  roles: [admin, maintain]
permissions:
  contents: read
  issues: read
tools:
  edit:
  bash: ["cat", "grep", "yq", "date", "sort", "uniq"]
  github:
    toolsets: [repos, issues]
safe-outputs:
  create-pull-request:
    title-prefix: "[catalog-audit] "
    labels: [catalog, automated]
    draft: false
    allowed-files:
      - workloads/audit-allowlist.yaml
    protected-files: blocked
    if-no-changes: warn
  add-comment:
    max: 1
  noop:
---

# Catalog Audit Accept

You record maintainer decisions to permanently accept (suppress) findings from the Catalog Dedupe Audit.

This workflow is triggered when someone comments `/accept ...` on an issue. The `roles` gate already ensures only maintainers (admin or maintain) can trigger it, so treat the comment as an authorized decision.

## Goal

Turn one `/accept` comment into one pull request that appends the accepted finding(s) to `workloads/audit-allowlist.yaml`, so the next audit run stops reporting them.

## Context To Read

1. Read the triggering comment body, its author, the issue number, the issue title, the issue labels, and the issue body.
2. Confirm this is a catalog audit issue: its title starts with `[catalog-audit] ` or it carries the `catalog` and `automated` labels, and its body contains a findings table with a **Finding ID** column. If it is not a catalog audit issue, do nothing except call `noop` explaining that `/accept` only applies to catalog audit issues.
3. Read the current `workloads/audit-allowlist.yaml`.

## Parsing The Command

The comment contains a command of the form:

```
/accept <finding-id>[, <finding-id> ...] — <reason> [until=YYYY-MM-DD]
```

- **Finding IDs** are `check:subject` tokens (e.g. `duplicate-url:owner/repo`, `inaccessible-repo:owner/repo`, `invalid-schema:catalog`). One or more, comma- or space-separated. A maintainer may also paste an ID with surrounding backticks; strip them.
- **Reason** is the free text after an em dash `—`, a hyphen `-`, or a colon following the IDs. The reason is required; if it is missing, ask for it (see Outcomes).
- **until** is optional. If present, capture the `YYYY-MM-DD` value as the expiry.
- `check` must be one of: `invalid-schema`, `duplicate-url`, `missing-field`, `empty-field`, `unknown-category`, `group-category-mismatch`, `non-canonical-url`, `inaccessible-repo`, `generic-tags`. Reject IDs whose check is not in this list.

Validate each finding ID against the issue's findings table when possible: prefer IDs that appear in the **Finding ID** column. If a requested ID is not in the table, still accept it if it is well-formed (valid `check` and a non-empty `subject`), but note in your confirmation comment that it was not found in the current findings.

## Updating The Allowlist

Edit only `workloads/audit-allowlist.yaml`.

For each valid finding ID, add a record under `accepted`:

```yaml
accepted:
  - check: duplicate-url
    subject: "owner/repo"
    reason: "<reason from the comment>"
    accepted_by: "@<comment author login>"
    accepted_at: "<today, from `date +%F`>"
    until: "<expiry if provided, otherwise omit this key>"
```

Rules:

- Set `accepted_at` to today's date using `date +%F`.
- Set `accepted_by` to the comment author's GitHub handle.
- Normalize `subject` to lowercase `owner/repo` for repository-scoped checks; keep descriptors like `catalog` as-is.
- If `accepted` is currently `[]`, replace it with a proper list.
- **Do not duplicate** an existing record with the same `check` and `subject`. If one already exists, update its `reason`, `accepted_by`, `accepted_at`, and `until` instead of adding a second record.
- Preserve the file's header comments and formatting.

## Outcomes

If at least one valid finding was accepted:

1. Edit `workloads/audit-allowlist.yaml`.
2. Create a pull request titled like `[catalog-audit] Accept N finding(s) from #<issue number>`. In the body, list each accepted finding ID with its reason and expiry, name the maintainer who requested it, and include `Ref #<issue number>` (do not use `Closes`, since the audit issue should stay open until the audit re-runs).
3. Comment on the issue confirming which findings were accepted, the expiry (if any), and the pull request link. Mention any requested IDs that were skipped and why.

If the comment is on a catalog audit issue but no valid finding ID or no reason could be parsed:

1. Do not edit files.
2. Comment with the exact correct syntax and an example using a real Finding ID from this issue's table.

If this is not a catalog audit issue, or there is otherwise nothing to do, call `noop` with a short explanation.
