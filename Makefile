.PHONY: build install update spec test test-file lint format format-check docs build-examples check-examples check-win32 inventory check-go-source-parity check-go-test-parity parity strip-sidecars clean benchmark run-example help
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

# Example source files and their output binaries
EXAMPLE_SOURCES := $(shell find examples -name '*.cr')
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
	@for f in examples/*.cr; do \
		echo "Checking $$f"; \
		crystal build --no-codegen "$$f" || exit $$?; \
	done

# Type-check the Win32 console readers for the Windows target; the win32 files
# are flag-gated, so the normal gates never see them.
check-win32:
	./scripts/check_win32.sh

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
	@echo "  check-win32        - Type-check the Win32 console readers (cross-target)"
	@echo "  test-linux         - Run the spec suite on Linux in a container"
	@echo "  container-info     - Show the detected container runtime"
	@echo "  container-build    - Build the Linux test image"
	@echo "  container-dev      - Interactive shell in the Linux image"
	@echo "  container-clean    - Remove the Linux test image"
	@echo "  install            - Install dependencies"
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
