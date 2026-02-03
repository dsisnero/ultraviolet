.PHONY: build install spec spec-all spec-provider spec-provider-record spec-interactive clean format docs build-examples

# Crystal cache for faster builds
export CRYSTAL_CACHE_DIR := $(PWD)/.crystal-cache

# Example source files and their output binaries
EXAMPLE_SOURCES := $(shell find examples -name '*.cr')
EXAMPLE_BINARIES := $(EXAMPLE_SOURCES:.cr=)

# Build the library (check for errors)
build:
	shards build

install:
	GIT_CONFIG_GLOBAL=/dev/null shards install

update:
	GIT_CONFIG_GLOBAL=/dev/null shards update

# Run all tests (excluding interactive)
spec:
	crystal spec


# Format all Crystal files
format:
	crystal tool format

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
	@echo "Term2 - Crystal Terminal Library"
	@echo ""
	@echo "Available targets:"
	@echo "  build              - Build the library"
	@echo "  build-examples     - Build all examples (output in examples/)"
	@echo "  install            - Install dependencies"
	@echo "  spec               - Run tests (excluding interactive)"
	@echo "  spec-interactive   - Run interactive tests"
	@echo "  format             - Format Crystal files"
	@echo "  docs               - Generate documentation"
	@echo "  clean              - Clean temp/, log/, cache, and built examples"
	@echo "  benchmark          - Run performance benchmarks"
	@echo "  run-example        - Run an example (EXAMPLE=name)"
	@echo "  help               - Show this help"
