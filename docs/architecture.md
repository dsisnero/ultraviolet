# Architecture

Ultraviolet is a Crystal port of Charm's Go
[ultraviolet](https://github.com/charmbracelet/ultraviolet) terminal UI library.
The Go source is vendored at `vendor/ultraviolet/` and is the behavioral source
of truth.

## Repository layout

| Path | Purpose |
|------|---------|
| `src/ultraviolet/` | Crystal implementation |
| `spec/` | Crystal specs, including Go-derived parity cases |
| `vendor/ultraviolet/` | Vendored Go source of truth |
| `plans/parity.md` | Feature status and resume point |
| `plans/inventory/` | Per-symbol port ledgers |
| `scripts/` | Parity manifest generators and verifiers |
| `docs/` | Project documentation |
| `examples/` | Runnable Crystal examples |
| `lib/` | Installed Crystal shards (not project source) |

## Runtime layers

The main path from application code to terminal output is:

```text
Terminal
  -> TerminalScreen
       -> ScreenBuffer / Buffer
       -> TerminalRenderer
            -> TerminalRendererHashmap or TerminalRendererHardscroll
            -> ANSI output
  -> TerminalReader / EventScanner / EventDecoder
       -> typed Ultraviolet events
```

- `Terminal` owns lifecycle and terminal mode setup.
- `TerminalScreen` exposes drawing, cursor, color, title, progress bar, and
  program status state.
- Buffers hold cells and dirty-region state used by the renderer.
- The renderer diffs cells and emits optimized ANSI sequences.
- The reader/scanner/decoder converts terminal input into typed events.

## Platform support

- Unix TTY handling lives in `terminal_unix.cr`, `tty.cr`, and `tty_state.cr`.
- Windows console handling lives in the `*_windows.cr` files.
- Poll readers are split by platform (`poll_bsd.cr`, `poll_linux.cr`,
  `poll_windows.cr`) with a portable fallback in `poll.cr`.

## Intentional divergences

- Crystal merges Go's `Terminal` and `Screen` responsibilities into
  `TerminalScreen`.
- `EventScanner` is extracted from `TerminalReader`, mirroring Go's
  `eventScanner`.
- Some Go dependencies are provided by Crystal shards (`ansi`, `terminfo`,
  `uniwidth`) instead of direct ports.

Parity details and deferred divergences live in `plans/parity.md` and
`PORTING.md`.
