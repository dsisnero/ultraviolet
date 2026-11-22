# Testing

## Commands

```bash
make test           # crystal spec
make test-file FILE=spec/decoder_spec.cr
make format-check   # crystal tool format --check src spec
make lint           # ameba src spec
make check-win32    # cross-type-check the Win32 console readers
```

The `{% if flag?(:win32) %}` files never compile on macOS/Linux, so
`make check-win32` type-checks them for `x86_64-windows-msvc` with
`--no-codegen`. It catches duplicate `LibC` constants, conflicting signatures,
broken require paths, and the bodies of everything the driver actually calls
(it has found a splat over an `Array`, a module-level `private def` called from
an instance, and mixed `Int32`/`UInt32` arrays).

Crystal types method bodies lazily, so this is a *partial* gate: a body reached
only through `spawn` (for example the Windows reader loop) is not typed by any
cross-target build. The `windows-latest` CI job is the full gate — it compiles
and runs the suite natively.

Run the full suite before committing. Specs must pass without network access or
a real interactive terminal.

## Spec layout

- `spec/*_spec.cr` mirrors the corresponding Go source or subsystem.
- `spec/decoder_spec.cr` contains sequence tables and typed event expectations.
- `spec/manual/` holds reference material for interactive or platform cases
  that cannot run unattended.
- `spec/spec_helper.cr` requires the library entry point.

## Porting tests

1. Find the Go test in `vendor/ultraviolet/` (for example `decoder_test.go`).
2. Port the cases and assertions as-is, including expected escape sequences.
3. Add the Crystal-specific setup needed to reproduce the same input.
4. Run `crystal spec spec/<file>_spec.cr` while iterating, then the full suite.

Do not delete a failing parity case to make the suite green. If a case is
blocked by an upstream-limited behavior, document it in `plans/parity.md` and
mark it explicitly.

## Linux in a container

`make test-linux` runs the suite inside `Dockerfile.linux`, which pins
`crystallang/crystal:latest` — whatever that means when the image is pulled,
not the compiler on your machine. The image was on Crystal 1.20.1 while the
host had 1.22.3, and a `Thread` + `Channel` construct that worked on one
deadlocked on the other. Treat a green local `make test` as no evidence about
the container, and read the compiler version before blaming the code:

```bash
container exec "$(container list -q | tail -1)" crystal --version
```

`shard.yml` allows Crystal >= 1.19.1, so anything the suite relies on must work
on the oldest supported compiler.

## Parity verification

The manifest scripts compare source and test inventories against the vendored
Go tree:

```bash
make parity   # inventory + source + test parity gates
```

They forward to the installed `cross-language-crystal-parity` skill (`regex`
parser mode) through the wrappers in `scripts/`; see `AGENTS.md` for the
**Parity tooling** rules.

The current status and remaining upstream-limited gaps are tracked in
`plans/parity.md`.
