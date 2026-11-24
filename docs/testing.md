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

## Verifying against the vendored decoder

`vendor/ultraviolet` has no checked-in event goldens, but its decoder can be run
as an oracle. `make decode-golden` decodes
`spec/fixtures/decode_inputs.txt` with the **vendored Go** decoder and writes
`spec/fixtures/decode_golden.tsv`; `spec/decoder_golden_spec.cr` asserts this
port matches it. The golden is committed, so CI checks parity without Go.

This is how the mouse families were pinned: press, release, motion with and
without a held button, wheel, legacy X10, and the terminal size reports
(`CSI 4/6/8/48 ; ... t`). Those reports matter for tracking, because
`mouse_pixel_to_cell` returns `(0, 0)` for every event until the terminal has
reported its pixel size.

When adding an input:

```bash
$EDITOR spec/fixtures/decode_inputs.txt   # hex<TAB>label
make decode-golden
crystal spec spec/decoder_golden_spec.cr
```

## Comparing examples against the Go originals

`make parity-examples` runs each vendored Go example and this port's counterpart
on identical 80x24 pseudo terminals and diffs the first frame (local only: it
needs Go). SGR colours are compared as written — a basic or indexed colour keeps
its kind, so both sides emit the same escapes — and the startup handshake is
trimmed so the comparison is about what gets painted, not about which sequences
each side resets on the way in.

`make snapshot-examples` is the regression half: it captures each example's own
first frame against the committed goldens in `spec/testdata/examples/`
(`golden` shard; `make snapshot-update` rewrites them, `GOLDEN_UPDATE=1` for a
single run). `space` animates from the wall clock and `prependline` picks a
random colour, so both are skipped and say why.

Both harnesses capture through `scripts/support/pty_capture.cr`, which owns the
pty instead of shelling out to `script(1)` — the two `script` implementations
add different noise.

`spec/decoder_fuzz_seed_spec.cr` separately feeds upstream's
`internal/conformance/testdata/fuzz` seeds to the decoder as hostile input.
Those seeds are renderer-program bytes rather than event inputs, so that spec
asserts termination and determinism, not event parity.
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
