# Ultraviolet Go → Crystal Porting Map

This document tracks the Go API surface and its Crystal counterparts. It is a
living checklist for parity and test coverage.

## Go Source Map (by file)
Legend:
- `[x]` implemented
- `[x] (partial)` implemented but not feature-complete
- `[ ]` missing

### Core Primitives
- [x] `ultraviolet_go/buffer.go` → `src/ultraviolet/buffer.cr`, `src/ultraviolet/geometry.cr` (Buffer, Line, RenderBuffer, ScreenBuffer, Position/Rectangle)
- [x] `ultraviolet_go/cell.go` → `src/ultraviolet/cell.cr`, `src/ultraviolet/style.cr` (Cell, Style, Attrs, Underline, Link, diffing)
- [x] `ultraviolet_go/uv.go` → `src/ultraviolet.cr`, `src/ultraviolet/cursor.cr`, `src/ultraviolet/window.cr` (Drawable, Screen, WidthMethod, Cursor, ProgressBar)
- [x] `ultraviolet_go/window.go` → `src/ultraviolet/window.cr`
- [x] `ultraviolet_go/cursor.go` → `src/ultraviolet/cursor.cr`

### Layout & Drawing Helpers
- [x] `ultraviolet_go/border.go` → `src/ultraviolet/border.cr`
- [x] `ultraviolet_go/layout.go` → `src/ultraviolet/layout.cr`
- [x] `ultraviolet_go/styled.go` → `src/ultraviolet/styled.cr`
- [x] `ultraviolet_go/tabstop.go` → `src/ultraviolet/tabstop.cr`

### Input & Events
- [x] `ultraviolet_go/event.go` → `src/ultraviolet/event.cr`
- [x] `ultraviolet_go/key.go` → `src/ultraviolet/key.cr`
- [x] (partial) `ultraviolet_go/key_table.go` → `src/ultraviolet/key_table.cr`
- [x] `ultraviolet_go/mouse.go` → `src/ultraviolet/mouse.cr`
- [x] (partial) `ultraviolet_go/decoder.go` → `src/ultraviolet/decoder.cr`
- [x] `github.com/charmbracelet/x/ansi` → `src/ultraviolet/ansi.cr`, `src/ultraviolet/ansi_color.cr` (parsing helpers and SGR mappings)

### Terminal Stack
- [x] (partial) `ultraviolet_go/terminal.go` → `src/ultraviolet/terminal.cr`
- [x] `ultraviolet_go/terminal_reader.go` → `src/ultraviolet/terminal_reader.cr`
- [x] `ultraviolet_go/terminal_reader_other.go` → `src/ultraviolet/terminal_reader.cr` (non-windows paths)
- [x] (partial) `ultraviolet_go/terminal_reader_windows.go` → `src/ultraviolet/terminal_reader.cr`
- [x] `ultraviolet_go/terminal_renderer.go` → `src/ultraviolet/terminal_renderer.cr`
- [x] `ultraviolet_go/terminal_renderer_hardscroll.go` → `src/ultraviolet/terminal_renderer_hardscroll.cr`
- [x] `ultraviolet_go/terminal_renderer_hashmap.go` → `src/ultraviolet/terminal_renderer_hashmap.cr`
- [x] `ultraviolet_go/screen/screen.go` → `src/ultraviolet/screen.cr`
- [x] `ultraviolet_go/tty.go` → `src/ultraviolet/tty.cr`
- [x] `ultraviolet_go/tty_other.go` → `src/ultraviolet/tty.cr` (non-windows paths)
- [x] (partial) `ultraviolet_go/tty_unix.go` → `src/ultraviolet/tty.cr`, `src/ultraviolet/tty_state.cr`
- [x] (partial) `ultraviolet_go/tty_windows.go` → `src/ultraviolet/tty.cr`
- [x] `ultraviolet_go/winch.go` → `src/ultraviolet/winch.cr`, `src/ultraviolet/winsize.cr`
- [x] `ultraviolet_go/winch_other.go` → `src/ultraviolet/winch.cr`
- [x] (partial) `ultraviolet_go/winch_unix.go` → `src/ultraviolet/winch.cr`
- [x] (partial) `ultraviolet_go/terminal_unix.go` → `src/ultraviolet/terminal_unix.cr`
- [x] (partial) `ultraviolet_go/terminal_windows.go` → `src/ultraviolet/terminal_windows.cr`
- [ ] `ultraviolet_go/terminal_other.go` → missing non-windows fallback parity
- [ ] `ultraviolet_go/poll.go` → missing
- [ ] `ultraviolet_go/poll_default.go` → missing
- [ ] `ultraviolet_go/poll_fallback.go` → missing
- [ ] `ultraviolet_go/poll_linux.go` → missing
- [ ] `ultraviolet_go/poll_bsd.go` → missing
- [ ] `ultraviolet_go/poll_select.go` → missing
- [ ] `ultraviolet_go/poll_solaris.go` → missing
- [ ] `ultraviolet_go/poll_windows.go` → missing
- [ ] `ultraviolet_go/terminal_tabdly.go` → missing
- [ ] `ultraviolet_go/terminal_tabdly_other.go` → missing
- [ ] `ultraviolet_go/terminal_bsdly.go` → missing
- [ ] `ultraviolet_go/terminal_bsdly_other.go` → missing

