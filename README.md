# Ultraviolet

Crystal port of Charm's [Ultraviolet](https://github.com/charmbracelet/ultraviolet) terminal UI library. The upstream Go implementation is vendored at `vendor/ultraviolet/` for behavioral reference.

Status: **behavior-complete** against vendored Go `7cc6674`. [See parity plan](plans/parity.md).

## Installation

Add to `shard.yml`:

```yaml
dependencies:
  ultraviolet:
    github: dsisnero/ultraviolet
```

Then:

```bash
shards install
```

## Quick Start

```crystal
require "ultraviolet"

env = ENV.map { |key, value| "#{key}=#{value}" }
term = Ultraviolet::Terminal.new(STDIN, STDOUT, env)

term.start
term.enter_alt_screen

"Hello, World!".each_char_with_index do |char, idx|
  term.set_cell(idx, 0, Ultraviolet::Cell.new(char.to_s, 1))
end
term.display
```

See [examples/helloworld.cr](examples/helloworld.cr) for a complete interactive application.

## Features

### Terminal Screen & Input

- Full-window and inline rendering modes ([`TerminalScreen`](src/ultraviolet/terminal_screen.cr))
- Raw terminal mode with signal handling ([`Terminal`](src/ultraviolet/terminal.cr))
- Event-driven input: keyboard, mouse, paste, focus/blur, resize ([`EventDecoder`](src/ultraviolet/decoder.cr))
- Kitty keyboard protocol, modifyOtherKeys, Win32 input, bracketed paste
- Legacy key encoding support via `LegacyKeyEncoding`

### High-Performance Renderer

The [`TerminalRenderer`](src/ultraviolet/terminal_renderer.cr) minimizes terminal output using cell-based diffing and ANSI optimizations:

- REP (repeat character), ECH (erase character), ICH/DCH (insert/delete character)
- SD/SU (scroll down/up), IL/DL (insert/delete line)
- CHA/HPA/VPA (cursor positioning), CHT/CBT (tab movement)
- Color profile downsampling (TrueColor → 256 → 16 → ASCII)
- Backspace/tab optimization for cursor movement
- Per-terminal capability detection

### Cell-Based Buffer System

The [`Buffer`](src/ultraviolet/buffer.cr) / [`RenderBuffer`](src/ultraviolet/buffer.cr) / [`ScreenBuffer`](src/ultraviolet/buffer.cr) hierarchy provides:

- Cell-level read/write with wide character support (emoji, CJK)
- Touch tracking for efficient dirty-region rendering
- Clone, fill, clear area operations
- Insert/delete line/cell with bounds checking

### ANSI Styled Strings

[`StyledString`](src/ultraviolet/styled.cr) renders ANSI-escaped text with:

- SGR attribute parsing (bold, faint, italic, blink, reverse, conceal, strikethrough)
- TrueColor / 256 / 16 color foreground, background, underline
- Hyperlink (OSC 8) parsing
- Text wrapping, truncation with tail, placement functions

### Screen Window System

[`Window`](src/ultraviolet/window.cr) provides nested, resizable viewports:

- Parent-child hierarchy with relative positioning
- MoveTo, MoveBy, Resize, Clone, CloneArea
- Custom width methods for CJK/emoji/grapheme support

### Layout System

[Layout](src/ultraviolet/layout.cr) functions for constraint-based positioning:

- `Percent`, `Fixed`, `Ratio` constraints
- `SplitVertical`, `SplitHorizontal`
- 9 rect placement helpers: Center, TopLeft, TopRight, BottomLeft, etc.

### Cross-Platform Console I/O

[`Console`](src/ultraviolet/console.cr) provides a unified interface across platforms:

- Unix: TTY detection, raw/restore terminal state, `Winsize` queries
- Windows: `WinCon` console handle wrapper
- Environment variable access via `Environ`

### Poll-Based Event Reading

Platform-optimized poll readers in [`poll.cr`](src/ultraviolet/poll.cr):

- BSD/macOS: `kqueueReader` via Kqueue
- Linux: `epollReader` via Epoll
- Windows: `conReader` via Windows Console API
- Fallback: `fallbackReader` for non-TTY file descriptors

### Border Drawing

[`Border`](src/ultraviolet/border.cr) provides configurable box-drawing:

- Built-in styles: Normal, Rounded, Double, Thick, Hidden, Block, Markdown, ASCII
- Style/Link application without mutating base border
- `Draw` renders border into any `Screen` region

## Module Overview

