# Thin wrapper around build-tools/. The scripts do the work and run on their own.

ADDON   := PopupAtCursor
TOC     := $(ADDON).toc
ADDONS  ?= $(or $(WOW_ADDONS),/Applications/World of Warcraft/_retail_/Interface/AddOns)
LUAC    ?= luac
VERSION := $(shell sed -n 's/^\#\# Version:[[:space:]]*//p' $(TOC) | tr -d '\r' | head -n1)
# .lua files the .toc loads (non-blank lines that are not # comments)
LUA     := $(filter %.lua,$(shell grep -v -e '^\#' -e '^[[:space:]]*$$' $(TOC) | tr -d '\r' | tr '\\\\' /))

.DEFAULT_GOAL := help
.PHONY: help lint package install clean

help: ## List targets
	@grep -E '^[a-z]+:.*\#\# ' $(MAKEFILE_LIST) | sed -E 's/:.*\#\# /\t/' | expand -t 10
	@echo; echo "Version $(VERSION); ADDONS=\"$(ADDONS)\""

lint: ## Syntax-check every .lua the .toc loads
	$(LUAC) -p $(LUA)

package: lint ## Build .release/PopupAtCursor-<version>.tar.gz
	build-tools/make-tarball.sh

install: lint ## Build and install into ADDONS (override: make install ADDONS=...)
	build-tools/install-tarball.sh "$(ADDONS)"

clean: ## Remove .release/
	rm -rf .release
