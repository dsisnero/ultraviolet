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

## [1.1.10] - 2026-11-25

Vendored upstream: `8ecbcf0`. Scope: one SGR reading fix.

### Fixed

- **SGR pens are read from parser parameters, like Go.** Go's `ReadStyle` takes
  `ansi.Params` (a value plus a `HasMore` flag per parameter), so
  `ansi.ReadStyleColor` can reject ambiguous colour forms and the loop then reads
  the remaining parameters as plain attributes. The port re-split the parameter
  string on `;` and `:`, which loses that structure. Sequences mixing the two
  separators produced a different pen: `38;2::10:20:30` read as faint instead of
  black, `1;31:4` dropped its underline, and `38;5::196` kept a blink.
  `read_style(params : Ansi::Params, pen)` is now a direct port; the string
  overload tokenises through the parser and delegates.
  `spec/read_style_parity_spec.cr` pins Go's pen for each form.

## [1.1.9] - 2026-11-24

Vendored upstream: `8ecbcf0`. Scope: work landed since `1.1.8`.

### Changed

- **One grapheme splitter in both of Go's modes.** Go segments in two places with
  libraries that disagree: the decoder and key encoding use `uniseg` (no GB9c, so
  an Indic conjunct splits at the virama) while the screen and width code use
  `uax29` (GB9c, one cluster of 2 cells). `ansi` now ports that splitter and
  exposes `Ansi::Grapheme.cluster_end(bytes, offset, incb : Bool = true)`, so the
  port uses it with `incb: false` in `EventDecoder#parse_utf8` and
  `EventScanner#encode_grapheme_bufs`, and `incb: true` in
  `ScreenContext#draw_string_at`. Boundaries are unchanged; the implementation is
  Go's.
- **The decoder needs no lookahead machinery.** `cluster_end` is O(cluster), so
  the window/growth code and its two constants are gone.

### Internal

- `textseg` is removed from `src` and from `shard.yml`; it remains installed only
  because `uniwidth` requires it itself, which is why the library kept compiling
  after `ansi` dropped it.
- `ansi` `3f6576d` (vendored UAX #29 splitter with page-indexed properties,
  bounded `DecodeSequence` parameters) is the resolved shard. Non-ASCII input got
  faster with it: 7.6 KB of mixed ASCII/accented text scans in 1.1 ms (3.5-5.9 ms
  when this work started, 12.7 s before the input-path fixes), plain 4.4 KB in
  0.27 ms, a 54 KB paste in 3.3 ms, 4.5 KB of win32 records in 0.019 ms.
- `scripts/check_inline_fixture.sh` swaps the sibling's `lib/ansi` for this
  checkout's along with `src`; the fixture splices `src` into another checkout,
  so an `ansi` older than the pin made it fail for a reason unrelated to the
  frame it checks.
- Verified against a Go oracle rebuilt after the migration: 21 event cases, 13
  win32 deserialize cases and 13 paste cases are byte-identical, including
  Prepend runs, controls between letters, and Indic conjuncts.

## [1.1.8] - 2026-11-24

Vendored upstream: `8ecbcf0`. Scope: work landed since `1.1.7`.

This release is about the input path: two silent data bugs and two complexity
bugs, all found by diffing behaviour and timings against Go oracles built from
the vendored tree.

### Changed

- **UTF-8 input decoding mirrors Go and is linear.** `EventDecoder#parse_utf8`
  validates only the rune at the cursor and segments only the first grapheme
  cluster, using a bounded lookahead instead of copying and segmenting the whole
  remaining buffer per character. 7.6 KB of mixed ASCII/accented text now
  decodes in 2.3 ms instead of 4.8 s.
- **A valid rune in front of an invalid byte decodes as itself.** The old
  whole-buffer decode meant any invalid byte made every following call emit
  `UnknownEvent` until it was consumed; `"é" + 0xff + "b"` produced three
  `UnknownEvent`s and now produces `é`, `UnknownEvent`, `b`, as Go does.
- **Win32 input records are classified by the shared ANSI parser.** A record
  with fewer than six parameters (`\e[0;0;97;1_`, `\e[0_`) is consumed as a
  serialized key record, as Go reads it, instead of being forwarded verbatim.
- **Key-up graphemes encode as Go's do.** Every kitty release sequence leads
  with the buffer's first rune (Go's `graphemeBuf[kd][0]`), codepoints are joined
  by byte offset, and an all-NUL grapheme still emits a sequence.

### Fixed

