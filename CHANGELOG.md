# Changelog

All notable changes to this Crystal port are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Upstream [charmbracelet/ultraviolet](https://github.com/charmbracelet/ultraviolet)
publishes no tags, so this port numbers itself and records upstream by commit:
every entry names the vendored snapshot it was made against. Older history
lives in `git log` and in [plans/parity.md](plans/parity.md), which also
carries the per-symbol ledger under `plans/inventory/`.

## Versioning

Shards resolves a dependency by its highest release tag, so a consumer only
sees work that is tagged. While upstream has no tags of its own, this port
releases on the `1.1` line with a patch bump per release (`1.1.2`, `1.1.3`, …)
and tags each one. As soon as upstream cuts a tag at `1.2` or above, this port
adopts that version number and follows upstream's releases from then on
(`1.2.0`, `1.2.1`, …). Keep `shard.yml`'s `version:` equal to the newest tag:
a mismatch lets `shard.lock` record a version that no tag provides, which
breaks dependents on their next update.

## [1.1.3] - 2026-11-23

Patch release on the self-numbered line. Delta since `1.1.2`.

Vendored upstream: `8ecbcf0`.

### Fixed

- `Terminal#start` renders the still-0x0 buffer before asking about grapheme
  width, as `TerminalScreen.Restore` does upstream. Without that render an
  inline application's first frame was missing the `\r\e[A` cursor nudge, and
  `examples/prependline` never repainted after inserting above the frame.

### Internal

- `make parity-examples`: 11 examples compared, 8 byte-identical to the vendored
  Go examples (`boxes`, `helloworld`, `image`, `mouse`, `rgbimage`, `splits`,
  `tv`, `widths`). `altscreen`, `panic` and `draw` remain, tracked
  byte-for-byte in `plans/parity.md`; `layout`, `space` and `prependline` are
  skipped with reasons.
- `make update_dependents` compares against the peeled tag commit and only warns
  about untagged *source* changes.

## [1.1.2] - 2026-11-23

Patch release on the self-numbered line. Tagging is what makes the work below
reachable through `shards`: until now the newest tag was `1.1.1`, so consumers
resolved ~50 commits behind `main`.

Vendored upstream: `8ecbcf0`.

- Re-verified gates (`format-check`, `lint`, `spec`) before tagging.
- `ansi` resolves `main` again instead of a feature branch, so a dependent's
  `ansi (*)` requirement no longer collides with this shard's git-ref
  requirement during resolution.
- `make update_dependents` refreshes sibling repos against the newest tag.

## [Unreleased]

Vendored upstream: `8ecbcf0`. Scope: work landed since that refresh closed.

### Fixed

- **Terminal size could corrupt the caller's stack.** `ioctl` was declared with
  a fixed `Void*` third argument although C declares it variadic, so on Apple
  Silicon the kernel wrote the winsize to a garbage stack address. Reading the
  size returned uninitialized bytes (`{3665, 25856}` for a 100x40 pty), and the
  stray write zeroed a `Terminal`'s tty fields, so a start/stop/start cycle
  failed with `not a terminal`. The declaration is variadic now.
- **`Terminal#display` ignored terminal state and prepends.** The method was
  defined twice; Crystal keeps the last definition, and the shorter later one
  won. It dropped alt-screen, cursor, and `@last_state` handling, so
  `prepend_string`/`prepend_lines` never reached the screen. The full definition
  is the only one again. Duplicates of `#flush`, `#buffered`,
  `TerminalReader#lookup=`, and ten `Ultraviolet.*_border` constructors went with
  it.
- **Poll readiness and cancellation were unreliable.** The select-based reader
  reported no data for any descriptor (`fd_set` was mutated through a by-value
  copy), and the epoll reader performed bare blocking reads that `cancel` could
  not interrupt. Both paths are replaced; readiness, timeout, cancellation, and
  end-of-input are covered by specs.

### Changed

- **`Terminal` input uses a poll reader**, as Go's `Terminal.start` does. The
  previous `CancelReader` path retried `EAGAIN` with `sleep 5.milliseconds`,
  which quantized input latency and woke 200 times a second while idle. Stop now
  cancels and then closes the reader, matching Go.
- **File-descriptor poll readers share one implementation.** `SelectReader`,
  `EpollReader`, and `KqueueReader` keep their names and platform selection, but
  `FdPollReader` now waits through Crystal's event loop (`IO::Buffered#peek`
  against a temporary `read_timeout`). The `select`/`epoll`/`kevent` plumbing,
  the per-reader cancel pipes, and the epoll/kqueue handles are gone. Behavior is
  unchanged: ready, timeout, canceled, and end-of-input are reported as before.
