.PHONY: build install update spec test test-file lint format format-check docs build-examples check-go-test-parity check-go-source-parity clean benchmark run-example help

# Crystal cache for faster builds
export CRYSTAL_CACHE_DIR := $(PWD)/.crystal-cache

# Example source files and their output binaries
EXAMPLE_SOURCES := $(shell find examples -name '*.cr')
EXAMPLE_BINARIES := $(EXAMPLE_SOURCES:.cr=)

# Build the library (check for errors)
build:
	shards build

install:
	shards install

update:
	shards update

# Run all tests (excluding interactive)
spec test:
	crystal spec

# Run one spec file: make test-file FILE=spec/decoder_spec.cr
test-file:
	crystal spec $(FILE)

# Lint project Crystal sources
lint:
	ameba src spec

check-go-test-parity:
	./bin/check_go_test_parity.sh

check-go-source-parity:
	./bin/check_go_source_parity.sh


# Format project Crystal files
format:
	crystal tool format src spec

# Check formatting without changing files
format-check:
	crystal tool format --check src spec

# Generate documentation
docs:
	crystal docs

# Build all examples (output in examples/ directory)
build-examples: $(EXAMPLE_BINARIES)
	@echo "Built all examples in examples/"

examples/%: examples/%.cr
	crystal build $< -o $@

# Clean temporary files, logs, and build artifacts
clean:
	mkdir -p temp
	rm -rf temp/*
	rm -rf log/*
	rm -rf .crystal-cache
	rm -f *.dwarf
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
	@echo "  install            - Install dependencies"
	@echo "  test/spec          - Run tests (excluding interactive)"
	@echo "  test-file          - Run one spec file (FILE=spec/foo_spec.cr)"
	@echo "  lint               - Run Ameba on src and spec"
	@echo "  format             - Format project Crystal files"
	@echo "  format-check       - Check formatting without changing files"
	@echo "  docs               - Generate documentation"
	@echo "  clean              - Clean temp/, log/, cache, and built examples"
	@echo "  benchmark          - Run performance benchmarks"
	@echo "  run-example        - Run an example (EXAMPLE=name)"
	@echo "  help               - Show this help"
