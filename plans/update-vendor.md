# Plan: Update Crystal Port to Match vendored Go Source

**Date:** 2026-07-27
**Go source:** `vendor/ultraviolet` at `7cc6674`
**Old pinned:** `ultraviolet_go` submodule at `524a660`
**Diff:** ~80 commits, 25 source files changed (+2581/−409)

---

## Overview

The Crystal port is synced to the old Go source at `524a660`. Between `524a660`
and `7cc6674` the Go codebase added several major subsystems and made breaking
API changes. This plan catalogs every gap and prescribes the order of work.

---

## P0 — Missing Subsystems (not ported at all)

### 1. Cassowary constraint solver (`internal/casso/`)

**Go:** `vendor/ultraviolet/internal/casso/math.go` (172 lines), `solver.go` (275 lines)
**Crystal:** Not present.

A linear constraint solver with:
- `Symbol`, `Term`, `Constraint` types
- `Op` enum: `EQ`, `GTE`, `LTE`
- `Priority` type (strength levels)
- `Solver` with `NewSolver()`, `Add(priority, constraint)`, `Val(symbol)`
- Simplex-style optimization

**Action:** Port `internal/casso/` to `src/ultraviolet/layout/casso/`.

---

### 2. Generic LRU cache (`internal/lru/`)

**Go:** `vendor/ultraviolet/internal/lru/lru.go` (69 lines)
**Crystal:** Not present.

A fixed-size generic LRU cache using a doubly-linked list + map.

**Action:** Port `internal/lru/` to `src/ultraviolet/layout/lru.cr`.

---

### 3. Layout system (`layout/` — major rewrite)

**Go:** 6 files: `layout.go` (1046 lines), `constraint.go` (174), `flex.go` (210),
`padding.go` (66), `cache.go` (29), `layout_test.go`
**Crystal:** `src/ultraviolet/layout.cr` has the old API (`Percent`, `Fixed`,
`split_vertical`, `split_horizontal`, `center_rect`, etc.) — which was *removed*
in the Go source.

**New Go API to port:**

| Type | Description |
|------|-------------|
| `Constraint` | Sealed interface: `Min`, `Max`, `Len`, `Percent`, `Ratio`, `Fill` |
| `Direction` | `Vertical` (0), `Horizontal` (1) |
| `Flex` | 8-way enum: `Start`, `Legacy`, `End`, `Center`, `SpaceBetween`, `SpaceEvenly`, `SpaceAround` |
| `Padding` | `{Top, Right, Bottom, Left int}` with `Pad()` CSS-like shorthand |
| `Layout` | `{Direction, Constraints, Padding, Spacing, Flex}` + `Split()`, `SplitWithSpacers()`, builder methods |
| `Splitted` | `[]Rectangle` with `Assign()` |

Old layout helpers (`split_vertical`, `center_rect`, etc.) were all **removed**
from Go. The Crystal `layout.cr` must be replaced, not amended.

**Action:** Rewrite `src/ultraviolet/layout.cr` to match the new Cassowary-based
API. Drop old helper functions. Add new files for `constraint`, `flex`,
`padding`, `cache`.

---

## P1 — TerminalScreen API changes (breaking)

### 4. Error return removal

**Go:** Most `TerminalScreen` methods now return `void` instead of `error`:
`Resize`, `Render`, `EnterAltScreen`, `ExitAltScreen`, `HideCursor`,
`ShowCursor`, `SetCursorPosition`, `SetCursorStyle`, `SetCursorColor`,
`SetBackgroundColor`, `SetForegroundColor`, `EnableBracketedPaste`,
`DisableBracketedPaste`, `SetMouseMode`, `SetWindowTitle`,
`SetKeyboardEnhancements`, `SetProgressBar`, `Reset`, `Restore`.

**Crystal:** These methods currently may raise or return values. Need to remove
error-raising from these specific methods.

**Action:** Change signatures in `src/ultraviolet/terminal_screen.cr` to match
Go's void returns. Update callers in `terminal.cr` and specs.

---

### 5. New TerminalScreen methods

**Go added:**
- `Width() int` / `Height() int`
- `StringWidth(str string) int`
- `SetSynchronizedUpdates(enabled bool)` / `SynchronizedUpdates() bool`
- `SetMouseEncoding(enc MouseEncoding)` / `MouseEncoding() MouseEncoding`

**Action:** Add these to `src/ultraviolet/terminal_screen.cr`.

---

### 6. Terminal API changes

**Go changes:**
- `Terminal.SetLogger(Logger)` — **removed**. Logger now set via `Options.Logger`
- `Terminal.GetSize() (w, h int, err error)` — new
- `Terminal.GetWinsize() (*Winsize, error)` — new
- `Terminal.Stop()` — now safe to call before Start and idempotent
- `Terminal.Start()` — auto-negotiates grapheme width mode

**Action:**
- Add `logger` field to `Options` in `src/ultraviolet/options.cr`
- Remove `Terminal#set_logger` if present
- Add `Terminal#get_size` / `Terminal#get_winsize`
- Ensure `stop` is safe to call multiple times

---

### 7. `NewScreen` → `NewWindow`

**Go:** `NewScreen(width, height)` removed, replaced by
`NewWindow(width, height, method WidthMethod)`.

**Crystal:** `Window.new_screen` exists in `window.cr`.