- **`poll` is fiber-safe.** It waits in the event loop instead of a raw syscall,
  so a long timeout no longer freezes the scheduler and another fiber can cancel
  a waiting poll.
- **`FallbackReader` buffers through `IO::Buffered`**, the same mixin Go's
  fallback reader gets from `bufio.Reader`, instead of a hand-rolled copy.
  `peek`, `skip`, `read_byte`, and `rewind` come from the standard library.
- **Poll reader `close` is idempotent**, following `IO::Delimited`,
  `IO::Sized`, and `IO::Stapled`, so repeated stop/teardown is safe.

### Removed

- `CancelReader` from `Terminal`'s input path. It stays available API, which is
  its position upstream, where nothing constructs one.
- `Ultraviolet::FD_SETSIZE`, unused once `select` was gone.
- The `LibC.select`, `LibC::FdSet`, `epoll_*`, and `kevent` bindings, plus the
  `EV_SET` helper. The only C binding left in the file-descriptor readers is
  `LibC.dup`, which the stdlib does not provide; `ConReader` still uses the
  Win32 console bindings in `win32_api.cr`.

### Internal

- Example output is now compared against the **vendored Go examples**:
  nine of the twelve comparable examples are byte-identical after colour
  normalisation. `Terminal` now configures its renderer like Go's
  `TerminalScreen` (inline, relative cursor), which is what made `mouse` match;
  `prependline`, `altscreen`, `panic` and `draw` differ only in cursor-nudge,
  clear-form and post-insert repaint details, tracked in `plans/parity.md`.
- `Terminal#resize` erases like Go's `TerminalScreen.Resize`, and the
  inline cursor nudge from `TerminalScreen.Flush` is implemented, which is
  what closed the gap on `mouse` and `prependline`.
- Example snapshots (`spec/testdata/examples/*.golden`) widened their idle
  window so a slow first frame cannot be captured as an empty one.
  `make parity-examples` runs both sides on identical pseudo terminals and
  diffs the first frame. Eight of twelve comparable examples are byte-identical
  after colour normalisation; the rest are tracked in `plans/parity.md`.
- The renderer never flushed its writer, so a small frame could sit in the
  `IO::FileDescriptor` buffer instead of reaching the terminal.
- `Terminal#start` now negotiates Unicode core mode (DEC 2027) as Go does,
  always reports the initial window size, and no longer pre-sizes the frame
  buffer or forces the alternate screen, matching `TerminalScreen`.
- `Terminal#insert_above` mirrors Go's `InsertAbove`, and `StyledString` now
  segments with `Ansi.each_grapheme_cluster` so Indic conjuncts are one cell
  (landed upstream on `dsisnero/ansi` main, `5d23aa9`).
- Decoder parity is now checked against the **vendored Go decoder**:
  `make decode-golden` regenerates `spec/fixtures/decode_golden.tsv` and
  `spec/decoder_golden_spec.cr` asserts this port matches it. It pinned the
  mouse families and the terminal size reports that mouse tracking depends on.
- `examples/mouse.cr` asks the terminal for its pixel size (XTWINOPS 14). Without
  that reply `mouse_pixel_to_cell` returns `(0, 0)` for every event, which is
  what made the mouse look like it was not tracking.
- `examples/` now mirrors every file under `vendor/ultraviolet/examples/`, and
  CI both type-checks and smoke-runs the examples. Nothing built or ran them
  before, so four had stopped compiling and `draw.cr` crashed on its first
  statement: `if __FILE__ == $0`, where Crystal's `$0` is the last regex match
  rather than the program name.
- Example binaries rebuild when any `src/` file changes and are left alone
  otherwise; the built artifacts are gitignored.
- Specs drive a real pseudo terminal for terminal, input, and winsize coverage;
  `spec/winsize_spec.cr` and the `pty_pair` helper in `spec/spec_helper.cr` are
  new.
- `make test-linux` runs the image's compiler, not the host's. `docs/testing.md`
  records the drift that once hid a deadlock.
- Inventory notes for the epoll/kqueue/select rows record the shared
  implementation.
