# Vendor Update: 7cc6674 → 6b8d4ba

**Date:** 2026-10-19
**Previous vendor:** `7cc6674` (2026-07-20)
**Current vendor:** `6b8d4ba` (2026-10-08, upstream `main`)
**Crystal implementation tracks:** `7cc6674` plus the completed `6b8d4ba`
follow-ups

The vendored Go snapshot has been refreshed. Phases 1–6 are complete. Phase 7
(refresh the parity inventories) is next; Phase 8 evaluates the optional Go
conformance harness.

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

### Phase 7 — Parity inventory refresh (next)

Feature-sized scope:

- Regenerate the source and test manifests from `6b8d4ba`.
- Reconcile the curated `go_port_inventory.tsv` with the new manifests.
- Resolve stale `missing` rows that are actually ported, and stale references.
- Re-run the parity checks and record the remaining true gaps.

**Done when:** `check_source_parity`, `check_test_parity`, and
`check_port_inventory` are current and their remaining findings are documented.

### Phase 8 — Conformance harness assessment (deferred)

Decide whether the Go `internal/conformance` harness adds coverage the Crystal
renderer specs cannot express. Port only the portable corpus/operation layer if
it does; record a divergence for the Go-only emulator oracle.

### Phase 9 — Next vendor refresh (deferred)

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
