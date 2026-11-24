.PHONY: build install update update_dependents spec test test-file lint format format-check docs build-examples check-examples smoke-examples snapshot-examples snapshot-update parity-examples decode-golden check-win32 check-inline-fixture inventory check-go-source-parity check-go-test-parity parity strip-sidecars clean benchmark run-example help
.PHONY: container-info container-build test-linux container-dev container-clean

# Local Linux testing in a container. Apple `container` is preferred on macOS,
# then docker; `container-info` reports the pick.
CONTAINER_IMAGE ?= ultraviolet-linux-test
CONTAINER_FILE ?= Dockerfile.linux
CONTAINER_MEMORY ?= 6G
CONTAINER_CPUS ?= 4
CONTAINER := $(shell command -v container 2>/dev/null)
DOCKER := $(shell command -v docker 2>/dev/null)

ifdef CONTAINER
  CONTAINER_ENGINE = container
  CONTAINER_BUILD = container build --tag $(CONTAINER_IMAGE) --file $(CONTAINER_FILE) .
  CONTAINER_RUN = container run --rm --memory $(CONTAINER_MEMORY) --cpus $(CONTAINER_CPUS) --volume "$(PWD)":/workspace $(CONTAINER_IMAGE)
  CONTAINER_SHELL = container run --rm --interactive --tty --memory $(CONTAINER_MEMORY) --cpus $(CONTAINER_CPUS) --volume "$(PWD)":/workspace $(CONTAINER_IMAGE) bash
  CONTAINER_CLEAN = container image delete $(CONTAINER_IMAGE) 2>/dev/null || true
else ifdef DOCKER
  CONTAINER_ENGINE = docker
  CONTAINER_BUILD = docker build -t $(CONTAINER_IMAGE) -f $(CONTAINER_FILE) .
  CONTAINER_RUN = docker run --rm --memory $(CONTAINER_MEMORY) --cpus $(CONTAINER_CPUS) -v "$(PWD)":/workspace $(CONTAINER_IMAGE)
  CONTAINER_SHELL = docker run --rm -it --memory $(CONTAINER_MEMORY) --cpus $(CONTAINER_CPUS) -v "$(PWD)":/workspace $(CONTAINER_IMAGE) bash
  CONTAINER_CLEAN = docker rmi $(CONTAINER_IMAGE) 2>/dev/null || true
else
  CONTAINER_ENGINE = none
  CONTAINER_BUILD = @echo "No container runtime found (install Apple container or docker)"; false
  CONTAINER_RUN = @echo "No container runtime found (install Apple container or docker)"; false
  CONTAINER_SHELL = $(CONTAINER_RUN)
  CONTAINER_CLEAN = @echo "No container runtime to clean."
endif

# Crystal cache for faster builds
export CRYSTAL_CACHE_DIR := $(PWD)/.crystal-cache

# Example source files and their output binaries. AppleDouble sidecars
# (`._draw.cr`) land next to real files on exFAT volumes and must not become
# build targets or type-check inputs.
EXAMPLE_SOURCES := $(filter-out examples/._%,$(shell find examples -name '*.cr'))
EXAMPLE_BINARIES := $(EXAMPLE_SOURCES:.cr=)

# Every example links the library, so an example binary is stale whenever any
# source file or the dependency set changes -- not only when its own file does.
# Depending on these makes `make build-examples` rebuild exactly what changed
# and leave the rest of the binaries alone.
EXAMPLE_DEPS := $(shell find src -name '*.cr') shard.yml $(wildcard shard.lock)

# Build the library (check for errors)
build:
	shards build

install:
	shards install

update:
	shards update

# --- Dependents -----------------------------------------------------------
# Sibling checkouts that declare `dsisnero/ultraviolet` in their shard.yml.
# Shards resolves a dependency by its highest release tag, so refreshing one is
# a targeted `shards update ultraviolet` that follows the newest tag. That is
# why every release needs a tag: an untagged commit on `main` never reaches a
# consumer or a dependent. See the Versioning section in CHANGELOG.md.
# Override with: make update_dependents DEPENDENTS="../lipgloss"
DEPENDENTS ?= ../lipgloss ../bubbletea.cr ../bubbletea.cr/bubbletea-examples ../bubbles-examples
UV_REMOTE ?= origin
UV_BRANCH ?= main
DRY_RUN ?= 0