- **Bracketed paste keeps every byte.** `decode_paste_bytes` no longer uses
  `String.new(bytes, invalid: :skip)`, which on Crystal 1.22.3 drops one valid
  byte per kilobyte (an 8 KB paste arrived 8 bytes short); it walks the buffer a
  rune at a time and drops what Go drops, including a *valid* U+FFFD. NUL is
  kept.
- **Paste no longer costs O(n²).** The paste buffer is a growable byte array
  instead of a `Bytes` rebuilt per character: a 54 KB paste went from ~520 ms to
  ~6 ms.

### Internal

- Input decoding is linear end-to-end only with `dsisnero/ansi` `5b0abcb`
  (`first_grapheme_cluster` segments a lookahead window rather than the whole
  string), which `shard.lock` now resolves; 7.6 KB scans in 5.5 ms instead of
  12.7 s.
- Six new decoder/oracle specs in `spec/terminal_reader_spec.cr` and
  `spec/go_compatibility_spec.cr` pin the win32, paste and UTF-8 behaviour
  against oracles built from `vendor/ultraviolet`.
- Recorded a Crystal 1.22.3 stdlib defect for the issue tracker: `String.encode`
  treats iconv's `E2BIG` as invalid input, so `invalid: :skip` shortens input
  longer than 1 KB.

## [1.1.7] - 2026-11-24

Vendored upstream: `8ecbcf0`. Scope: work landed since `1.1.6`.

### Changed

- **Style colours keep their kind**, as Go's `color.Color` values do. `Color` is
  now a basic entry (`ansi.BasicColor`), a 256-colour index
  (`ansi.IndexedColor`) or RGB (`ansi.RGBColor`), so `AnsiColor.basic(1)` emits
  `31` rather than `38;2;128;0;0` and `AnsiColor.indexed(240)` emits `38;5;240`.
  `Color.basic(i)`, `Color.indexed(i)` and `to_rgb` are the new constructors and
  accessor; `Color.new(r, g, b)` still builds a truecolor value.
- Equality follows Go's `colorEqual`: colours compare by resolved channels, not
  by kind, so `indexed(1) == basic(1)` while `basic(1) != Color.new(205, 0, 0)`
  — the palette is `ansiHex` from `charmbracelet/x/ansi` (via the `ansi` shard),
  which resolves basic red to `#800000`, not xterm's `#cd0000`. Code that read
  `.r/.g/.b` still compiles and now sees the ANSI palette's values.
- `ColorProfileUtil.convert` mirrors `colorprofile.Convert`: basic passes
  through every profile, an index survives every profile but ANSI, and RGB
  becomes the closest entry the profile can show (`ansi.Convert256`/`Convert16`
  from the `ansi` shard). So `#cd0000` is `38;5;160` under ANSI256 and `91` under
  ANSI, exactly as Go writes it.

### Internal

- `scripts/parity_examples.cr` no longer rewrites SGR colours to RGB before
  comparing: `make parity-examples` is a raw byte diff (11 compared, 0 differing).
- `spec/testdata/examples/{image,mouse,splits}.golden` were regenerated: those
  examples now emit the palette escapes Go does.
- `spec/style_spec.cr` pins the kind encoding, the palette channels, cross-kind
  equality and the per-profile conversion table, all read off the vendored Go.

## [1.1.6] - 2026-11-24

Patch release on the self-numbered line. Delta since `1.1.5`.

Vendored upstream: `8ecbcf0`.

### Changed

- **`Terminal` is a facade over a `TerminalScreen`**, the last structural
  difference from upstream. The screen owns every piece of screen state
  (alternate screen, mouse mode and encoding, bracketed paste, keyboard
  enhancements, cursor, colors, progress bar, program status, window title,
  synchronized updates, tab stops), so `stop` undoes what the application
  enabled without `Terminal` tracking a second copy. `Terminal#screen` exposes
  it; the drawing and mode helpers on `Terminal` delegate. The
  `TerminalState`/`@last_state` delta machinery is gone, along with the
  duplicate buffer, renderer, and output queue.
- `start` is Go's `Terminal.Start` tail (`screen.restore` → grapheme-width
  request → `screen.flush`), and `stop` is Go's `Terminal.Stop`
  (`screen.reset` → `screen.flush` → console restore). An application that never
  entered the alternate screen no longer sees an alt-screen sequence at start.

### Fixed

- `examples/mouse` and `examples/boxes` set their mouse mode and encoding through
  the screen and no longer reset them by hand: `stop` does it, as upstream does.
