# Ultraviolet

> **How to resume:** read `plans/parity.md` first and use its **Where we are**
> block (current focus + ordered "Next up"), then run `make lint` and
> `make test`. Details: [docs/resuming.md](docs/resuming.md). Do not re-derive
> state from git.

Crystal port of Charm's ultraviolet (Go) from
[charmbracelet/ultraviolet](https://github.com/charmbracelet/ultraviolet),
vendored at `vendor/ultraviolet/` (commit `6b8d4ba`).

## Commands

```bash
make install   # shards install
make update    # shards update
make format    # crystal tool format src spec
make lint      # ameba src spec
make test      # crystal spec
make clean     # remove temp/, .crystal-cache/, examples, and build artifacts
```

Run gates on project code only: never format or lint `lib/`, `vendor/`, or
generated example binaries.

## Docs

- [Resuming work](docs/resuming.md)
- [Architecture](docs/architecture.md)
- [Development](docs/development.md)
- [Coding Guidelines](docs/coding-guidelines.md)
- [Testing](docs/testing.md)
- [PR Workflow](docs/pr-workflow.md)
- [Porting map](PORTING.md)
- [Parity plan](plans/parity.md)
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

## Session continuity (read this first)

`plans/parity.md` is the single source of truth for where we are. At the start
of every session:

1. Read `plans/parity.md` and use its **Where we are** block to find the current
   focus, the ordered "Next up" list, and per-area chunk status. Do not
   re-derive state from git history.
2. Skim `git log --oneline -10` and `git status` to confirm the working tree.
3. Run `make lint` and `make test` before changes to confirm a clean baseline.

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
3. gates pass: `make lint` and `make test`;
4. parity inventory rows for the feature are updated
   (`plans/inventory/go_port_inventory.tsv`);
5. `plans/parity.md` status is updated and the **Where we are** block refreshed
   (current focus + next up);
6. any intentional divergence is documented (in `plans/parity.md` and/or the
   commit message).

### Commit message

Start with `port:` and a one-line feature name, then bullets for what changed,
then the upstream revision (`charmbracelet/ultraviolet 6b8d4ba`). Include
new/changed files, divergences, and the gate results so a new session can
resume from the commit alone.

### Session completion

Work is not complete until the commit is pushed:

```bash
git pull --rebase
git push
git status  # must report up to date with origin
```
