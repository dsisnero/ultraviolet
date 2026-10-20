# Vendor Update: 7cc6674 → 6b8d4ba

**Date:** 2026-10-19
**Previous vendor:** `7cc6674` (2026-07-20)
**Current vendor:** `6b8d4ba` (2026-10-08, upstream `main`)
**Crystal implementation tracks:** `7cc6674` plus the program status, styled/buffer, renderer, input-loop, and width follow-ups from `6b8d4ba`

The vendored Go snapshot has been refreshed. The program status reset/restore,
styled-string/buffer, renderer damage/resize, terminal input-loop, and width
follow-ups are complete. Only the optional conformance harness remains.

```text
67 commits
79 files changed
+4959 / -210
```

## Where we are

- `vendor/ultraviolet/` is now at `6b8d4ba`.
- The Crystal implementation and specs match the previous `7cc6674` behavior
  plus the completed program status, styled/buffer, renderer, and input-loop
  follow-ups.
- Program Status Protocol (OSC 7501) support is fully ported, including
  reset/restore behavior.
- Styled strings and buffers now include the `6b8d4ba` fixes.
- The renderer now uses the damage/resize model from `6b8d4ba`.
- The reader now copies each read before handing it to the event loop.
- Width handling now covers clusters wider than four columns.
- Next step: regenerate the parity inventories and assess the optional
  conformance harness.

## Porting checklist

### 1. Program status follow-ups

Upstream files: `event.go`, `decoder.go`, `terminal_screen.go`, `uv.go`,
`programstatus_test.go`.

- [x] Program status types and encoding (`ansi` shard)
- [x] `ProgramStatusSupportEvent` and OSC 7501 decoding
- [x] `TerminalScreen#set_program_status` / `#program_status`
- [x] `reset` deliberately leaves the program status record in place
- [x] `restore` re-emits the stored program status
- [x] Add parity coverage for the reset/restore behavior

**Completed 2026-10-19.** `restore` now re-encodes `@program_status`, and
`spec/program_status_spec.cr` covers the upstream
`TestTerminalScreenProgramStatus` behavior.

### 2. Styled strings and buffers

Upstream files: `styled.go`, `styled_test.go`, `buffer.go`, `buffer_test.go`.

Commits: `ae99b73`, `043ea8a`, `a5fed5c`, `7db69eb`, `6966a4f`, `d9e819d`,
`d38ea0f`.

- [x] Carry terminated APC/DCS/SOS/PM sequences through cell content
  (`passThrough` / `terminated`)
- [x] Fold trailing combining marks into the last written cell
- [x] Re-decode ASCII followed by a combining sequence as one grapheme cluster
- [x] Render grapheme clusters wider than 4 columns
- [x] Allow `Lines` to parse unbounded content
- [x] Preserve semicolons in hyperlink URLs (`SplitN(..., 3)`)
- [x] Flush pending trailing content in `renderLine`
- [x] Add buffer tests for the new `RenderBuffer#resize`, `growTouched`, and
  touched-line invariants

**Completed 2026-10-19.** The Crystal implementation now carries terminated
string sequences, folds combining marks, keeps pass-through content out of cell
width, preserves trailing spaces in `Line#render`, and restores the
`RenderBuffer` touched-row invariant across resizes.

### 3. Renderer damage and resize model

Upstream files: `terminal_renderer.go`,
`terminal_renderer_hardscroll.go`, `terminal_renderer_hashmap.go`, and the
large `terminal_renderer_test.go` additions.

This is the largest part of the delta. It replaces the ad-hoc touch handling
with a screen-sized damage record and fixes inline/fullscreen resize behavior,
autowrap, hardware scroll repaint, and erase-after-shrink cases.

Key commits: `7c6028e`, `2e490d9`, `13b333e`, `815bedb`, `4117f7c`, `6d7982b`,
`8786532`, `419da2b`, plus the inline-frame resize fixes (`08f27a0`, `e90e227`,
`0de425e`, `c0d8ed2`, `af6533f`, `48eaef2`, `3c072e9`, `8b38db3`, `243ea4b`,
`2c536ce`).

- [x] Port the damage/touch record used by the renderer
- [x] Port resize repaint and erase behavior
- [x] Match autowrap and cursor-row handling
- [x] Port the new renderer regression tests
- [x] Run the upstream conformance corpus where it applies

