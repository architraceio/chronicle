# Chronicle development tasks
ENGINE_FILES := packages/engine/chronicle-hook packages/engine/judge-prompt.md
HARNESSES    := claude codex gemini cursor copilot
APM          ?= uvx --from apm-cli==0.39.0 apm
SHELLCHECK   ?= $(shell command -v shellcheck 2>/dev/null || echo uvx --from shellcheck-py shellcheck)

.PHONY: all sync check-sync lint test test-apm

all: sync check-sync lint test

sync: ## copy the shared engine into every hook package
	@for h in $(HARNESSES); do \
	  mkdir -p packages/hooks-$$h/.apm/hooks/scripts; \
	  cp $(ENGINE_FILES) packages/hooks-$$h/.apm/hooks/scripts/; \
	  chmod +x packages/hooks-$$h/.apm/hooks/scripts/chronicle-hook; \
	done; echo "engine synced to: $(HARNESSES)"

check-sync: ## fail if a bundled engine copy drifted from packages/engine
	@for h in $(HARNESSES); do for f in $(ENGINE_FILES); do \
	  cmp -s $$f packages/hooks-$$h/.apm/hooks/scripts/$$(basename $$f) \
	    || { echo "drift: hooks-$$h/$$(basename $$f) (run make sync)"; exit 1; }; \
	done; done; echo "engine copies in sync"

lint:
	$(SHELLCHECK) packages/engine/chronicle-hook packages/core/.apm/skills/chronicle-adr/scripts/chronicle-adr tests/*.sh

test: ## unit tests for the engine and chronicle-adr
	bash tests/run.sh

test-apm: ## install the package into a fixture project with APM and check the result
	APM="$(APM)" bash tests/apm-install.sh