- `TerminalScreen#exit_alt_screen` writes the reset sequence on every call (Go
  does; the port used to skip it when not in alt mode), `#reset` emits the
  keyboard-enhancement pop where Go emits it, `#restore` re-emits the mouse
  encoding, `#set_mouse_encoding` queues its sequence, and `#set_width_method`
  propagates to the renderer.
- `flush` wraps queued output in hide/show cursor when synchronized updates are
  off and the cursor is visible, as Go's `TerminalScreen.Flush` does.
- Examples whose startup handshake the new model exposed: `boxes` and `splits`
  now enter the alternate screen before `start`, and `widths`/`altscreen` render
  once before the event loop on the still-0x0 screen, matching their Go
  counterparts. `spec/testdata/examples/*.golden` were regenerated: the startup
  bytes now match Go's.

## [1.1.5] - 2026-11-24

Patch release on the self-numbered line. Delta since `1.1.4`.

Vendored upstream: `8ecbcf0`.

### Fixed

- **Every comparable example now matches Go byte for byte** (11 of 11; `mouse`
  and `panic` were the holdouts).
  - `Terminal` and `TerminalScreen` carry Go's two-buffer output model: the
    renderer writes into a queue that `render` drains (`NewTerminalRenderer(s.buf,
    …)` upstream), while screen-level writes go straight into that queue. A
    cursor write made while flushing a frame therefore waits for the next frame,
    so an inline app's `\r\e[A` nudge lands after the writes it queues before
    its first display, not before them. Alt-screen switches are queued like Go's
    rather than written through the renderer.
  - `Terminal#stop` mirrors `Terminal.Stop` → `TerminalScreen.Reset`: it undoes
    the state it queued, leaves the application's frame on screen, and no longer
    resets tab stops or clears below the frame. `Terminal#stop` also no longer
    emits the bottom-row cursor move, which Go computes and then drops.
- The `panic` example's capture is deterministic: `make parity-examples` gives
  it a window longer than its one second tick and cuts the panic report and
  backtrace, which only one language can produce.

### Internal

- The renderer is built over the screen's own buffer (`NewTerminalRenderer(s.buf,
  …)`), so the deferral above is structural rather than a pass-through
  workaround: the renderer writes into the queue, `render` drains it, and
  screen-level writes go straight in. `TerminalRenderer#take_buffered` is gone.
- `make parity-examples` runs both languages on identical pseudo terminals and
  now reports **11 compared, 0 differing**; all twelve example goldens
  (`spec/testdata/examples/*.golden`) were regenerated for the deferred nudge,
  and `panic`'s golden covers its whole countdown.
- `scripts/support/pty_capture.cr` gives `panic` an idle window longer than its
  one second tick (`IDLE_OVERRIDES`) and cuts the panic report and backtrace
  (`CUT`); both example harnesses go through `capture_example`.


## [1.1.4] - 2026-11-23

Patch release on the self-numbered line. Delta since `1.1.3`.

Vendored upstream: `8ecbcf0`.

### Fixed

- Inline (`relative_cursor`) downward cursor moves now always use newlines, as
  Go does, instead of a `CSI n B` sequence once the renderer had "scrolled" to
  a row before. Only a newline scrolls the screen to make room for the next
  row, so the old remembered-height shortcut could paint past the bottom of an
  inline frame. The `scrollHeight` machinery upstream deleted in 2026-05 is
  gone from the port with it.
- `Cell#wide_placeholder?` (Go's `isWidePlaceholder`) replaces `Cell#zero?` in
  `put_attr_cell`, `put_cell_lr`, `put_range` and `transform_line`. A wide
  cell's continuation column is marked by zero width alone, so a styled
  zero-width cell is still a placeholder and must never be written on its own.
- The overwrite movement optimization no longer pads a move with spaces for
  cells it did not read, matching Go.

### Internal

- `make inline-golden` regenerates `spec/fixtures/inline_moves_golden.tsv` from
  the **vendored Go renderer** (`scripts/inline_oracle/`), and
  `spec/terminal_renderer_inline_spec.cr` asserts this port matches it for
  inline and fullscreen movement, including the pending-wrap ("phantom") frame
  boundary.
- `bubbletea.cr`'s `spec/parity/v2_control_sequences_spec.cr` was re-derived
  from Go. Its old expectation encoded ultraviolet `524a660` behaviour that
  upstream removed; see the note in that spec for the recipe.

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

## Earlier notes (accumulated before `1.1.5`)

Work that landed while `1.1.2`–`1.1.4` were being numbered, kept for the record.
Where these notes report example parity, the number has moved on: `1.1.5`
compares all eleven comparable examples byte for byte.

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
