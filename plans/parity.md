# Ultraviolet Parity Plan

Ultraviolet is a Crystal port of the Go
[ultraviolet](https://github.com/charmbracelet/ultraviolet) terminal UI library.
The Go source is vendored at `vendor/ultraviolet/` (commit `6b8d4ba`).

## Where we are

- **Active plan:** [Vendor update `7cc6674` → `6b8d4ba`](update-vendor-6b8d4ba.md).
- **Current focus:** Phase 8, triaging the refreshed inventory. The vendor delta
  and its feature follow-ups are implemented.
- **Next up (feature-sized phases, one branch/commit each):**
  1. **Phase 8 — Inventory triage:** resolve inherited/shared-implementation
     rows, classify example/internal-tooling rows, and leave only true porting
     gaps as `missing`.
  2. **Phase 9 — Conformance harness assessment:** decide whether the Go
     conformance harness adds coverage Crystal specs cannot express.
  3. **Phase 10 — Next vendor refresh:** repeat the vendor-update workflow when
     upstream moves past `6b8d4ba`.
- **Chunk status:** phases 1–7 complete; phase 8 next; phases 9–10 deferred.
- **Last code feature commit:** `2a85b32` (`port: add Go-compatible method aliases`).
- **Gates:** `make lint` and `make test` pass (`392` examples).

> **Synced to:** `6b8d4ba` (vendored snapshot; Crystal implementation tracks
> `7cc6674` plus the completed `6b8d4ba` follow-ups).

## Feature phases

Each phase is sized for one branch or commit and is tracked in detail in
[the vendor-update plan](update-vendor-6b8d4ba.md).

| Phase | Feature-sized scope | Status | Evidence |
|-------|---------------------|--------|----------|
| 1 | Vendor snapshot + Program Status Protocol (OSC 7501) | ✅ | `b2f6a0b`, `7661bb4`, `28371aa` |
| 2 | Styled strings + buffer parity | ✅ | `bcdf389` |
| 3 | Renderer damage + resize model | ✅ | `d6dd62a` |
| 4 | Terminal I/O robustness: input copy, stop lifecycle, cancelable reads | ✅ | `2a512a2`, `94f85f4`, `b357f5d` |
| 5 | Width + Unicode layout | ✅ | `f68c0af` |
| 6 | API surface compatibility: mouse, sizes, winch, aliases | ✅ | `cc5ca2d`, `756d7a7`, `c8b0dc2`, `21e8aa8`, `08b76f2`, `8659366`, `2a85b32` |
| 7 | Parity inventory refresh | ✅ | `plans/inventory/*` refreshed from `6b8d4ba` |
| 8 | Inventory triage | **Next** | 203 audit-pending rows |
| 9 | Conformance harness assessment | Deferred | — |
| 10 | Next vendor refresh | Deferred | — |

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
| **Test coverage** | 196 Go tests | 392 Crystal specs |
| **Source API parity** | 819 Go APIs | 690 ported, 129 audit pending |
| **Test parity** | 196 Go tests | 122 ported, 74 audit pending |
| **Port inventory** | 1015 items | 812 ported, 203 audit pending |

Many audit-pending rows are shared/inherited implementations or
example/internal-tooling noise; Phase 8 resolves them.

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
- The Go conformance harness is tooling, not runtime code; Phase 8 decides
  whether any of it should be ported.

## Test coverage

| Area | Primary specs |
|------|---------------|
| Core types and buffers | `border_spec.cr`, `buffer_spec.cr`, `style_spec.cr`, `event_spec.cr`, `key_spec.cr` |
| Terminal screen and lifecycle | `terminal_screen_spec.cr`, `terminal_spec.cr`, `terminal_reader_spec.cr` |
| Renderer | `terminal_renderer_spec.cr`, `terminal_renderer_output_spec.cr`, `terminal_renderer_resize_spec.cr` |
| Styled strings and width | `styled_spec.cr`, `width_spec.cr`, `program_status_spec.cr` |
| I/O and platform | `poll_spec.cr`, `poll_fallback_spec.cr`, `cancelreader_spec.cr`, `tty_spec.cr`, `console_spec.cr`, `mouse_spec.cr` |
| Compatibility aliases | `go_compat_aliases_spec.cr`, `go_method_aliases_spec.cr` |

## Guardrails

- Do not weaken upstream tests or fixtures to make Crystal look green.
- Preserve behaviorally important internal data structures.
- Run `make format-check`, `make lint`, and `make test` after each phase.
- Update `go_port_inventory.tsv` rows as features close.
- Keep phase scopes feature-sized; do not promote aliases or one-off fixes to
  their own phase.