# Refresh every dependent onto the newest pushed tag. Run it after `git push
# --tags`: dependents resolve from GitHub, so a local tag is invisible, and a
# commit on `main` past the newest tag cannot be reached at all. DRY_RUN=1
# reports without changing anything.
update_dependents:
	@git fetch --quiet --tags $(UV_REMOTE) 2>/dev/null || true; \
	newest_tag=$$(git ls-remote --tags --refs $(UV_REMOTE) 'refs/tags/v*' 2>/dev/null | sed 's|.*refs/tags/||' | grep -E '^v[0-9]' | sort -V | tail -1); \
	tag_sha=$$(git rev-parse --verify --quiet "$$newest_tag^{commit}" || true); \
	[ -n "$$tag_sha" ] || tag_sha=$$(git ls-remote --tags $(UV_REMOTE) "refs/tags/$$newest_tag^{}" 2>/dev/null | cut -f1); \
	newest_version=$${newest_tag#v}; \
	remote_sha=$$(git ls-remote $(UV_REMOTE) refs/heads/$(UV_BRANCH) 2>/dev/null | cut -f1); \
	if [ -z "$$newest_tag" ]; then \
		echo "note: no tags on $(UV_REMOTE); dependents would resolve $(UV_BRANCH) HEAD instead" >&2; \
		newest_tag="$(UV_BRANCH) HEAD"; \
		echo "ultraviolet $(UV_REMOTE)/$(UV_BRANCH) = $$(echo $$remote_sha | cut -c1-7)"; \
	elif [ -n "$$remote_sha" ] && [ "$$tag_sha" != "$$remote_sha" ]; then \
		echo "ultraviolet newest tag = $$newest_tag ($$(echo $$tag_sha | cut -c1-7))"; \
		unshipped=$$(git diff --name-only "$$tag_sha..$$remote_sha" -- src shard.yml 2>/dev/null | head -1); \
		if [ -n "$$unshipped" ]; then \
			echo "warning: $(UV_REMOTE)/$(UV_BRANCH) $$(echo $$remote_sha | cut -c1-7) has source changes after $$newest_tag" >&2; \
			echo "         untagged commits never reach dependents: tag a patch release to ship them" >&2; \
		else \
			echo "note: $(UV_REMOTE)/$(UV_BRANCH) is ahead of $$newest_tag, but only tooling/docs changed" >&2; \
		fi; \
	else \
		echo "ultraviolet newest tag = $$newest_tag ($$(echo $$tag_sha | cut -c1-7))"; \
	fi; \
	status=0; \
	for dep in $(DEPENDENTS); do \
		if [ ! -f "$$dep/shard.yml" ]; then echo "skip   $$dep (no shard.yml)"; continue; fi; \
		locked_before=$$(awk '/^  ultraviolet:/{f=1;next} f&&/version:/{print $$2;exit}' "$$dep/shard.lock" 2>/dev/null || echo none); \
		if [ "$(DRY_RUN)" = "1" ]; then \
			echo "dry    $$dep (locked $${locked_before:-none}, newest tag $$newest_tag)"; \
			continue; \
		fi; \
		echo "update $$dep"; \
		( cd "$$dep" && shards update ultraviolet ) || { status=1; continue; }; \
		locked=$$(awk '/^  ultraviolet:/{f=1;next} f&&/version:/{print $$2;exit}' "$$dep/shard.lock"); \
		case "$$locked" in \
			"$$newest_version") echo "       $$dep now at $$newest_tag" ;; \
			*+git.commit.*) echo "       $$dep now at $$locked (untagged $(UV_BRANCH) HEAD; drop its shard.override.yml to follow tags)" ;; \
			*) echo "warn   $$dep stayed on $$locked, not $$newest_version; check its lock or shard.override.yml" >&2 ;; \
		esac; \
	done; \
	exit $$status

