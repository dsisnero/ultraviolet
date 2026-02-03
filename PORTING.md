# Ultraviolet Go → Crystal Porting Map

This document tracks the Go API surface and its Crystal counterparts. It is a
living checklist for parity and test coverage.

## Core Primitives
- `ultraviolet_go/cell.go` → `src/ultraviolet/cell.cr` (Cell, Link, Style, attrs, underline, diff)
- `ultraviolet_go/buffer.go` → `src/ultraviolet/buffer.cr` (Line/Lines/Buffer/RenderBuffer/ScreenBuffer)
- `ultraviolet_go/uv.go` → `src/ultraviolet/*.cr` (Drawable, Screen, WidthMethod, Cursor, ProgressBar)
- `ultraviolet_go/geometry` (Position/Rectangle) → `src/ultraviolet/geometry.cr`

## Layout & Drawing Helpers
- `ultraviolet_go/border.go` → `src/ultraviolet/border.cr`
- `ultraviolet_go/layout.go` → `src/ultraviolet/layout.cr`
- `ultraviolet_go/styled.go` → `src/ultraviolet/styled.cr`
- `ultraviolet_go/tabstop.go` → `src/ultraviolet/tabstop.cr`

## Input & Events
- `ultraviolet_go/event.go` → `src/ultraviolet/event.cr`
- `ultraviolet_go/key.go` → `src/ultraviolet/key.cr`
- `ultraviolet_go/mouse.go` → `src/ultraviolet/mouse.cr`
- `ultraviolet_go/decoder.go` → `src/ultraviolet/decoder.cr`

## Terminal Stack
- `ultraviolet_go/terminal.go` → `src/ultraviolet/terminal.cr`
- `ultraviolet_go/terminal_reader*.go` → `src/ultraviolet/terminal_reader.cr`
- `ultraviolet_go/terminal_renderer*.go` → `src/ultraviolet/terminal_renderer.cr`
- `ultraviolet_go/poll*.go` → `src/ultraviolet/poll*.cr`
- `ultraviolet_go/tty*.go` → `src/ultraviolet/tty*.cr`
- `ultraviolet_go/winch*.go` → `src/ultraviolet/winch*.cr`
- `ultraviolet_go/window.go` → `src/ultraviolet/window.cr`
- `ultraviolet_go/cursor.go` → `src/ultraviolet/cursor.cr`
- `ultraviolet_go/screen/*` → `src/ultraviolet/screen/*`

## Utilities
- `ultraviolet_go/environ.go` → `src/ultraviolet/environ.cr`
- `ultraviolet_go/logger.go` → `src/ultraviolet/logger.cr`
- `ultraviolet_go/utils.go` → `src/ultraviolet/utils.cr`
- `ultraviolet_go/cancelreader*.go` → `src/ultraviolet/cancelreader*.cr`

## Tests (Parity Required)
- `ultraviolet_go/*_test.go` → `spec/ultraviolet/*_spec.cr`
- `ultraviolet_go/terminal_renderer_output_test.go` may require golden fixtures.

## External Dependencies (Go → Crystal equivalents)
- `github.com/charmbracelet/x/ansi` (SGR, parsing, mouse/button defs)
- `github.com/charmbracelet/colorprofile` (color conversion)
- `github.com/muesli/cancelreader` (cancelable reader)
- `github.com/rivo/uniseg` (grapheme segmentation / widths)
- `github.com/xo/terminfo` (terminal capabilities)
- platform APIs (termios, windows console, poll/select/epoll/kqueue)

## Status
- Implemented in Crystal: `cell`, `style`, `geometry`, `buffer` (Line/Lines/Buffer/RenderBuffer/ScreenBuffer),
  `colorprofile`, `ansi_color`, `layout`, `border`, `tabstop`, `styled`,
  input/event scaffolding (`ansi`, `key`, `key_table` (partial), `mouse`, `event`, `decoder` (partial)).
- Specs ported: `buffer`, `border`, `layout`, `style`, `tabstop`, `styled`.
- Pending: input/events (event/key/mouse/decoder), cursor, window/screen, terminal stack,
  utils/environ/logger/cancelreader, platform backends, terminal renderer tests (may need golden fixtures).
