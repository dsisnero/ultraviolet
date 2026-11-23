# Ultraviolet Parity Plan

Ultraviolet is a Crystal port of the Go
[ultraviolet](https://github.com/charmbracelet/ultraviolet) terminal UI library.
The Go source is vendored at `vendor/ultraviolet/` (commit `8ecbcf0`).

## Where we are

- **Active plan:** none. [The `8ecbcf0` refresh](commit_8ecbcf0.md) is complete
  and there is no open porting feature.
- **Vendored snapshot:** `8ecbcf0` (2026-11-19, `fix: use layout's own key`),
  fully ported. Upstream publishes no tags; refreshes are commit-based.
- **Current focus:** none. The `PollReader` decision is made and implemented
  (see below), and the adversarial signoff is clean at `ab56604`; the only work
  left is the next upstream refresh.
- **Next up, in priority order:**
  1. **Check upstream.** `git ls-remote https://github.com/charmbracelet/ultraviolet refs/heads/main`
     — still `8ecbcf0` as of `ab56604` (two checks, `d9728b6` and `ab56604`).
     If it moved, run a refresh: clone, diff `<old>..<new>`, write
     `plans/commit_<new>.md`, bump `vendor/`, then port the delta in
     feature-sized phases. The recipe and phase template are in
     [commit_8ecbcf0.md](commit_8ecbcf0.md).
  2. **Optional: re-run the adversarial signoff** with
     `./scripts/verify_parity_adversarial.sh . vendor/ultraviolet` after a
     refresh. Last run at `ab56604`: manifests clean (819 APIs / 196 tests),
     432 examples, 0 pending, and upstream `go test ./...` green. It leaves the
     working tree untouched.
- **Decided: `PollReader` is wired into `Terminal`** (was item 2). Go builds a
  poll reader in `Terminal.start` (`vendor/ultraviolet/terminal.go:188`);
  Crystal's `Terminal` now does the same in `start_input` instead of wrapping
  `@in` in `CancelReader`, which woke from `EAGAIN` with `sleep 5.milliseconds`
  (input latency and idle wakeups quantized by that sleep). `stop_input`
  cancels and then closes the reader, as Go's `Stop` does. `Poll` is a
  different matter: **Go's `Terminal` never calls it**, so the input path never
  waits for readiness at all. The acceptance criterion — no raw wait reachable
  from a fiber — is met outright: the fd readers poll through the event loop
  after `b318a4f`, so `poll` is fiber-safe and another fiber can cancel it.
  `make test`, `make test-linux`, and `check-win32` are green.
- **Chunk status:** `8ecbcf0` refresh complete (phases 1–4); symbol inventory
  unchanged across the delta (819 APIs, 196 tests, no ledger row changes).
- **Last code feature commit:** `b318a4f` (`port: poll the fd readers through
  Crystal's event loop`).
- **Examples:** every file under `vendor/ultraviolet/examples/` has a
  counterpart in `examples/`. `make check-examples` runs in CI and example
  binaries declare `src/**/*.cr` as prerequisites, so they cannot rot again the
  way four of them had (they no longer compiled, and nothing noticed).
- **Gates:** `make format-check`, `make lint`, `make test` (432 examples),
  `make check-win32`, `make test-linux` (432 examples in the container) pass;
  `make inventory` (819 items) and `make parity` (819 APIs / 196 tests) pass;
  CI is green on ubuntu-latest, macos-latest, windows-latest plus the lint job.

> **Synced to:** `8ecbcf0` (vendored snapshot; Crystal behavior tracks it in
> full).

### Reset checklist

1. Read this block, then `git log --oneline -10` and `git status`.
2. Run `make lint && make test && make inventory` (add `make check-win32` for
   win32 files; `make test-linux` needs Apple `container` or docker).
3. `make inventory` / `make parity` forward to the locally installed
   `cross-language-crystal-parity` skill — they do **not** run in CI.
4. Environment quirks (exFAT AppleDouble sidecars, git exec bits) are in
   [docs/resuming.md](../docs/resuming.md#environment-notes).

### Known limitations

- `make check-win32` is a **partial** type-check: Crystal types method bodies
  lazily, so bodies reached only through `spawn` (the Windows reader loop) are
  compiled by the `windows-latest` CI job instead. Deliberate-typo probes
  confirmed the gap; see `docs/testing.md`.
- The file-descriptor readers share one implementation (`FdPollReader`) that
  polls through Crystal's event loop: readiness is `IO::Buffered#peek` against a
  temporary `read_timeout`, and cancel/close close the dup. Go drives
  `select`/`epoll`/`kevent` plus a cancel pipe per platform; Crystal's event
  loop already multiplexes descriptors, so `SelectReader`, `EpollReader`, and
  `KqueueReader` keep their names and platform selection but no fd_set,
  epoll/kqueue handle, or cancel pipe. Behavior is the same (ready, timeout,
  canceled, EOF-reports-ready) and `poll` is fiber-safe, so another fiber can
  cancel a waiting poll. `poll` and `read` share one buffer: use them from one
  fiber at a time.
- Running that wait on a `Thread` was tried and reverted. On the single-threaded
  scheduler that older supported compilers use, a channel send from another
  thread never woke the fiber parked on the channel, so the receiver deadlocked
  (reproduced on Crystal 1.20.1, and `shard.yml` still allows 1.19.1). Current
  compilers run threads under execution contexts and do wake it, but the readers
  must also work on the oldest supported one, and the event-loop design needs no
  thread at all. An `ExecutionContext::Isolated` fiber could host the raw wait
  too, but that costs a dedicated OS thread per reader and still needs a
  cross-thread channel to return the result, so it inherits the same version
  constraint for no gain.
- The only C binding left in the file-descriptor readers is `LibC.dup` (the
  stdlib has no `dup`, and a reader must not close the caller's descriptor). `poll_windows.cr`
  still waits in `WaitForMultipleObjects`, which the Windows console reader
  needs and CI covers.
- `Terminal` input goes through the poll readers, and `CancelReader` is ported
  API only — the same position it holds upstream, where nothing constructs one
  (`terminal_reader.go` mentions it in a comment). `Terminal.stop` cancels and
  then closes its reader, so a canceled reader is never reused across a
  restart.
- Mouse tracking needs a pixel-size report. `MousePixelToCell` is an exact port
  (including returning `(0, 0)` when the terminal reports no pixel size), and
  `examples/mouse.cr` now asks for the size with XTWINOPS 14
  (`\e[14t`), whose `CSI 4 ; h ; w t` reply decodes to `PixelSizeEvent`. The Go
  example sends `ansi.WindowOp(4)` instead, which terminals read as a resize
  request and do not answer; that one-number divergence is deliberate.
- `examples/` output is compared against the vendored Go examples with
  `make parity-examples` (local only: it needs Go). Frames are compared after
  rewriting every SGR colour to RGB, because Go passes palette entries through
  as indexed colours while this port resolves them, and after trimming the
  startup handshake. `make snapshot-examples` pins each example's own frame as a
  regression golden (`spec/testdata/examples/`), regenerated with
  `make snapshot-update`; `space` (wall-clock animation) and `prependline`
  (random colour) are skipped.
- **Open divergence the harness found:** Go's default width method is
  `ansi.WcWidth` (`buffer.go:617`) until the terminal confirms DEC mode 2027;
  this port defaults to uniwidth, which measures like grapheme clustering (a
  Devanagari conjunct is 1 column instead of 2). `examples/widths.cr` therefore
  reports a different model on a terminal that never answers the query. Fixing
  it means re-porting the width expectations, so it is tracked here rather than
  changed in passing.
- Colors are RGB-only. `Ultraviolet::Color` is an RGB struct, so
  `AnsiColor.basic`/`.indexed` resolve palette entries to RGB and the output
  uses `38;2`/`48;2` where Go's `ansi.BasicColor`/`ansi.IndexedColor` emit
  `3x`/`4x` or `38;5`/`48;5`. Same pixels on a default palette, different bytes
  if the user redefines it: captured frames of `examples/splits.cr` differ only
  in the color escapes.
- `FallbackReader#read` is not interruptible. Upstream behaves the same way
  (`poll_fallback.go`), and its test unblocks the reader manually, so this is a
  ported behavior rather than a gap.

## Recent work outside plan phases

These landed after the refresh closed; they are not plan phases, so they are
listed here to keep a fresh session from re-deriving them from git.

| Commit | What changed |
|--------|--------------|
| `9932661` | `SelectReader#poll` reported no data for every fd: `fd_set` wrote into a by-value `StaticArray` copy of `LibC::FdSet`. Fixed; readiness specs added. |
| `cbdfc0c` | PollReader hardening for runtime use: `FallbackReader` buffers through stdlib `IO::Buffered` instead of a hand-rolled copy, `close` is idempotent like `IO::Delimited`/`IO::Sized`, and the BSD `new_poll_reader` honors `FD_SETSIZE`. |
| `d9728b6` | `ioctl` was declared with a fixed `Void*` third argument although C declares it variadic, so on AArch64 the winsize write went to a garbage stack address and corrupted the caller's frame (it zeroed `Terminal`'s `@in_tty`/`@out_tty`). Declaration is variadic now; pty-based specs added. |
| `7d36e33` | `Terminal` input uses the poll reader like Go's `Terminal.start`, not `CancelReader`'s 5ms `EAGAIN` sleep; `stop_input` cancels then closes. `TerminalReader` treats `PollCanceledError` as a cancel. pty specs cover input delivery, restart, and stop with input in flight. |
| `79169fd` | The `poll`-on-a-`Thread` wrapper from `cbdfc0c` is gone: on the single-threaded scheduler of older supported compilers a channel send from another thread never wakes the parked fiber, so `poll` deadlocked (reproduced on Crystal 1.20.1; `shard.yml` allows 1.19.1). `poll` blocked on the calling fiber; superseded by the `FdPollReader` rewrite below. |
| `b318a4f` | The fd readers poll through Crystal's event loop (`IO::Buffered#peek` + temporary `read_timeout`) instead of Go's select/epoll/kqueue plus a cancel pipe: `FdPollReader` is the one implementation, the platform classes keep their names and selection, `poll` is fiber-safe again, and the readers keep only `LibC.dup`. |
| `8f003e6` | `Window.new_window`/`new_screen`/`#new_window`/`#new_view` never compiled: they called a `private` class method through the class. The shared builder is `protected`; `spec/window_spec.cr` covers them. Found by porting `examples/boxes.cr`. |
| `7a52d50` | Finished the example set (`advanced/boxes`, `advanced/rgbimage`, a real `advanced/splits`, plus the `mouse`/`widths` ports), fixed four examples that no longer compiled, wired example binaries to `src/**/*.cr`, gitignored the binaries, declared `stumpy_png`, and made CI type-check examples. |
| `5e790de` | Removed definitions a later one silently shadowed: `Terminal#display`/`#flush`/`#buffered`, `TerminalReader#lookup=`, ten duplicated `Ultraviolet.*_border` functions, and a repeated `@opts` declaration. The `display` duplicate had dropped prepends and terminal state. |
| `22fc910` | `Ultraviolet::ConsoleWait` classifies `WaitForMultipleObjects`; a failed wait now raises instead of looking like a quiet wake. Strengthened `check-win32`, which found three real Windows compile blockers (splat over an `Array`, mixed `Int32`/`UInt32` modes, module-level `private def`). |
| `f01d432` | Poll readers read through a nonblocking dup and cancel/close wake a blocked read by closing it — no `read_timeout` churn. |
| `6ccc7d9` | `EpollReader#read` was a bare blocking read, so cancel could never unblock it (found by CI on Linux). |
| `cb5a97e` | `Dockerfile.linux` + `make test-linux` (Apple `container` or docker) to run the Linux suite locally. |
| `fe8a9f2` | Made the library compile for the Windows target (POSIX-only `poll.cr` guard, `CancelReader#read`, `LibC::HANDLE.null`). |
| `0f50d96`, `2d67fac` | CI matrix (ubuntu/macOS/windows) + lint; exec bits, `.gitattributes` LF, ameba invocation. |

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
| **Test coverage** | 196 Go tests | 420 Crystal specs |
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
  loop, and cancel/close wake a blocked read by closing the dup. `poll` now
  reports readiness correctly too (its `fd_set` wrote into a by-value
  `StaticArray` copy and was silently dropped).
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
