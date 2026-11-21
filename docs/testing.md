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
