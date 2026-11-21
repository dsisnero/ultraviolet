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

## CI

`.github/workflows/ci.yml` runs on every push and pull request:

| Job | Runner | Steps |
|-----|--------|-------|
| `Test (ubuntu-latest)` | Ubuntu | `shards install`, format check, `check_win32.sh`, `crystal spec` |
| `Test (macos-latest)` | macOS | same |
| `Test (windows-latest)` | Windows | `shards install`, format check, `crystal spec` (compiles the win32 files natively) |
| `Lint` | Ubuntu | `shards install`, `./bin/ameba src spec` |

The parity gates (`make inventory`, `make parity`) are intentionally **not** in
CI: they forward to the locally installed `cross-language-crystal-parity`
skill, which is not part of this repository. Run them locally.

`.gitattributes` pins `eol=lf` so the Windows runner's format check sees the
same bytes as the Unix runners.

## Local Linux testing in a container

Linux-only code (for example the epoll poll reader) cannot be exercised on
macOS. `Dockerfile.linux` plus the container targets run the same suite the
`ubuntu-latest` CI job runs:

```bash
make container-info   # shows which runtime was detected
make container-build  # build the Linux test image
make test-linux       # shards install once, then run the suite in Linux
make container-dev    # interactive shell in the image
make container-clean  # delete the image
```

Apple `container` is preferred when present (macOS on Apple silicon), then
`docker`. The run is given 6 GB / 4 CPUs by default because the Crystal
compiler is otherwise OOM-killed (`exit 137`); override with
`make test-linux CONTAINER_MEMORY=8G CONTAINER_CPUS=6`.

## Porting workflow

1. Find the upstream behavior in `vendor/ultraviolet/`.
2. Locate the nearest Go test and port it to `spec/` first.
3. Implement the Crystal API in `src/ultraviolet/`.
4. Run `make lint` and `make test`.
5. Update the inventory rows and `plans/parity.md` **Where we are** block.
6. Commit one feature atomically using the `port:` message format in
   `AGENTS.md`.

## Updating the vendored Go source

This upstream publishes no tags or releases, so snapshots are pinned by commit.
The current snapshot is `8ecbcf0` (2026-11-19) and the port tracks it in full;
`plans/commit_8ecbcf0.md` is the record of that refresh.

To move to a newer upstream commit:

```bash
git ls-remote https://github.com/charmbracelet/ultraviolet refs/heads/main
git clone https://github.com/charmbracelet/ultraviolet temp/upstream-ultraviolet
git -C temp/upstream-ultraviolet log --oneline <current>..<target>
```

Replace the `vendor/ultraviolet/` tree with the target commit's tree, write a
`plans/commit_<sha>.md` plan for the delta, regenerate the parity manifests, and
triage the inventory before porting behavior.

## Parity scripts

The gates forward to the installed `cross-language-crystal-parity` skill
(`${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity`,
override with `PARITY_SKILL_DIR`). The wrappers in `scripts/` only supply this
repo's defaults; the parity logic lives in the skill.

```bash
make inventory    # curated ledger: plans/inventory/go_port_inventory.tsv
make parity       # inventory + generated source/test parity manifests

# Underlying commands, all pinned to PORT_PARSER=regex
./scripts/check_go_port_inventory.sh . plans/inventory/go_port_inventory.tsv vendor/ultraviolet
./scripts/check_go_source_parity.sh  . plans/inventory/go_source_parity.tsv  vendor/ultraviolet
./scripts/check_go_test_parity.sh    . plans/inventory/go_test_parity.tsv    vendor/ultraviolet

# Adversarial signoff (re-derives ledgers and proves the gates can fail)
./scripts/verify_parity_adversarial.sh . vendor/ultraviolet
```

Never copy parity scripts into this repo; see the **Parity tooling** section in
`AGENTS.md`.

See `plans/parity.md` for current counts and known upstream-limited gaps.
