# Changelog

All notable changes to this Crystal port are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Upstream [charmbracelet/ultraviolet](https://github.com/charmbracelet/ultraviolet)
publishes no tags, so this port tracks it by commit: every entry names the
vendored snapshot it was made against. Older history lives in `git log` and in
[plans/parity.md](plans/parity.md), which also carries the per-symbol ledger
under `plans/inventory/`.

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

- Specs drive a real pseudo terminal for terminal, input, and winsize coverage;
  `spec/winsize_spec.cr` and the `pty_pair` helper in `spec/spec_helper.cr` are
  new.
- `make test-linux` runs the image's compiler, not the host's. `docs/testing.md`
  records the drift that once hid a deadlock.
- Inventory notes for the epoll/kqueue/select rows record the shared
  implementation.
