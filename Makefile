YAML_SRC  := workloads/repositories.yaml
JSON_OUT  := web/repositories.json
SITE_DIR  := _site

.PHONY: build site clean

build: $(JSON_OUT)

$(JSON_OUT): $(YAML_SRC)
	python3 -c 'import yaml,json,pathlib; d=yaml.safe_load(open("$(YAML_SRC)")); open("$(JSON_OUT)","w").write(json.dumps(d,ensure_ascii=False,indent=2))'
	@echo "Generated $(JSON_OUT)"

site: build
	mkdir -p $(SITE_DIR)
	cp web/index.html $(SITE_DIR)/index.html
	cp $(JSON_OUT) $(SITE_DIR)/repositories.json
	@echo "Site assembled in $(SITE_DIR)/"

clean:
	rm -f $(JSON_OUT)
	rm -rf $(SITE_DIR)
