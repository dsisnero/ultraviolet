# Ultraviolet Parity Plan

Ultraviolet is a Crystal port of the Go
[ultraviolet](https://github.com/charmbracelet/ultraviolet) terminal UI library.
The Go source is vendored at `vendor/ultraviolet/` (commit `8ecbcf0`).

## Where we are

- **Active plan:** none — [the `8ecbcf0` refresh](commit_8ecbcf0.md) is
  complete, so there is no open porting feature.
- **Current focus:** none. The 3-commit `8ecbcf0` delta (key layout rule,
  Windows cancel-event lifetime, Windows wait loop) is fully ported.
- **Next up:**
  1. **Next upstream refresh** when `charmbracelet/ultraviolet` moves past
     `8ecbcf0` (commit-based; the upstream publishes no tags). Reuse the
     comparison recipe and phase template in
     [commit_8ecbcf0.md](commit_8ecbcf0.md).
  2. **Optional follow-up:** decide whether to wire the `PollReader` family
     into `Terminal` the way Go does (see **Architectural divergences**; its
     `poll` must move off the raw syscall first). The `WAIT_FAILED` gap from
     the `8ecbcf0` delta is closed.
- **Chunk status:** `8ecbcf0` refresh complete (phases 1–4). Symbol inventory
  unchanged across the delta: 819 APIs, 196 tests, no ledger row changes.
- **Last code feature commit:** `port: surface a failed console wait` (hash
  recorded by the next commit).
- **Gates:** `make format-check`, `make lint`, `make test` (410 examples),
  `make check-win32`, `make test-linux` (410 examples on Linux), `make
  inventory` (819 items) and `make parity` (819 APIs / 196 tests) all pass. CI
  is green on ubuntu-latest, macos-latest and windows-latest, plus the lint job.

> **Synced to:** `8ecbcf0` (vendored snapshot; Crystal behavior tracks it in
> full).

## Commit plans

One file per upstream commit range; the current one is also the active plan.

| Plan | Range | Status |
|------|-------|--------|
| [update-vendor-6b8d4ba.md](update-vendor-6b8d4ba.md) | `7cc6674` → `6b8d4ba` | ✅ complete |
| [commit_8ecbcf0.md](commit_8ecbcf0.md) | `6b8d4ba` → `8ecbcf0` | ✅ complete |

## Feature phases

Each phase is sized for one branch or commit. Phases 1–9 are the
`7cc6674` → `6b8d4ba` refresh, tracked in
[update-vendor-6b8d4ba.md](update-vendor-6b8d4ba.md); phase 10 is the current
refresh, tracked in [commit_8ecbcf0.md](commit_8ecbcf0.md).

| Phase | Feature-sized scope | Status | Evidence |
|-------|---------------------|--------|----------|
| 1 | Vendor snapshot + Program Status Protocol (OSC 7501) | ✅ | `b2f6a0b`, `7661bb4`, `28371aa` |
| 2 | Styled strings + buffer parity | ✅ | `bcdf389` |
| 3 | Renderer damage + resize model | ✅ | `d6dd62a` |
| 4 | Terminal I/O robustness: input copy, stop lifecycle, cancelable reads | ✅ | `2a512a2`, `94f85f4`, `b357f5d` |
| 5 | Width + Unicode layout | ✅ | `f68c0af` |
| 6 | API surface compatibility: mouse, sizes, winch, aliases | ✅ | `cc5ca2d`, `756d7a7`, `c8b0dc2`, `21e8aa8`, `08b76f2`, `8659366`, `2a85b32` |
| 7 | Parity inventory refresh | ✅ | `plans/inventory/*` refreshed from `6b8d4ba` |
| 8 | Inventory triage | ✅ | 954 ported, 61 intentional divergences, 0 missing |
| 9 | Conformance harness assessment | ✅ | [Decision: not ported](conformance-assessment.md) |
| 10 | Vendor refresh `6b8d4ba` → `8ecbcf0` | ✅ | [Plan](commit_8ecbcf0.md) — `5d41995`, `e01962d`, `c9f8872`, `f01d432` |

## Status overview

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
| **Test coverage** | 196 Go tests | 410 Crystal specs |
| **Source API parity** | 819 Go APIs | 776 ported, 43 intentional divergences |
| **Test parity** | 196 Go tests | 178 ported, 18 intentional divergences |
| **Port inventory** | 1015 items | 954 ported, 61 intentional divergences |

No `missing` rows remain. The 61 divergences are examples, Go-only conformance
tooling, or Go-specific safety/allocation guards.

\* Crystal merges `Terminal` and `Screen`; Go keeps them separate. Crystal also
extracts `EventScanner` from `TerminalReader`, matching Go's `eventScanner`.

## Remaining work (upstream-limited)

All 8 remaining Crystal TODOs match Go's TODOs verbatim. They are open
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

Revisit when upstream addresses these TODOs or publishes a new vendor snapshot.

## Architectural divergences

- Crystal merges Go's `Terminal` and `Screen` responsibilities into
  `TerminalScreen`.
- `NotifyWinchContext` uses a stop channel because Crystal has no
  `context.Context`.
- ANSI parsing, width tables, and terminfo come from Crystal shards rather than
  direct ports.
- `CancelEventLifetime` holds the Windows cancel-event ownership decisions
  (`waiters`/`closed`/`freed`) that Go keeps inline in `conInputReader`, so the
  lifecycle is testable off Windows.
- `ConsoleWakeLoop` holds the peek/wait/backoff loop Go keeps inline in
  `streamData`, with the console calls injected, for the same reason.
- The `PollReader` family (`poll.cr`, `poll_linux.cr`, `poll_bsd.cr`) is
  currently exercised only by specs: Go's `Terminal` creates a poll reader
  (`newPollReader`) for its input loop, while Crystal's `Terminal` uses
  `CancelReader` and its own stream loop. If it is wired in, its raw
  `select`/`epoll_wait` `poll` must move to a `Thread` or to Crystal's event
  loop first — a blocking syscall inside a fiber stalls the scheduler. Reads
  already avoid that: they go through a nonblocking dup and Crystal's event
  loop, and cancel/close wake a blocked read by closing the dup.
- `src/ultraviolet/win32_api.cr` is the single `LibC` declaration block for the
  Win32 console layer; `make check-win32` cross-type-checks it for the Windows
  target because the `flag?(:win32)` files never compile on macOS.
- The Go conformance harness is tooling, not runtime code; Phase 9 decides
  whether any of it should be ported.

## Test coverage

| Area | Primary specs |
|------|---------------|
| Core types and buffers | `border_spec.cr`, `buffer_spec.cr`, `style_spec.cr`, `event_spec.cr`, `key_spec.cr` |
| Terminal screen and lifecycle | `terminal_screen_spec.cr`, `terminal_spec.cr`, `terminal_reader_spec.cr` |
| Renderer | `terminal_renderer_spec.cr`, `terminal_renderer_output_spec.cr`, `terminal_renderer_resize_spec.cr` |
| Styled strings and width | `styled_spec.cr`, `width_spec.cr`, `program_status_spec.cr` |
| I/O and platform | `poll_spec.cr`, `poll_fallback_spec.cr`, `cancelreader_spec.cr`, `tty_spec.cr`, `console_spec.cr`, `mouse_spec.cr` |
| Windows reader logic | `cancel_event_lifetime_spec.cr`, `console_wake_loop_spec.cr`, `console_wait_spec.cr` (platform-independent, drive the win32 code paths) |
| Compatibility aliases | `go_compat_aliases_spec.cr`, `go_method_aliases_spec.cr` |

## Guardrails

- Do not weaken upstream tests or fixtures to make Crystal look green.
- Preserve behaviorally important internal data structures.
- Run `make format-check`, `make lint`, and `make test` after each phase.
- Update `go_port_inventory.tsv` rows as features close.
- Keep phase scopes feature-sized; do not promote aliases or one-off fixes to
  their own phase.