# This checkout lives on an exFAT volume, so macOS writes AppleDouble `._*`
# sidecars next to real files. A `._foo_spec.cr` sidecar matches Crystal's
# `*_spec.cr` discovery glob and a `._foo.cr` breaks require resolution, so
# strip them before any gate.
strip-sidecars:
	@find src spec examples plans docs scripts vendor -name '._*' -delete 2>/dev/null || true

# Run all tests (excluding interactive)
spec test: strip-sidecars
	crystal spec

# Run one spec file: make test-file FILE=spec/decoder_spec.cr
test-file:
	crystal spec $(FILE)

# Lint project Crystal sources
lint: strip-sidecars
	ameba src spec

# Curated parity ledger gate: every pinned Go symbol has a row and every
# crystal_refs file still exists. Forwards to the installed parity skill.
inventory:
	./scripts/check_go_port_inventory.sh

check-go-test-parity:
	./scripts/check_go_test_parity.sh

check-go-source-parity:
	./scripts/check_go_source_parity.sh

# All parity gates (inventory + generated manifests)
parity: inventory check-go-source-parity check-go-test-parity

# Format project Crystal files
format: strip-sidecars
	crystal tool format src spec

# Check formatting without changing files
format-check:
	crystal tool format --check src spec

# Container runtime detection
container-info:
	@echo "Container runtime detection:"
	@echo "  Apple container: $(if $(CONTAINER),found at $(CONTAINER),not found)"
	@echo "  docker:          $(if $(DOCKER),found at $(DOCKER),not found)"
	@echo ""
	@echo "Using: $(CONTAINER_ENGINE)"

# Build the Linux test image
container-build:
	$(CONTAINER_BUILD)

# Run the full spec suite on Linux in a container (run `make install` first)
test-linux: container-build
	$(CONTAINER_RUN) crystal spec

# Interactive shell inside the Linux image
container-dev: container-build
	$(CONTAINER_SHELL)

# Remove the Linux test image
container-clean:
	$(CONTAINER_CLEAN)

# Generate documentation
docs:
	crystal docs

# Build all examples (output in examples/ directory)
build-examples: $(EXAMPLE_BINARIES)
	@echo "Built all examples in examples/"