| Module | Go Source | Crystal Source |
|--------|-----------|----------------|
| Terminal | [terminal.go](vendor/ultraviolet/terminal.go) | [terminal.cr](src/ultraviolet/terminal.cr) |
| TerminalScreen | [terminal_screen.go](vendor/ultraviolet/terminal_screen.go) | [terminal_screen.cr](src/ultraviolet/terminal_screen.cr) |
| TerminalRenderer | [terminal_renderer.go](vendor/ultraviolet/terminal_renderer.go) | [terminal_renderer.cr](src/ultraviolet/terminal_renderer.cr) |
| TerminalReader | [terminal_reader.go](vendor/ultraviolet/terminal_reader.go) | [terminal_reader.cr](src/ultraviolet/terminal_reader.cr) |
| EventScanner | [terminal_reader.go](vendor/ultraviolet/terminal_reader.go) (eventScanner) | [event_scanner.cr](src/ultraviolet/event_scanner.cr) |
| EventDecoder | [decoder.go](vendor/ultraviolet/decoder.go) | [decoder.cr](src/ultraviolet/decoder.cr) |
| Buffer | [buffer.go](vendor/ultraviolet/buffer.go) | [buffer.cr](src/ultraviolet/buffer.cr) |
| Cell/Style | [cell.go](vendor/ultraviolet/cell.go) | [cell.cr](src/ultraviolet/cell.cr), [style.cr](src/ultraviolet/style.cr) |
| StyledString | [styled.go](vendor/ultraviolet/styled.go) | [styled.cr](src/ultraviolet/styled.cr) |
| Console | [console.go](vendor/ultraviolet/console.go) | [console.cr](src/ultraviolet/console.cr) |
| Border | [border.go](vendor/ultraviolet/border.go) | [border.cr](src/ultraviolet/border.cr) |
| Window | [window.go](vendor/ultraviolet/window.go) | [window.cr](src/ultraviolet/window.cr) |
| Layout | [layout/layout.go](vendor/ultraviolet/layout/layout.go) | [layout.cr](src/ultraviolet/layout.cr) |
| Poll | [poll*.go](vendor/ultraviolet/) | [poll*.cr](src/ultraviolet/) |
| Winch | [winch.go](vendor/ultraviolet/winch.go) | [winch.cr](src/ultraviolet/winch.cr) |
| TabStops | [tabstop.go](vendor/ultraviolet/tabstop.go) | [tabstop.cr](src/ultraviolet/tabstop.cr) |
| Options | [terminal.go](vendor/ultraviolet/terminal.go) (Options) | [options.cr](src/ultraviolet/options.cr) |
| Key types | [key.go](vendor/ultraviolet/key.go), [key_table.go](vendor/ultraviolet/key_table.go) | [key.cr](src/ultraviolet/key.cr), [key_table.cr](src/ultraviolet/key_table.cr) |
| Mouse | [mouse.go](vendor/ultraviolet/mouse.go) | [mouse.cr](src/ultraviolet/mouse.cr) |
| Event types | [event.go](vendor/ultraviolet/event.go) | [event.cr](src/ultraviolet/event.cr) |
| TTY | [tty*.go](vendor/ultraviolet/) | [tty.cr](src/ultraviolet/tty.cr), [tty_state.cr](src/ultraviolet/tty_state.cr) |

## Documentation

- [Resuming work](docs/resuming.md) — start here in a new session
- [Architecture](docs/architecture.md) — repository layout and runtime layers
- [Development](docs/development.md) — setup, porting workflow, and parity checks
- [Coding Guidelines](docs/coding-guidelines.md) — behavior, style, and dependency rules
- [Testing](docs/testing.md) — spec layout and how to port Go tests
- [PR Workflow](docs/pr-workflow.md) — branch, gates, and review checklist
- [Parity Plan](plans/parity.md) — feature status, resume point, and remaining work
- [Tutorial](docs/TUTORIAL.md) — building a terminal application with Ultraviolet
- [API Reference](docs/API_REFERENCE.md) — Go-to-Crystal type mapping
- [Porting Map](PORTING.md) — source-to-source checklist
- [Examples](examples/) — runnable Crystal examples
- [Parity Manifests](plans/inventory/) — Go-vs-Crystal tracking
- [Port Audit](docs/plans/audit.md) — per-symbol audit notes
- [Unchecked Items](docs/plans/unchecked_items.md) — remaining missing ports

## Development

### Setup

```bash
make install
```

### Quality Gates

```bash
make format-check
make lint
make test
```

See [docs/development.md](docs/development.md) for the porting workflow, parity
scripts, and how to update the vendored Go source.

## Contributing

1. Fork it (<https://github.com/dsisnero/ultraviolet/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Port from Go source of truth, matching behavior exactly
4. Write Crystal specs matching Go test expectations
5. Run quality gates: `make format-check && make lint && make test`
6. Run the parity checks described in [docs/development.md](docs/development.md)
7. Commit and push
8. Create a Pull Request using [docs/pr-workflow.md](docs/pr-workflow.md)

## License

MIT — see [LICENSE](LICENSE).

## Contributors

- [Dom](https://github.com/dsisnero) — creator and maintainer