### Utilities & Glue
- [x] `ultraviolet_go/environ.go` → `src/ultraviolet/environ.cr`
- [x] `ultraviolet_go/logger.go` → `src/ultraviolet/logger.cr`
- [x] `ultraviolet_go/utils.go` → `src/ultraviolet/utils.cr`
- [x] `ultraviolet_go/cancelreader_other.go` → `src/ultraviolet/cancelreader.cr`
- [x] (partial) `ultraviolet_go/cancelreader_windows.go` → `src/ultraviolet/cancelreader.cr`
- [x] `ultraviolet_go/doc.go` → `src/ultraviolet.cr` (package docs)

### Examples & Docs
- [ ] `ultraviolet_go/examples/*` → missing Crystal examples
- [ ] `ultraviolet_go/TUTORIAL.md` → missing Crystal tutorial

## Tests (Parity Required)
- [x] `ultraviolet_go/buffer_test.go` → `spec/buffer_spec.cr`
- [ ] `ultraviolet_go/cell_test.go` → missing Crystal spec
- [x] `ultraviolet_go/style` coverage → `spec/style_spec.cr`
- [x] `ultraviolet_go/border_test.go` → `spec/border_spec.cr`
- [x] `ultraviolet_go/layout_test.go` → `spec/layout_spec.cr`
- [x] `ultraviolet_go/tabstop_test.go` → `spec/tabstop_spec.cr`
- [x] `ultraviolet_go/styled_test.go` → `spec/styled_spec.cr`
- [x] `ultraviolet_go/key_test.go` → `spec/key_spec.cr`
- [x] `ultraviolet_go/event_test.go` → `spec/event_spec.cr`
- [x] `ultraviolet_go/decoder_test.go` → `spec/decoder_spec.cr`
- [x] `ultraviolet_go/cancelreader_test.go` → `spec/cancelreader_spec.cr`
- [x] `ultraviolet_go/cursor_test.go` → `spec/cursor_spec.cr`
- [x] `ultraviolet_go/terminal_test.go` → `spec/terminal_spec.cr`
- [x] `ultraviolet_go/terminal_renderer_test.go` → `spec/terminal_renderer_spec.cr`
- [x] `ultraviolet_go/terminal_renderer_output_test.go` → `spec/terminal_renderer_output_spec.cr` (may need golden fixtures)
- [x] `ultraviolet_go/screen/screen_test.go` → `spec/screen_spec.cr`
- [ ] `ultraviolet_go/poll_test.go` → missing Crystal spec
- [ ] `ultraviolet_go/poll_default_test.go` → missing Crystal spec
- [ ] `ultraviolet_go/poll_fallback_test.go` → missing Crystal spec

## External Dependencies (Go → Crystal equivalents)
- [x] `github.com/charmbracelet/colorprofile` → `src/ultraviolet/colorprofile.cr`
- [x] `github.com/charmbracelet/x/ansi` → `src/ultraviolet/ansi.cr`, `src/ultraviolet/ansi_color.cr`
- [x] `github.com/muesli/cancelreader` → `src/ultraviolet/cancelreader.cr`
- [x] `github.com/xo/terminfo` → `shard.yml` dependency `terminfo`
- [x] `github.com/rivo/uniseg` → Crystal stdlib `TextSegment` for grapheme segmentation + `shard.yml` dependency `uniwidth` for widths
- [ ] `github.com/charmbracelet/x/term` → missing parity mapping (tty/term helpers)
- [ ] `github.com/charmbracelet/x/termios` → missing parity mapping (termios helpers)
- [ ] `github.com/charmbracelet/x/windows` → missing parity mapping (Win32 console helpers)
- [ ] `golang.org/x/sync` → missing parity mapping (errgroup/cond usage)
- [ ] `golang.org/x/sys` → missing parity mapping (syscalls and constants)

## Status
- Implemented in Crystal: core primitives (buffer/cell/style/geometry), layout helpers, screen,
  renderer core (hashmap/hardscroll), ansi/colorprofile integration, cursor/window, environ/logger/utils,
  cancelreader, and basic tty/winch/terminal scaffolding.
- Partially implemented: decoder/key_table, terminal/reader, unix/windows backends, tty/winch platform paths.
- Missing: poll system, terminal tab/bsd delay helpers, non-windows terminal_other parity,
  examples/tutorial docs, and poll/cell specs.
