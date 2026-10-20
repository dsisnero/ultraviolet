# Ultraviolet Parity Plan

Ultraviolet is a Crystal port of the Go [ultraviolet](https://github.com/charmbracelet/ultraviolet) terminal UI library. The Go source is vendored at `vendor/ultraviolet/` (commit `6b8d4ba`).

## Where we are

- **Active plan:** [Vendor update `7cc6674` → `6b8d4ba`](update-vendor-6b8d4ba.md)
  — use its checklist as the working order.
- **Current focus:** the `7cc6674` → `6b8d4ba` vendor delta is ported. Next is
  inventory cleanup and the optional conformance harness.
- **Next up:**
  1. Regenerate the parity inventories against the refreshed vendor tree.
  2. Assess and port the optional conformance harness where it adds coverage.
  3. Resume upstream tracking when the next vendor snapshot is available.
- **Chunk status:**
  - **Ported:** core types, layout, console/TTY, poll, winch, encode helpers,
    OSC 7501, program status reset/restore, styled-string/buffer fixes, the
    renderer damage/resize model, terminal input-loop fixes, width handling,
    idempotent `Terminal#stop`, mouse pixel-to-cell conversion, and
    `SizeNotifier` compatibility accessors.
  - **In progress:** inventory regeneration.
  - **Remaining:** the optional conformance harness.
- **Last commit:** `cc5ca2d` (`port: add mouse pixel-to-cell conversion`).
- **Gates:** `make lint` and `make test` pass (`384` examples).

> **Synced to:** `6b8d4ba` (vendored snapshot; Crystal implementation tracks
> `7cc6674` plus the program status, styled/buffer, renderer, input-loop, and
> width follow-ups)

## Status Overview

| Area | Go Items | Crystal Status |
|------|----------|----------------|
| Core types (Border, Cell, Key, Mouse, Event) | ~200 APIs | Ported |
| Buffer system (Buffer, RenderBuffer, ScreenBuffer) | ~60 APIs | Ported |
| Terminal Screen (TerminalScreen, Window) | ~50 APIs | Ported |
| Terminal / Event Loop (Terminal, TerminalReader) | ~30 APIs | Ported* |
| Renderer (TerminalRenderer, optimizations) | ~40 APIs | Ported |
| Styled strings / ANSI parsing | ~20 APIs | Ported |
| Layout, Tabstops, Cursor, Color | ~30 APIs | Ported |
| Console/TTY I/O | ~30 APIs | Ported |
| Poll readers (epoll, kqueue, fallback, Windows) | ~20 APIs | Ported |
| Winch / SizeNotifier | ~6 APIs | Ported |
| Screen Context | ~50 APIs | Ported |
| Encode helpers (uv.go) | ~15 APIs | Ported |
| **Test coverage** | 122 Go tests | 384 Crystal specs |
| **Source API parity** | 704 Go APIs | 703 ported, 1 skipped |
| **Port inventory** | 826 items | 825 ported, 1 skipped |

\* Crystal merges Terminal + Screen into one class; Go keeps them separate.

Crystal extracts `EventScanner` from `TerminalReader`, matching Go's
`eventScanner`. Merging Terminal and Screen is an architectural divergence with
no behavioral impact.

## Recent Porting Progress

| Session | Tests Added | Areas |
|---------|------------|-------|
| 2026-10-19 | +1 spec | SizeNotifier `GetWindowSize` / `GetSize` compatibility |
| 2026-10-19 | +2 specs | Mouse pixel-to-cell conversion and wide-cell reanchor coverage |
| 2026-10-19 | +2 specs | Terminal stop: safe before start and idempotent |
| 2026-10-19 | +3 specs | Width handling: WcWidth/GraphemeWidth cell layout, placeholder columns, ZWJ/flag/skin-tone/family clusters, Cell.new_cell |
| 2026-10-19 | +1 spec | Terminal input loop: reusable read buffer copied before dispatch |
| 2026-10-19 | +21 specs | Renderer damage/resize: inline/fullscreen resize, repaint latching, drift/autowrap, corner clusters, scroll repaint, short touch lists |
| 2026-10-19 | +14 specs | Styled strings and buffers: pass-through sequences, combining marks, hyperlink URLs, trailing spaces, wide clusters, RenderBuffer resize/touched |
| 2026-10-19 | +1 spec | Program status reset/restore parity (`TestTerminalScreenProgramStatus`) |
| 2026-10-19 | Vendor refreshed | `vendor/ultraviolet` `7cc6674` → `6b8d4ba`; Crystal port unchanged, work tracked in the active plan |
| 2026-10-19 | +8 specs | Program Status Protocol (OSC 7501): encoding, support event, screen accessors |
| 2025-05-26 | +42 specs | terminal_screen reset/restore (5), X10 mouse (8), SGR mouse (9), helpers (3), scan_events (3), grapheme buf (2), TerminalReader stream (14) |
| Manifest | Updated | Source parity (703/704), Port inventory (825/826), Options struct (F1), EventScanner extraction (F2) |

## Completed Items

### F3. TerminalScreen `Reset` completeness ✅

Go emits `KittyKeyboard(0,1)` before exiting alt screen to prevent mis-rendered
characters. Crystal's `reset` method was missing this emission.

**Fix:** Added `Ansi.kitty_keyboard(0, 1)` emission before
`ResetModeAltScreenSaveCursor` when alt screen is active and keyboard
enhancements are configured. Also tightened cursor visibility, cursor color
reset, background/foreground reset, and progress bar state checks to match Go's
pattern of writing reset sequences directly rather than going through setters.

**Files changed:** `src/ultraviolet/terminal_screen.cr` (reset method, lines 276-338)
**Specs:** `spec/terminal_screen_spec.cr` (KittyKeyboard order + restore cycle, lines 69-143)

### F3b. TerminalScreen `Restore` parity ✅

Crystal's `restore` was calling setter methods (`enter_alt_screen`, `set_keyboard_enhancements`, etc.) that mutate internal state. After `reset` cleared state fields, `restore` had nothing to restore.

**Fix:** Rewrote `restore` to emit raw ANSI sequences directly (matching Go's pattern of `sb.WriteString(ansi.SetModeAltScreenSaveCursor)` etc.), never modifying internal state. Also rewrote `reset` to use raw ANSI writes for mouse mode, cursor style, bracketed paste, window title, progress bar, and keyboard enhancements — preserving state for the restore cycle.

**Files changed:** `src/ultraviolet/terminal_screen.cr` (reset lines 276-338, restore lines 340-374)
**Specs:** `spec/terminal_screen_spec.cr` (2 new: keyboard/cursor restore after reset, lines 91-143)

### F4. `rgbToHSL` / `isDarkColor` color helpers ✅

Already present in Crystal at `src/ultraviolet/event.cr`:

- `Ultraviolet.rgb_to_hsl(r, g, b)` → matches Go's `rgbToHSL`
- `Ultraviolet.dark_color?(color)` → matches Go's `isDarkColor`
- `ForegroundColorEvent#dark?`, `BackgroundColorEvent#dark?`, `CursorColorEvent#dark?` all delegate to `Ultraviolet.dark_color?`

No changes needed.

### F5. `StyledString#Lines` parity ✅

Go's `Lines` delegates to `printString(nil, ...)`. Crystal's `lines` uses inline
logic with the same helper functions (`handle_escape`, `read_print_segment`,
`TextSegment.each_grapheme`). Behavior is equivalent for ANSI SGR/OSC parsing,
grapheme segmentation, and line decomposition.

No changes needed.

### F6. Buffer concurrent resize safety ✅

Go commit `29fb728` added a bounds re-check in `TouchLine` to guard against
concurrent resize clearing the `Touched` slice. Crystal's `touch_line` method
already has this guard (`return if y >= @touched.size` on line 586 of
`buffer.cr`).

Go commit `7b43eda` removed the `maxCellWidth` traversal limit for wide cells.
Crystal's `clear_wide_left` never had a limit — it uses `while x - j >= 0`.

No changes needed.

### F7. Program Status Protocol (OSC 7501) ✅

Added typed program status support: `Ansi::ProgramStatus` encoding from the
`ansi` shard, `Ultraviolet::ProgramStatusSupportEvent` for `OSC 7501;?` replies,
and `TerminalScreen#set_program_status` / `#program_status`.

**Files changed:** `src/ultraviolet/program_status.cr`,
`src/ultraviolet/decoder.cr`, `src/ultraviolet/event.cr`,
`src/ultraviolet/terminal_screen.cr`
**Specs:** `spec/program_status_spec.cr` (9 examples)
**Tracking:** [`plans/ultraviolet.1.md`](ultraviolet.1.md)
**Divergence:** none. Upstream `6b8d4ba` provides the types through
`charmbracelet/x/ansi`; the Crystal port uses the `ansi` shard for the same
types. `reset` leaves the program status record in place and `restore` re-emits
it, matching upstream.

### F8. Styled strings and buffers (vendor `6b8d4ba`) ✅

Ported the `6b8d4ba` styled-string and buffer behavior: terminated APC/DCS/SOS/PM
pass-through sequences, combining-mark folding, unbounded `Lines`, semicolons in
hyperlink URLs, clusters wider than four columns, trailing-space preservation in
`Line#render`, and the `RenderBuffer` resize/touched-row invariant.

**Files changed:** `src/ultraviolet/styled.cr`,
`src/ultraviolet/buffer.cr`, `src/ultraviolet/terminal_screen.cr`
**Specs:** `spec/styled_spec.cr`, `spec/buffer_spec.cr`,
`spec/ultraviolet_spec.cr`

### F9. Renderer damage and resize model (vendor `6b8d4ba`) ✅

Ported the renderer's damage record and resize reconciliation: latching real
terminal size changes, repainting after fullscreen/inline resizes, erasing only
the rows an inline frame gives up, keeping drift-prone rows from wrapping, and
marking rows moved by hardware scrolls.

**Files changed:** `src/ultraviolet/terminal_renderer.cr`,
`src/ultraviolet/terminal_renderer_hardscroll.cr`,
`src/ultraviolet/terminal_renderer_hashmap.cr`,
`src/ultraviolet/buffer.cr`
**Specs:** `spec/terminal_renderer_resize_spec.cr`,
`spec/terminal_renderer_spec.cr`, `spec/terminal_renderer_output_spec.cr`

### F10. Terminal input loop (vendor `6b8d4ba`) ✅

The Crystal reader now reuses a single read buffer and copies each chunk before
sending it to the event loop, matching upstream's input-loop fix. The input loop
already captured a stable local reader reference, so the Go stop-time nil
dereference has no Crystal equivalent; a comment records the invariant.

**Files changed:** `src/ultraviolet/terminal_reader.cr`,
`src/ultraviolet/terminal.cr`
**Specs:** `spec/terminal_reader_spec.cr`

### F11. Width handling (vendor `6b8d4ba`) ✅

Refreshed the `ansi` shard to `7beb3d4` for `WcWidth`/`GraphemeWidth` parity
with upstream `ansi v0.11.9`, and added width regression specs for clusters
wider than four columns, placeholder columns, and `Cell.new_cell`.

**Dependency:** `ansi` shard `7beb3d4` (`shard.lock` is gitignored)
**Specs:** `spec/width_spec.cr`

### F12. Terminal stop lifecycle (vendor `6b8d4ba`) ✅

Ported `TestStopBeforeStart` and `TestStopIdempotent`. `Terminal#stop` now returns
quietly when the terminal is not running instead of raising `ErrNotRunning`, so
shutdown paths can call it safely before `Start` or more than once.

**Files changed:** `src/ultraviolet/terminal.cr`
**Specs:** `spec/terminal_spec.cr`

### F13. Mouse pixel-to-cell conversion ✅

Ported `MousePixelToCell` for `MouseEncoding::SGRPixel` input, preserving button
and modifier state while converting pixel coordinates through the terminal's
reported cell and pixel dimensions. Also added the wide-cell reanchor regression.

**Files changed:** `src/ultraviolet/mouse.cr`
**Specs:** `spec/mouse_spec.cr`, `spec/terminal_renderer_resize_spec.cr`

### F14. SizeNotifier compatibility accessors ✅

Ported the exported `GetWindowSize` and `GetSize` names as `get_window_size` and
`get_size`, delegating to the existing cell/pixel size implementation. Covered
with a stub notifier so the spec does not require a real TTY.

**Files changed:** `src/ultraviolet/winch.cr`
**Specs:** `spec/terminal_spec.cr`

## Remaining Work (Upstream-Limited)

All 8 remaining Crystal TODOs match Go's TODOs verbatim. These are open
investigations in both codebases, not porting gaps:

| Crystal Line | Go Line | Description |
|-------------|---------|-------------|
| `terminal_renderer.cr:214` | `terminal_renderer.go:325` | Use scrolling region if available |
| `terminal_renderer.cr:287` | `terminal_renderer.go:417` | Investigate case handling for erase |
| `buffer.cr:707` | `terminal_renderer.go:459` | Empty line scroll optimization artifacts |
| `terminal_renderer.cr:719` | `terminal_renderer.go:947` | Unnecessary cursor movements on resize |
| `terminal_renderer.cr:912` | `terminal_renderer.go:1149` | Investigate REP necessity for inline mode |
| `terminal_renderer.cr:936` | `terminal_renderer.go:1185` | Inline mode character repeat optimization |
| `terminal_renderer.cr:1079` | `terminal_renderer.go:1349` | Unintentional scrolling guard |
| `terminal_renderer.cr:1109` | `terminal_renderer.go:1383` | Linux console terminal edge case |

Next update cycle when upstream addresses these TODOs and/or commits new features.

### Architectural Divergences (Deferred)

### F1. Terminal `Options` struct

Go has `Options` struct with `BufferSize`, `EventTimeout`, `LegacyKeyEncoding`,
`LookupKeys`, `UseTerminfoKeys`. Crystal hardcodes defaults directly in
`Terminal` and `TerminalReader`. Adding an `Options` struct would be a public API
change.

### F2. eventScanner extraction ✅

Go refactored event scanning into a separate `eventScanner` struct. Crystal's
`TerminalReader` kept scanning logic inline.

**Fix:** Extracted `EventScanner` class from `TerminalReader`, matching Go's
`eventScanner` struct. EventScanner extends `EventDecoder` and contains:
scan_events (public), deserialize_win32_input, parse_win32_sequence,
encode_grapheme_bufs, store_grapheme_rune, control_char?, logf.
TerminalReader now holds an `@scanner` field and delegates event scanning.
State (lookup, logger) is synchronized between TerminalReader and scanner.

**Files changed:** `src/ultraviolet/event_scanner.cr` (new), `src/ultraviolet/terminal_reader.cr` (refactored to delegate)
**Specs:** Updated `TestTerminalReader` to delegate through `@scanner`

## Test Parity Status

All 18 Go test files covered by Crystal specs (381 total):

| Go Test File (Go tests) | Crystal Spec Status |
|---|---|
| `border_test.go` (5) | `border_spec.cr` |
| `buffer_test.go` (8) | `buffer_spec.cr` |
| `cancelreader_test.go` (1) | `cancelreader_spec.cr` |
| `cell_test.go` (3) | `style_spec.cr` |
| `cursor_test.go` (1) | `cursor_spec.cr` |
| `decoder_test.go` (7) | `decoder_spec.cr` + `decoder_function_spec.cr` |
| `event_test.go` (10) | `event_spec.cr` |
| `key_test.go` (17) | `key_spec.cr` + `decoder_*_spec.cr` + `terminal_reader_*_spec.cr` |
| `poll_default_test.go` (1) | `poll_spec.cr` |
| `poll_fallback_test.go` (2) | `poll_fallback_spec.cr` |
| `poll_test.go` (1) | `poll_spec.cr` |
| `terminal_renderer_output_test.go` (1) | `terminal_renderer_output_spec.cr` |
| `terminal_renderer_test.go` (41) | `terminal_renderer_spec.cr` |
| `terminal_test.go` (5) | `terminal_spec.cr` |
| `layout/layout_test.go` (5) | `layout_spec.cr` |
| `styled_test.go` (2) | `styled_spec.cr` |
| `tabstop_test.go` (5) | `tabstop_spec.cr` |
| `screen/screen_test.go` (9) | `screen_spec.cr` |

## Guardrails

- Do not weaken upstream tests or fixtures to make Crystal look green.
- Preserve behaviorally important internal data structures.
- Run `crystal spec` after each feature change.
- Update `go_port_inventory.tsv` rows as features close.
