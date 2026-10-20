# Vendor Update: 7cc6674 → 6b8d4ba

**Date:** 2026-10-19
**Previous vendor:** `7cc6674` (2026-07-20)
**Current vendor:** `6b8d4ba` (2026-10-08, upstream `main`)
**Crystal implementation tracks:** `7cc6674` plus the completed `6b8d4ba`
follow-ups

The vendored Go snapshot has been refreshed. Phases 1–9 are complete. Phase 10
is the next vendor refresh, deferred until upstream advances past `6b8d4ba`.

```text
67 commits
79 files changed
+4959 / -210
```

## Phase plan

Each phase is feature-sized and should land as one atomic commit. Details from
completed phases live in the commit history and specs rather than being expanded
into one-off work items here.

### Phase 1 — Vendor refresh + Program Status Protocol ✅

- Refresh `vendor/ultraviolet/` to `6b8d4ba`.
- Port OSC 7501 types, encoder, support event, decoder mapping, screen
  accessors, and reset/restore behavior.
- **Evidence:** `b2f6a0b`, `7661bb4`, `28371aa`;
  [`plans/ultraviolet.1.md`](ultraviolet.1.md); `spec/program_status_spec.cr`.

### Phase 2 — Styled strings + buffers ✅

- Carry terminated APC/DCS/SOS/PM sequences through cells.
- Fold combining marks; preserve hyperlink semicolons.
- Support clusters wider than four columns.
- Preserve trailing spaces in `Line#render`.
- Restore `RenderBuffer` resize/touched invariants.
- **Evidence:** `bcdf389`; `spec/styled_spec.cr`, `spec/buffer_spec.cr`,
  `spec/ultraviolet_spec.cr`.

### Phase 3 — Renderer damage + resize model ✅

- Add the screen-sized damage record and resize reconciliation.
- Repaint inline/fullscreen frames after resize without erasing untouched rows.
- Handle drift-prone rows with autowrap off and re-anchor the cursor.
- Keep corner clusters from leaving a pending wrap.
- Mark rows moved by hardware scrolls as damaged.
- **Evidence:** `d6dd62a`; `spec/terminal_renderer_resize_spec.cr`,
  `spec/terminal_renderer_spec.cr`, `spec/terminal_renderer_output_spec.cr`.

### Phase 4 — Terminal I/O robustness ✅

- Copy each reusable read buffer before dispatch.
- Keep the input loop's reader reference stable.
- Make `Terminal#stop` idempotent and safe before `Start`.
- Make `SelectReader` reads cancelable without wedging the scheduler.
- **Evidence:** `2a512a2`, `94f85f4`, `b357f5d`;
  `spec/terminal_reader_spec.cr`, `spec/terminal_spec.cr`, `spec/poll_spec.cr`.

### Phase 5 — Width + Unicode layout ✅

- Refresh the `ansi` shard to `7beb3d4` for WcWidth/GraphemeWidth parity.
- Cover wide, ZWJ, flag, skin-tone, and family clusters.
- Cover placeholder columns and `Cell.new_cell` widths.
- **Evidence:** `f68c0af`; `spec/width_spec.cr`.

### Phase 6 — API surface compatibility ✅

- Mouse pixel-to-cell conversion.
- `SizeNotifier` cell/pixel accessors.
- Multi-listener `NotifyWinch` and stop-channel `NotifyWinchContext` analogue.
- Console, constructor, and method aliases used by Go call sites.
- **Evidence:** `cc5ca2d`, `756d7a7`, `c8b0dc2`, `21e8aa8`, `08b76f2`,
  `8659366`, `2a85b32`; mouse, TTY, console, and alias specs.

### Phase 7 — Parity inventory refresh ✅

- Regenerated source, test, and curated inventory manifests from `6b8d4ba`.
- Preserved curated statuses/refs for matching items and removed stale ids.
- New baseline: 1015 items, 812 ported, 203 audit pending.
- **Evidence:** `check_source_parity` (819 items), `check_test_parity`
  (196 tests), and `check_port_inventory` (1015 items) pass.

### Phase 8 — Inventory triage ✅

- Resolved shared/inherited implementations: `RenderBuffer` accessors, Terminal
  getters, TerminalScreen methods, mouse enums, window constructor.
- Mapped Casso, LRU, and Layout rows to their consolidated Crystal files.
- Classified examples and Go conformance tooling as intentional divergences.
- Added the remaining renderer regressions for hyperlink row reopening and the
  drift short-circuit.
- **Result:** 954 ported, 61 intentional divergences, 0 missing.
- **Evidence:** `check_source_parity` (819 items), `check_test_parity`
  (196 tests), and `check_port_inventory` (1015 items) pass.

### Phase 9 — Conformance harness assessment ✅

Assessed and intentionally not ported. The harness's value comes from
differential comparison against a Go/cgo terminal-emulator oracle; porting only
the decoder/operation layer would add maintenance without screen-level
assertions. Crystal already covers the portable cases with 394 specs and the
inventory has zero missing runtime rows.

**Decision record:** [`plans/conformance-assessment.md`](conformance-assessment.md)

### Phase 10 — Next vendor refresh (deferred)

Repeat this workflow when upstream moves past `6b8d4ba`.

## Dependency and platform notes

- Upstream moved to `ansi v0.11.9`; the Crystal `ansi` shard is at `7beb3d4`.
- Upstream moved to `terminfo v1.0.0`; compare against the current
  `dsisnero/terminfo` dependency when touching capability lookup.
- Upstream now requires Go 1.26; this has no direct Crystal equivalent.

## Verification after each phase

```bash
make format-check
make lint
make test
```

Update `plans/parity.md`'s **Where we are** block and this phase plan as each
phase lands.