**Completed 2026-10-19.** The renderer now sizes its damage record to the
screen, latches real resizes, repaints after terminal/screen resizes, keeps
inline shrinks from erasing their own rows, handles drift-prone rows with
autowrap off, re-anchors the cursor after a corner cluster, and marks rows moved
by hardware scrolls. The resize/damage regression suite lives in
`spec/terminal_renderer_resize_spec.cr`; the Go conformance harness remains
optional tooling rather than a runtime port.

### 4. Terminal input loop

Upstream files: `terminal.go`, `terminal_input_test.go`,
`terminal_stop_test.go`.

Commits: `666ce5e`, `d4534d5`.

- [x] Keep a stable poll-reader reference for the input loop lifetime
- [x] Copy each read before sending it to the event loop
- [x] Make `Stop` idempotent and safe before `Start`
- [x] Cover stop/restart and input-copy behavior

**Completed 2026-10-19.** `Terminal#input_loop` already held a local reader
reference, so the Go nil-dereference bug has no Crystal equivalent; a comment now
records that invariant. `TerminalReader#send_bytes` reuses its read buffer and
copies each chunk before sending it, with a regression spec that sends 500 pairs
of back-to-back mode-report and Kitty replies. Stop/restart continues to use the
existing `CancelReader` + stop-channel path. `Terminal#stop` now returns quietly
when the terminal is not running, so calling it before `Start` or more than once
is safe.

### 5. Width handling

Upstream files: `width_test.go`, renderer/styled changes.

Commit: `006e29f`.

- [x] Support grapheme clusters wider than 4 columns
- [x] Add width regression specs for ZWJ sequences and wide clusters

**Completed 2026-10-19.** The `ansi` shard was refreshed to `7beb3d4`, which
brings its `WcWidth`/`GraphemeWidth` behavior in line with upstream
`ansi v0.11.9`. `spec/width_spec.cr` covers WcWidth cell layout, placeholder
columns, ZWJ/flag/skin-tone/family clusters, grapheme widths, and
`Cell.new_cell` widths. The renderer and styled-string paths no longer cap
cluster widths.

### 6. Conformance harness (optional but useful)

Upstream files: `internal/conformance/*`.

The new harness fuzzes renderer output against a terminal emulator. It is Go
tooling, not runtime code. Port it only if the equivalent Crystal renderer
tests cannot cover the same resize/render cases; otherwise use the corpus as a
reference when porting section 3.

### 7. Mouse pixel-to-cell conversion

- [x] Port `MousePixelToCell`
- [x] Add conversion specs for standard, boundary, modifier, zero-pixel, and
  out-of-window cases

**Completed 2026-10-19.** `Ultraviolet.mouse_pixel_to_cell` converts
`MouseEncoding::SGRPixel` coordinates using the terminal's reported pixel and
cell dimensions.

### 8. SizeNotifier compatibility

- [x] Expose `get_window_size` and `get_size`
- [x] Cover the cell and pixel results without requiring a real TTY

**Completed 2026-10-19.** The Go-compatible method names now delegate to the
existing `window_size` and `size` implementations.

### 9. NotifyWinch signal helper

- [x] Port `NotifyWinch` using `Signal::WINCH.trap`
- [x] Add a SIGWINCH forwarding spec

**Completed 2026-10-19.** `Ultraviolet.notify_winch(channel)` forwards SIGWINCH
to a buffered channel. Go's `NotifyWinchContext` has no direct Crystal
equivalent because Crystal has no `context.Context`; use `notify_winch` with a
stop channel.

### 10. Dependency and platform notes

- Upstream moved to `ansi v0.11.9`; the Crystal `ansi` shard is already updated
  for OSC 7501.
- Upstream moved to `terminfo v1.0.0`; compare against the current
  `dsisnero/terminfo` dependency when touching terminal capability lookup.
- Upstream now requires Go 1.26; this has no direct Crystal equivalent.

## Already-covered delta

The OSC 7501 types, encoder, decoder event, and screen accessors from
`6b8d4ba` are already implemented in Crystal. Do not re-port them; only the
reset/restore follow-ups remain.

## Verification after each chunk

```bash
make format-check
make lint
make test
```

Update this file and the **Where we are** block in `plans/parity.md` as each
chunk lands. Regenerate the inventory manifests after the API-affecting
chunks (2, 3, and 4).
