.POSIX:

# Recipes for this Makefile

## Build shards
##   $ make
## Build shards in release mode
##   $ make release=1
## Run tests
##   $ make test
## Run tests without fossil tests
##   $ make test skip_fossil=1
## Generate docs
##   $ make docs
## Install shards
##   $ make install
## Uninstall shards
##   $ make uninstall
## Build and install shards
##   $ make build && sudo make install

release ?=      ## Compile in release mode
debug ?=        ## Add symbolic debug info
static ?=       ## Enable static linking
skip_fossil ?=  ## Skip fossil tests
skip_git ?=     ## Skip git tests
skip_hg ?=      ## Skip hg tests

DESTDIR ?=          ## Install destination dir
PREFIX ?= /usr/local## Install path prefix

CRYSTAL ?= crystal
SHARDS ?= shards
override FLAGS += $(if $(release),--release )$(if $(debug),-d )$(if $(static),--static )

SHARDS_SOURCES = $(shell find src -name '*.cr')
MOLINILLO_SOURCES = $(shell find lib/molinillo -name '*.cr' 2> /dev/null)
SOURCES = $(SHARDS_SOURCES) $(MOLINILLO_SOURCES)
TEMPLATES = src/templates/*.ecr

SHARDS_CONFIG_BUILD_COMMIT := $(shell git rev-parse --short HEAD 2> /dev/null)
SHARDS_VERSION := $(shell cat VERSION)
SOURCE_DATE_EPOCH := $(shell (git show -s --format=%ct HEAD || stat -c "%Y" Makefile || stat -f "%m" Makefile) 2> /dev/null)
EXPORTS := SHARDS_CONFIG_BUILD_COMMIT="$(SHARDS_CONFIG_BUILD_COMMIT)" SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)"
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
INSTALL ?= /usr/bin/install

# MSYS2 support (native Windows should use `Makefile.win` instead)
ifeq ($(OS),Windows_NT)
  EXE := .exe
  WINDOWS := 1
else
  EXE :=
  WINDOWS :=
endif

.PHONY: all
all: build

include docs.mk

.PHONY: build
build: bin/shards$(EXE)

.PHONY: clean
clean: ## Remove build artifacts
clean: clean_docs
	rm -f bin/shards$(EXE)

bin/shards$(EXE): $(SOURCES) $(TEMPLATES)
	@mkdir -p bin
	$(EXPORTS) $(CRYSTAL) build $(FLAGS) src/shards.cr -o "$@"

.PHONY: install
install: ## Install shards
install: bin/shards$(EXE) man/shards.1.gz man/shard.yml.5.gz
	$(INSTALL) -m 0755 -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(MANDIR)/man1" "$(DESTDIR)$(MANDIR)/man5"
	$(INSTALL) -m 0755 bin/shards$(EXE) "$(DESTDIR)$(BINDIR)"
	$(INSTALL) -m 0644 man/shards.1.gz "$(DESTDIR)$(MANDIR)/man1"
	$(INSTALL) -m 0644 man/shard.yml.5.gz "$(DESTDIR)$(MANDIR)/man5"

ifeq ($(WINDOWS),1)
.PHONY: install_dlls
install_dlls: bin/shards$(EXE) ## Install the dependent DLLs at DESTDIR (Windows only)
	$(INSTALL) -d -m 0755 "$(BINDIR)/"
	@ldd bin/shards$(EXE) | grep -iv ' => /c/windows/system32' | sed 's/.* => //; s/ (.*//' | xargs -t -i $(INSTALL) -m 0755 '{}' "$(BINDIR)/"
endif

.PHONY: uninstall
uninstall: ## Uninstall shards
uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/shards"
	rm -f "$(DESTDIR)$(MANDIR)/man1/shards.1.gz"
	rm -f "$(DESTDIR)$(MANDIR)/man5/shard.yml.5.gz"

.PHONY: test
test: ## Run all tests
test: test_unit test_integration

.PHONY: test_unit
test_unit: ## Run unit tests
test_unit:
	$(CRYSTAL) spec ./spec/unit/ $(if $(skip_fossil),--tag ~fossil) $(if $(skip_git),--tag ~git) $(if $(skip_hg),--tag ~hg)

.PHONY: test_integration
test_integration: ## Run integration tests
test_integration: bin/shards$(EXE)
	$(CRYSTAL) spec ./spec/integration/

man/%.gz: man/%
	gzip -c -9 $< > $@

.PHONY: help
help: ## Show this help
	@echo
	@printf '\033[34mtargets:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34moptional variables:\033[0m\n'
	@grep -hE '^[a-zA-Z_-]+ \?=.*?## .*$$' $(MAKEFILE_LIST) |\
		sort |\
		awk 'BEGIN {FS = " \\?=.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo
	@printf '\033[34mrecipes:\033[0m\n'
	@grep -hE '^##.*$$' $(MAKEFILE_LIST) |\
		awk 'BEGIN {FS = "## "}; /^## [a-zA-Z_-]/ {printf "  \033[36m%s\033[0m\n", $$2}; /^##  / {printf "  %s\n", $$2}'
