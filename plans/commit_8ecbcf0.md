# Vendor refresh `6b8d4ba` → `8ecbcf0`

- **Baseline (ported behavior):** `charmbracelet/ultraviolet@6b8d4ba`
  (2026-10-08, `feat: OSC 7501 helpers (#207)`)
- **Target (vendored snapshot):** `charmbracelet/ultraviolet@8ecbcf0`
  (2026-11-19, `fix: use layout's own key (#238)`)
- **Upstream delta:** 3 commits, 8 files, +129/−19 lines
- **Symbol delta:** none — 819 source APIs and 196 tests before and after
- **Status:** phase 1 ✅ (`port: prefer layout key in Keystroke`); snapshot bumped; phases 2–3 open

This file is the plan for one commit range. Per-release history lives in
`plans/commit_<sha>.md`; `plans/parity.md` links each file and tracks the
current one.

## Comparison recipe

Reproduce the comparison at any time (the old snapshot is not kept in the repo
— a clone is cheap and always authoritative):

```bash
git clone https://github.com/charmbracelet/ultraviolet temp/upstream-ultraviolet
cd temp/upstream-ultraviolet
git log --oneline 6b8d4ba..8ecbcf0
git diff --stat 6b8d4ba 8ecbcf0
git diff 6b8d4ba 8ecbcf0 -- '*.go'
```

Verify the vendored tree still matches the target (and that nothing drifted):

```bash
git -C temp/upstream-ultraviolet worktree add temp/new-8ecbcf0 8ecbcf0
diff -r --exclude=.git vendor/ultraviolet temp/new-8ecbcf0 && echo identical
```

On this exFAT volume `rsync`/`diff` create AppleDouble `._*` sidecars; delete
them with `find vendor -name '._*' -delete` before trusting a directory diff.
`make format`, `make lint`, and `make test` strip them automatically.

## Upstream delta

| Commit | Date | Author | Subject |
|--------|------|--------|---------|
| `8ecbcf0` | 2026-11-19 | Drew Smirnoff | `fix: use layout's own key (#238)` |
| `f0c8309` | 2026-11-19 | Gaurav Gosain | `fix(windows): wait on the console handle instead of polling (#217)` |
| `a45b7c8` | 2026-10-23 | Kieran Klukas | `go: mody tidy to clear outdated pins` |

| File | +/− | Category | Crystal action |
|------|-----|----------|----------------|
| `key.go` | +4/−3 | Behavior (all platforms) | Port: `Key.Keystroke` base-code rule |
| `key_test.go` | +8/−3 | Tests | Port two new cases, drop one |
| `cancelreader_windows.go` | +81/−5 | Behavior (Windows) | Port: cancel-event lifecycle |
| `terminal_reader_windows.go` | +30/−2 | Behavior (Windows) | Port: block on console handle |
| `examples/go.mod`, `examples/go.sum` | +1/−1, +2/−2 | Dependency pins | None |
| `internal/conformance/go.mod`, `go.sum` | +1/−1, +2/−2 | Dependency pins | None (conformance not ported) |

## Symbol delta: none

Regenerating the discovery manifests against the new snapshot produces the same
819 source API IDs and 196 test IDs as `6b8d4ba`. The new Windows helpers are
unexported (`conInputReader.waitForInput`, `emptyWakeBackoff`), so discovery does
not add rows. Consequences:

- `plans/inventory/go_port_inventory.tsv` needs **no row changes** for this
  refresh.
- `plans/inventory/go_source_parity.tsv` and `go_test_parity.tsv` are unchanged
  apart from the `# kinds=` header that current skill scripts emit.
- All work in this plan is behavioral, and existing ledger rows (`ported`) stay
  `ported` only after their specs are updated.

> **Regeneration trap.** `generate_source_parity_manifest.sh` /
> `generate_test_parity_manifest.sh` emit pure discovery output: every row comes
> back `missing` with `crystal_refs = -`. These two TSVs are curated by hand in
> this repo, so regeneration must be diffed, not trusted — compare the ID sets,
> then port the status columns forward. The regeneration done for this refresh
> produced identical IDs, so the files were left untouched.

## Behavior delta

### 1. `Key.Keystroke` prefers the layout's own key

Go `key.go`, inside `Keystroke()`:

```go
code := k.Code
// before: any BaseCode wins
if k.BaseCode != 0 { code = k.BaseCode }
// after: BaseCode only for non-ASCII layouts
if k.BaseCode != 0 && (code > unicode.MaxASCII || !unicode.IsPrint(code)) {
    code = k.BaseCode
}
```