# Type-check every example without producing binaries
check-examples:
	@if grep -rn -- '__FILE__ == $$0' examples/*.cr; then \
		echo "error: Crystal's \$$0 is the last regex match, not the program name." >&2; \
		echo "       Run the example unconditionally instead of guarding on __FILE__." >&2; \
		exit 1; \
	fi
	@for f in $$(find examples -maxdepth 1 -name '[^.]*.cr' | sort); do \
		echo "Checking $$f"; \
		crystal build --no-codegen "$$f" || exit $$?; \
	done

# Snapshot every example's first frame (verify / regenerate).
snapshot-examples: $(EXAMPLE_BINARIES)
	@crystal run scripts/snapshot_examples.cr

snapshot-update: $(EXAMPLE_BINARIES)
	@GOLDEN_UPDATE=1 crystal run scripts/snapshot_examples.cr

# Compare each example's first frame against the vendored Go example. Local
# only: it needs a Go toolchain and the modules in vendor/ultraviolet/examples.
parity-examples: $(EXAMPLE_BINARIES)
	@crystal run scripts/parity_examples.cr

# Regenerate the decoder golden with the vendored Go decoder as the oracle.
# Needs Go; the output is committed, so CI verifies Crystal alone.
decode-golden:
	@cd scripts/decode_oracle && go run . ../../spec/fixtures/decode_inputs.txt ../../spec/fixtures/decode_golden.tsv
	@echo "Regenerated spec/fixtures/decode_golden.tsv"

# Smoke-run every example under a pseudo terminal for a moment. Type-checking
# cannot see a crash on the first frame (a nil assumption, an unmatchable
# guard), and that is how examples rot once they stop being run. POSIX only,
# and needs `timeout` (coreutils).
smoke-examples: $(EXAMPLE_BINARIES)
	@for bin in $(EXAMPLE_BINARIES); do \
		out=$$(cd examples && if [ "$$(uname -s)" = "Darwin" ]; then \
			timeout 3 script -q /dev/null "../$$bin"; \
		else \
			timeout 3 script -qec "../$$bin" /dev/null; \
		fi 2>&1 || true); \
		if echo "$$out" | grep -qiE "unhandled exception|nilassertionerror"; then \
			echo "smoke: $$bin crashed:" >&2; \
			echo "$$out" | head -6 >&2; \
			exit 1; \
		fi; \
		echo "smoke: $$bin ok"; \
	done

# Type-check the Win32 console readers for the Windows target; the win32 files
# are flag-gated, so the normal gates never see them.
check-win32:
	./scripts/check_win32.sh

# Reproduce the sibling bubbletea.cr inline-fixture failure against this src/.
check-inline-fixture:
	./scripts/check_inline_fixture.sh

examples/%: examples/%.cr $(EXAMPLE_DEPS)
	@echo "Building $@"
	crystal build $< -o $@

# Clean temporary files, logs, and build artifacts
clean:
	mkdir -p temp
	rm -rf temp/*
	rm -rf log/*
	rm -rf .crystal-cache
	rm -f *.dwarf examples/*.dwarf
	rm -f $(EXAMPLE_BINARIES)
	@echo "Cleaned temp/, log/, .crystal-cache/, *.dwarf, and example binaries"

# Run benchmarks
benchmark:
	crystal run benchmarks/benchmark.cr --release

# Run a specific example
run-example:
	@if [ -z "$(EXAMPLE)" ]; then \
		echo "Usage: make run-example EXAMPLE=basic_example"; \
		echo "Available examples:"; \
		ls -1 examples/*.cr | xargs -n1 basename | sed 's/.cr$$//'; \
	else \
		crystal run examples/$(EXAMPLE).cr; \
	fi

# Help
help:
	@echo "Ultraviolet - Crystal terminal UI library"
	@echo ""
	@echo "Available targets:"
	@echo "  build              - Build the library"
	@echo "  build-examples     - Build all examples (output in examples/)"
	@echo "  check-examples     - Type-check every example without building binaries"
	@echo "  smoke-examples     - Run each example under a pty for a moment"
	@echo "  decode-golden      - Regenerate the decoder golden from the vendored Go decoder"
	@echo "  snapshot-examples  - Verify each example's first frame against its golden"
	@echo "  snapshot-update    - Regenerate the example goldens"
	@echo "  parity-examples    - Diff each example against the vendored Go example"
	@echo "  check-win32        - Type-check the Win32 console readers (cross-target)"
	@echo "  check-inline-fixture - Reproduce bubbletea.cr's inline-fixture failure against local src/"
	@echo "  test-linux         - Run the spec suite on Linux in a container"
	@echo "  container-info     - Show the detected container runtime"
	@echo "  container-build    - Build the Linux test image"
	@echo "  container-dev      - Interactive shell in the Linux image"
	@echo "  container-clean    - Remove the Linux test image"
	@echo "  install            - Install dependencies"
	@echo "  update_dependents  - Refresh sibling repos that depend on ultraviolet (DRY_RUN=1 to preview)"
	@echo "  test/spec          - Run tests (excluding interactive)"
	@echo "  test-file          - Run one spec file (FILE=spec/foo_spec.cr)"
	@echo "  lint               - Run Ameba on src and spec"
	@echo "  format             - Format project Crystal files"
	@echo "  format-check       - Check formatting without changing files"
	@echo "  inventory          - Check the curated parity ledger (installed skill)"
	@echo "  parity             - Run inventory + generated parity manifest gates"
	@echo "  docs               - Generate documentation"
	@echo "  clean              - Clean temp/, log/, cache, and built examples"
	@echo "  benchmark          - Run performance benchmarks"
	@echo "  run-example        - Run an example (EXAMPLE=name)"
	@echo "  help               - Show this help"
