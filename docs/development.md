# Development

## Setup

Install Crystal dependencies:

```bash
make install
```

`vendor/ultraviolet/` is a checked-in snapshot of the upstream Go source. The
Crystal dependencies under `lib/` are managed by `shards`.

## Daily commands

```bash
make format   # format project Crystal sources
make lint     # run Ameba on src and spec
make test     # run the Crystal spec suite
make clean    # remove generated artifacts
```

For a non-mutating format check:

```bash
make format-check
```

## Porting workflow

1. Find the upstream behavior in `vendor/ultraviolet/`.
2. Locate the nearest Go test and port it to `spec/` first.
3. Implement the Crystal API in `src/ultraviolet/`.
4. Run `make lint` and `make test`.
5. Update the inventory rows and `plans/parity.md` **Where we are** block.
6. Commit one feature atomically using the `port:` message format in
   `AGENTS.md`.

## Updating the vendored Go source

The current snapshot is commit `7cc6674`. To move to a newer upstream commit,
follow the process in `plans/update-vendor.md`: replace the `vendor/ultraviolet/`
tree, re-run the port audit, then regenerate the parity manifests.

## Parity scripts

```bash
./scripts/check_port_inventory.sh . plans/inventory/go_port_inventory.tsv vendor/ultraviolet go
./scripts/check_source_parity.sh . plans/inventory/go_source_parity.tsv vendor/ultraviolet go
./scripts/check_test_parity.sh . plans/inventory/go_test_parity.tsv vendor/ultraviolet go
./scripts/verify_parity_adversarial.sh . vendor/ultraviolet go 'crystal spec' 'go test ./...'
```

See `plans/parity.md` for current counts and known upstream-limited gaps.