Intent (from the commit): remapped ASCII layouts (Dvorak, Colemak) must bind by
their own label, while non-ASCII layouts (Cyrillic) still fall back to the
PC-101 `BaseCode` so `ctrl+c` keeps working.

Upstream test change in `key_test.go` (`TestKeystroke`):

| Case | Before | After |
|------|--------|-------|
| `{Code:'A', BaseCode:'a'}` | expected `a` | case removed |
| `{Code:'с', BaseCode:'c', Mod:ModCtrl}` | — | expects `ctrl+c` |
| `{Code:'s', BaseCode:';', Mod:ModCtrl}` | — | expects `ctrl+s` |
| `{Code:99999, BaseCode:'x'}` | expects `x` | unchanged |

Crystal today (`src/ultraviolet/key.cr`, `key_label`):

```crystal
code = @base_code != 0 ? @base_code : @code
```

This must become the two-clause rule: use `@base_code` only when `@code` is
outside ASCII or is not a printable character.

### 2. Windows cancel reader owns a cancel event

Go `cancelreader_windows.go` adds an auto-reset-off (`manual reset`) Win32 event
so `Close` cannot free a handle a reader is still waiting on (Windows reuses
handle numbers):

- new `conInputReader` state: `eventMu`, `cancelEvent`, `waiters`, `closed`,
  `eventFreed`;
- `NewCancelReader` creates the event (`CreateEvent(nil, 1, 0, nil)`);
- `Cancel` sets the event before `CancelIoEx`/`CancelIo`;
- `Close` is idempotent and safe while a reader waits; it resets console mode,
  signals the event, and frees it only when no waiter remains (the last waiter
  frees it otherwise);
- new `waitForInput` registers itself as a waiter, then
  `WaitForMultipleObjects([conin, event], false, INFINITE)` and frees the event
  on exit if `Close` already ran;
- error handling uses `errors.Join` so a failed mode reset and a failed handle
  close both surface.

Crystal today (`src/ultraviolet/cancelreader_windows.cr`, class
`ConInputReader`): no event, `cancel` only calls `CancelIoEx`/`CancelIo`, `close`
is not idempotent and calls `CloseHandle(@conin)`.

Note the pre-existing divergence: Go does **not** close the console input
handle in `Close`; Crystal does. Phase 2 should decide explicitly (default:
match Go, stop closing `@conin`, and record the change in
`plans/parity.md` if the old behavior is kept for a reason).

### 3. Windows terminal reader blocks instead of polling

Go `terminal_reader_windows.go`, `streamData`:

- new `emptyWakeBackoff = 10ms` constant;
- the inner poll loop now calls `cc.waitForInput()` instead of
  `time.Sleep(10ms)`;
- when the console handle wakes the reader but `Peek` returns no records
  (focus/menu/key-up/buffer-size records consumed elsewhere, or Windows Terminal
  spurious wake), it backs off for `emptyWakeBackoff` before waiting again, so a
  handle that stays signaled costs what polling did instead of a full core.

Crystal today (`src/ultraviolet/terminal_reader_windows.cr`,
`send_bytes_windows`): `records.empty?` sleeps `10.milliseconds` and `next`s.

## Crystal mapping

| Go | Crystal | Phase |
|----|---------|-------|
| `key.go` `Keystroke` | `src/ultraviolet/key.cr` `Key#key_label` | 1 |
| `key_test.go` `TestKeystroke` | `spec/key_spec.cr` keystroke table | 1 |
| `cancelreader_windows.go` | `src/ultraviolet/cancelreader_windows.cr` `ConInputReader` | 2 |
| `terminal_reader_windows.go` | `src/ultraviolet/terminal_reader_windows.cr` `send_bytes_windows` | 3 |
| `*.go.mod` / `*.go.sum` | none (Go-only dependency pins) | — |

## Change plan

Each phase is one atomic `port:` commit that satisfies the definition of done in
`AGENTS.md`.

### Phase 1 — `Key.Keystroke` base-code rule (all platforms) ✅

Commit: `port: prefer layout key in Keystroke`.

