# Ultraviolet

> **How to resume:** read `plans/parity.md` first and use its **Where we are**
> block (current focus + ordered "Next up"), then run `make lint`, `make test`,
> and `make inventory`. Details: [docs/resuming.md](docs/resuming.md). Do not
> re-derive state from git.

Crystal port of Charm's ultraviolet (Go) from
[charmbracelet/ultraviolet](https://github.com/charmbracelet/ultraviolet),
vendored at `vendor/ultraviolet/` (commit `8ecbcf0`; Crystal behavior tracks
`6b8d4ba` until [the refresh plan](plans/commit_8ecbcf0.md) closes).

## Commands

```bash
make install    # shards install
make update     # shards update
make format     # crystal tool format src spec
make lint       # ameba src spec
make test       # crystal spec
make inventory  # curated parity ledger gate (installed skill scripts)
make parity     # inventory + both generated parity manifests
make clean      # remove temp/, .crystal-cache/, examples, and build artifacts
```

Run gates on project code only: never format or lint `lib/`, `vendor/`, or
generated example binaries. `lint`, `format`, and `test` strip macOS AppleDouble
`._*` sidecars first; see [Environment notes](docs/resuming.md#environment-notes).

## Docs

- [Resuming work](docs/resuming.md)
- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Coding Guidelines](docs/coding-guidelines.md)
- [Testing](docs/testing.md)
- [PR Workflow](docs/pr-workflow.md)
- [Porting map](PORTING.md)
- [Parity plan](plans/parity.md)
- [Parity inventory](plans/inventory/)
- [Tutorial](docs/TUTORIAL.md)
- [API reference](docs/API_REFERENCE.md)
- [Examples](examples/)

## Principles

1. Upstream behavior is the source of truth; `vendor/ultraviolet/` wins over
   local preference.
2. Port behavior, not style.
3. Port upstream tests early and never weaken assertions.
4. Track parity in `plans/parity.md` and `plans/inventory/`.
5. Commit one completed feature at a time.

## Parity tooling

The active cross-language parity skill is
`${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity`.
`make inventory` and `make parity` invoke that skill's current `scripts/`
through the thin wrappers in this repo's `scripts/` (resolve with
`scripts/parity_skill_dir.sh`; override with `PARITY_SKILL_DIR`). Never copy a
parity implementation into this repo: copies drift and silently keep an
outdated parser backend.

The curated ledger uses `regex` discovery vocabulary (`PORT_PARSER=regex` is
pinned in every wrapper). Keep that mode for the regular gate until a reviewed
manifest and ID migration changes it. Before relying on discovery, run:

```bash
PARITY_SKILL_DIR="${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity"
"${PARITY_SKILL_DIR}/scripts/verify_skill_install.sh" . go regex
PORT_PARSER=regex make inventory
```

Check `PARITY_DISCOVERY_BACKEND` in the gate output and, when manifests are
regenerated, `backend` in their `.metadata.json` files. A requested parser mode
or installed Ruby gem does not prove tree-sitter ran; this ledger is `regex`,
so the reported backend must stay `regex`. Chiasmus binary releases are
resolved by the installed skill, distinct from its scripts.

Inventory layout:

- `plans/inventory/go_port_inventory.tsv` — curated ledger, edited by hand.
- `plans/inventory/go_source_parity.tsv`, `go_test_parity.tsv` — discovery
  output **merged by hand with `ported` / `crystal_refs` columns**. Regenerating
  them writes `missing` for every row, so diff the new ID set against the
  current file and port the status columns forward; never overwrite in place.
- Never run `scripts/generate_go_port_inventory.sh` against the live ledger:
  it writes a candidate under `temp/` for review.

## Session continuity (read this first)

`plans/parity.md` is the single source of truth for where we are. At the start
of every session:

1. Read `plans/parity.md` and use its **Where we are** block to find the current
   focus, the ordered "Next up" list, and per-area chunk status. Do not
   re-derive state from git history.
2. Skim `git log --oneline -10` and `git status` to confirm the working tree.
3. Run `make lint`, `make test`, and `make inventory` before changes to confirm
   a clean baseline.

See [docs/resuming.md](docs/resuming.md) for the full resume checklist.

### Keeping `plans/parity.md` resumable

- `plans/parity.md` starts with a **Where we are** block (`Current focus`,
  `Next up`, chunk status by area). Keep it accurate after every feature.
- Work items are feature-sized (roughly one branch/commit). Per-symbol state
  lives in `plans/inventory/go_port_inventory.tsv`, not in the plan.
- If `plans/parity.md` grows too large, split it into `plans/<area>.md` files,
  link each from `plans/parity.md`, and mark each split file
  complete/in-progress plus the file being worked on next.

### Definition of done for every feature (required)

A feature is complete only when all of the following are true, and all of it
must be committed as **one** atomic commit before starting the next feature:

1. the API surface is implemented;
2. upstream tests (or equivalent characterization specs) exist and pass;
3. gates pass: `make lint`, `make test`, and `make inventory`;
4. parity inventory rows for the feature are updated
   (`plans/inventory/go_port_inventory.tsv`) and `make inventory` passes — it
   checks every row against the pinned tree *and* that each `crystal_refs` file
   still exists, which is the half that rots when this repo's own files move;
5. `plans/parity.md` status is updated and the **Where we are** block refreshed
   (current focus + next up);
6. any intentional divergence is documented (in `plans/parity.md` and/or the
   commit message).

### Commit message

Start with `port:` and a one-line feature name, then bullets for what changed,
then the upstream revision (`charmbracelet/ultraviolet 8ecbcf0`). Include
new/changed files, divergences, and the gate results so a new session can
resume from the commit alone.

### Session completion

Work is not complete until the commit is pushed:

```bash
git pull --rebase
git push
git status  # must report up to date with origin
```
