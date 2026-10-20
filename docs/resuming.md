# Resuming Work

This is the first thing to read in a new session. It takes a few minutes to get
back to a known-good state.

## 1. Read where we are

- `plans/parity.md` — start at the **Where we are** block. It names the current
  focus, the ordered "Next up" list, per-area chunk status, and any scoping
  notes or gotchas, plus the last commit and current gate results. Do not
  re-derive state from git history.
- `plans/inventory/go_port_inventory.tsv` — the per-symbol ledger. Use it to
  see what is left inside the current chunk:

  ```bash
  tail -n +2 plans/inventory/go_port_inventory.tsv \
    | cut -f3 | sort | uniq -c
  ```

## 2. Confirm the working tree

```bash
git log --oneline -10
git status
```

The last commit should be the previous feature (`port: ...`), committed
atomically. If the tree is dirty, finish or stash before starting.

## 3. Confirm a clean baseline

```bash
make lint
make test
```

Both must pass before changing anything.

## 4. Pick the next feature

Take the first unchecked item in the **Next up** list (or the next `[ ]` item in
the current phase). For each feature:

1. Read the upstream source under `vendor/ultraviolet/` and the nearest upstream
   tests.
2. Port the tests first (red → green); never weaken assertions.
3. Satisfy the **Definition of done** in `AGENTS.md` (API, tests, gates,
   inventory rows, `plans/parity.md` status + **Where we are** refresh,
   divergences).
4. Commit atomically with the `port: ...` message format from `AGENTS.md`.

## If the plan is split

When `plans/parity.md` grows too large it is split into `plans/<area>.md` files.
In that case every split file is linked from `plans/parity.md`, and
`plans/parity.md` marks each file complete/in-progress and names the file being
worked on plus the next file/phase to start.
