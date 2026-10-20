# Testing

## Commands

```bash
make test           # crystal spec
make test-file FILE=spec/decoder_spec.cr
make format-check   # crystal tool format --check src spec
make lint           # ameba src spec
```

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
./scripts/check_source_parity.sh . plans/inventory/go_source_parity.tsv vendor/ultraviolet go
./scripts/check_test_parity.sh . plans/inventory/go_test_parity.tsv vendor/ultraviolet go
```

The current status and remaining upstream-limited gaps are tracked in
`plans/parity.md`.