**Action:** Rename/alias `new_screen` to `new_window` with the new signature.
Third argument defaults to `nil` (→ `ansi.WcWidth`).

---

### 8. Window struct changes

**Go:** `NewWindow` now takes a `WidthMethod` parameter (was hardcoded before).

**Action:** Update `Window` initialization to accept an optional width method.

---

## P2 — New feature additions

### 9. Mouse encoding (`MouseEncoding` type)

**Go:** New `MouseEncoding` type (`uint8`) with:
- `MouseEncodingLegacy` (0) — X10 compatible
- `MouseEncodingSGR` (1) — DEC mode 1006
- `MouseEncodingSGRPixel` (2) — DEC mode 1016, pixel coords
- `MousePixelToCell(m Mouse, ws *Winsize) Mouse` — converts pixel to cell coords

**Go also added:** `EncodeMouseEncoding(w io.Writer, enc MouseEncoding) error` in `uv.go`.

**Crystal:** `mouse.cr` has `MouseMode` but no `MouseEncoding`.

**Action:**
- Add `MouseEncoding` enum to `src/ultraviolet/mouse.cr`
- Add `encode_mouse_encoding` to `src/ultraviolet/uv_api.cr`
- Add `mouse_pixel_to_cell` helper
- Wire into `TerminalScreen`

---

### 10. Synchronized updates (DEC mode 2026)

**Go:** `TerminalScreen` gained `SetSynchronizedUpdates(bool)` /
`SynchronizedUpdates() bool`. Flush wraps output in DEC 2026 sequences.

**Crystal:** `TerminalScreen` has no sync updates support.

**Action:**
- Add `@synchronized_updates` field to `TerminalScreen`
- Implement `set_synchronized_updates` / `synchronized_updates?`
- Wrap flush output in DEC 2026 when enabled

---

### 11. Grapheme width mode negotiation (DEC mode 2027)

**Go:** `TerminalScreen` gained `requestGraphemeWidth()` and
`enableGraphemeWidth()`. `TerminalRenderer` gained `SetGraphemeWidth(bool)` and
`SetWidthMethod(ansi.Method)`.

**Crystal:** No grapheme width negotiation exists. `TerminalRenderer` uses
`TextSegment.each_grapheme` for rendering but does not negotiate mode 2027 with
the terminal.

**Action:**
- Add DECRQM/DECSET mode 2027 logic to `TerminalScreen`
- Add `set_grapheme_width` and `set_width_method` to `TerminalRenderer`
- Wire into `Terminal.start`

---

### 12. `RenderBuffer` new methods

**Go added:** `Clear()`, `ClearArea(Rectangle)`, `Fill(*Cell)`, `FillArea(*Cell, Rectangle)`.

**Crystal:** `RenderBuffer` has `fill`, `clear`, `draw` but may not have
`clear_area` / `fill_area`.

**Action:** Add `clear_area` and `fill_area` if missing.

---

### 13. `Terminal.StreamEvents` goroutine safety

**Go:** `StreamEvents` now uses `sync.WaitGroup` to ensure the streaming
goroutine completes before returning.

**Crystal:** Check `stream_events` in `terminal_reader.cr` for fiber leak on
error/cancel paths. Add `WaitGroup` equivalent if needed.

---

## P3 — Additional smaller changes

### 14. `uv.go` changes

- `EncodeMouseMode` — updated with `MouseModePress` case and no internal error
- `EncodeMouseEncoding` — new function
- `KeyboardEnhancements` — new fields: `ReportAlternateKeys`,
  `ReportAllKeysAsEscapeCodes`, `ReportAssociatedText`

**Action:** Update `uv_api.cr` to match.

### 15. `mouse.go` enum shift

`MouseMode` values changed:
- `MouseModeNone` = 0 (unchanged)
- `MouseModePress` = 1 (NEW)
- `MouseModeClick` = 2 (was 1)
- `MouseModeDrag` = 3 (was 2)
- `MouseModeMotion` = 4 (was 3)

**Action:** Update `MouseMode` enum values in `mouse.cr`.

### 16. `screen/screen.go` wide-cell handling

`FillArea` and `CloneArea` now iterate by `cell.Width` instead of by 1.

**Action:** Update `screen.cr` wide-cell iteration to match.

### 17. `styled.go` bounds check

Added early-exit when `y >= bounds.Max.Y`.

**Action:** Verify `print_string` in `styled.cr` has this guard.

---

## Execution Order

| Phase | Items | Estimated Effort |
|-------|-------|------------------|
| 1 | P0#1 (casso solver) | 2–3 days |
| 2 | P0#2 (LRU cache) | 0.5 day |
| 3 | P0#3 (layout rewrite) | 2–3 days |
| 4 | P1#4 (error return removal) | 0.5 day |
| 5 | P1#5–6, P2#10–11 (TerminalScreen features) | 1 day |
| 6 | P1#7–8 (NewScreen→NewWindow) | 0.5 day |
| 7 | P2#9 (mouse encoding) | 0.5 day |
| 8 | P2#12–13, P3#14–17 (smaller items) | 0.5 day |

Total: ~8–10 days of porting work.

---

## Verification

After each phase:
```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

The chiasmus snapshot `ultraviolet-vendor-initial` (59 files, 640 functions,
1500 call edges) was taken at `7cc6674` for future diff comparisons.
