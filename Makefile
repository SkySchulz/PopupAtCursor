# Thin wrapper around build-tools/. The scripts do the work and run on their own.

ADDON   := PopupAtCursor
TOC     := $(ADDON).toc
ADDONS  ?= $(or $(WOW_ADDONS),/Applications/World of Warcraft/_retail_/Interface/AddOns)
LUAC    ?= luac
LUACHECK ?= luacheck
# A literal "#". Writing \# inside $(shell) or a recipe breaks on GNU make 4.3+
# (the backslash is kept, and newer grep warns about it); make 3.81 needs it.
HASH    := \#
VERSION := $(shell sed -n 's/^$(HASH)$(HASH) Version:[[:space:]]*//p' $(TOC) | tr -d '\r' | head -n1)
# .lua files the .toc loads (non-blank lines that are not # comments)
LUA     := $(filter %.lua,$(shell grep -v -e '^$(HASH)' -e '^[[:space:]]*$$' $(TOC) | tr -d '\r' | tr '\\\\' /))

.DEFAULT_GOAL := help
.PHONY: help lint package install clean

help: ## List targets
	@grep -E '^[a-z]+:.*$(HASH)$(HASH) ' $(MAKEFILE_LIST) | sed -E 's/:.*$(HASH)$(HASH) /\t/' | expand -t 10
	@echo; echo "Version $(VERSION); ADDONS=\"$(ADDONS)\""

lint: ## Syntax-check, then luacheck (if installed), every .lua the .toc loads
	$(LUAC) -p $(LUA)
	@if command -v $(LUACHECK) >/dev/null 2>&1; then \
		echo "$(LUACHECK) $(LUA)"; $(LUACHECK) $(LUA); \
	else \
		echo "note: $(LUACHECK) not found, skipping (brew install luacheck)"; \
	fi

package: lint ## Build .release/PopupAtCursor-<version>.tar.gz
	build-tools/make-tarball.sh

install: lint ## Build and install into ADDONS (override: make install ADDONS=...)
	build-tools/install-tarball.sh "$(ADDONS)"

clean: ## Remove .release/
	rm -rf .release