- `Key#key_label` now picks the PC-101 `@base_code` only when `@code` is above
  `0x7F` (Go's `unicode.MaxASCII`) or is not printable, via the new
  `base_code_preferred?`; ASCII printables keep the layout's own label.
- `spec/key_spec.cr` keystroke table: `"key with base code"` (`'A'`/`'a'` →
  `a`) replaced by the two upstream cases — `с`+`c`+ctrl → `ctrl+c` (non-ASCII
  fallback) and `s`+`;`+ctrl → `ctrl+s` (Dvorak ignores the base code) —
  with `"unknown key with base code"` (`x`) kept as the fallback case.
- Red → green: the Dvorak case failed first (`ctrl+;`), then passed; the
  Cyrillic case already passed and now guards the fallback from regressing.
- Reuses the existing `Ultraviolet.printable_char?` guard so out-of-range or
  surrogate `@code` values cannot raise.
- Gates: `make format-check`, `make lint`, `make test` (394 examples),
  `make inventory` (819 items).

### Phase 2 — Windows cancel reader event lifecycle

- Bind `CreateEventW`, `SetEvent`, and `WaitForMultipleObjects` alongside the
  existing console bindings in `cancelreader_windows.cr`; reuse
  `INFINITE`/`WAIT_*` from `terminal_reader_windows.cr` instead of redeclaring.
- Add `@event_mutex : Mutex`, `@cancel_event`, `@waiters`, `@closed`,
  `@event_freed` to `ConInputReader`; create the event in `initialize` and
  clean up the console mode if creation fails.
- Make `cancel` signal the event before `CancelIoEx`/`CancelIo`; make `close`
  idempotent, wake a waiting reader, free the event only when the last waiter
  leaves, and reset the console mode.
- Add `wait_for_input` mirroring `waitForInput` (waiter accounting + event
  free-on-exit).
- Crystal has no `errors.Join`: aggregate failure messages and raise one
  `IO::Error` (or log both) — document the divergence in the commit message.
- Decide the `CloseHandle(@conin)` question above and record the outcome.
- Verification on macOS: win32 code is not executed here. Keep the file
  `flag?(:win32)`-gated, run `make format-check`/`make lint` (Ameba parses the
  whole file), and re-read the diff against Go line by line. If a Linux CI with
  a Windows runner appears later, add the compile check there.

### Phase 3 — Windows terminal reader wait loop

- Add `EMPTY_WAKE_BACKOFF = 10.milliseconds`.
- In `send_bytes_windows`, replace the `records.empty?` sleep with
  `conin.wait_for_input` + backoff when the previous iteration woke without
  records; keep the `conin.canceled?` checks and the generic fallback for a
  plain `IO::FileDescriptor` handle.
- Same verification constraints as phase 2 (win32-gated, macOS cannot execute).

### Phase 4 — Re-baseline bookkeeping

- Confirm manifests/ledger still match: `make inventory`, `make parity` (no row
  changes expected — see "Symbol delta").
- Refresh `plans/parity.md` (**Where we are**, counts, phase table) and mark
  this file complete.
- Update the pinned commit in `AGENTS.md`, `README.md`, and
  `docs/development.md`, then delete the completed plan's "status: open" note.

## Testing strategy

- Phase 1 is fully testable on macOS/Linux: port the upstream cases verbatim
  (red first, then green) and keep every other keystroke expectation.
- Phases 2–3 are Windows-only. Coverage comes from (a) structural parity with
  Go, (b) `ameba`/format parsing of the gated file, and (c) specs that remain
  `flag?(:win32)`-gated (`spec/cancelreader_spec.cr`, `spec/terminal_reader_spec.cr`).
  Never claim a Windows behavior as verified without a Windows run; say
  "compiled-gated, not executed" in the commit message.
- Do not weaken `cancelreader_spec.cr` or `terminal_reader_spec.cr` to make the
  gate pass.

## Divergences to record

- `errors.Join` → aggregated single `IO::Error` (Crystal stdlib has no join).
- `Mutex` usage: Crystal's `Mutex` guards the event lifetime exactly like
  `sync.Mutex`; no re-entrancy, keep `Close`/`Cancel`/`waitForInput` lock-free
  inside the critical sections.
- `CloseHandle(@conin)` removal (if taken) is observable on Windows only; note
  it in `plans/parity.md`.
- `emptyWakeBackoff` / 10 ms backoff: same value as Go; no divergence.

## Gate state after the snapshot bump

The snapshot bump itself changes no symbols, so the repository stays green:

- `make lint` — pass
- `make test` — 394 examples, 0 failures
- `make inventory` — 819 items tracked
- `make parity` — 819 APIs, 196 tests

Phase 1 opened with a red spec (the Dvorak case failed against the old
`key_label`) and closed it in `port: prefer layout key in Keystroke`. Phases 2–3 change Windows-only
code, so `make test` stays green on macOS while parity comes from review.
