# Vendor Update: 7cc6674 → 6b8d4ba

**Date:** 2026-10-19
**Previous vendor:** `7cc6674` (2026-07-20)
**Current vendor:** `6b8d4ba` (2026-10-08, upstream `main`)
**Crystal implementation still tracks:** `7cc6674`

The vendored Go snapshot has been refreshed. The Crystal port has **not** yet
been updated for this delta; the gates still pass because only the reference
source changed.

```text
67 commits
79 files changed
+4959 / -210
```

## Where we are

- `vendor/ultraviolet/` is now at `6b8d4ba`.
- The Crystal implementation and specs match the previous `7cc6674` behavior.
- Program Status Protocol (OSC 7501) support is already ported through the
  `ansi` shard, but the reset/restore behavior below still needs checking.
- Next step: work through the porting checklist in the order shown.

## Porting checklist

### 1. Program status follow-ups

Upstream files: `event.go`, `decoder.go`, `terminal_screen.go`, `uv.go`,
`programstatus_test.go`.

- [x] Program status types and encoding (`ansi` shard)
- [x] `ProgramStatusSupportEvent` and OSC 7501 decoding
- [x] `TerminalScreen#set_program_status` / `#program_status`
- [ ] `reset` must deliberately leave the program status record in place
- [ ] `restore` must re-emit the stored program status
- [ ] Add parity coverage for the reset/restore behavior

The current Crystal `restore` does not re-encode `@program_status`. Upstream
does so in `terminal_screen.go`.

### 2. Styled strings and buffers

Upstream files: `styled.go`, `styled_test.go`, `buffer.go`, `buffer_test.go`.

Commits: `ae99b73`, `043ea8a`, `a5fed5c`, `7db69eb`, `6966a4f`, `d9e819d`,
`d38ea0f`.

- [ ] Carry terminated APC/DCS/SOS/PM sequences through cell content
  (`passThrough` / `terminated`)
- [ ] Fold trailing combining marks into the last written cell
- [ ] Re-decode ASCII followed by a combining sequence as one grapheme cluster
- [ ] Render grapheme clusters wider than 4 columns
- [ ] Allow `Lines` to parse unbounded content
- [ ] Preserve semicolons in hyperlink URLs (`SplitN(..., 3)`)
- [ ] Flush pending trailing content in `renderLine`
- [ ] Add buffer tests for the new `RenderBuffer#resize`, `growTouched`, and
  touched-line invariants

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

- [ ] Port the damage/touch record used by the renderer
- [ ] Port resize repaint and erase behavior
- [ ] Match autowrap and cursor-row handling
- [ ] Port the new renderer regression tests
- [ ] Run the upstream conformance corpus where it applies

### 4. Terminal input loop

Upstream files: `terminal.go`, `terminal_input_test.go`,
`terminal_stop_test.go`.

Commits: `666ce5e`, `d4534d5`.

- [ ] Keep a stable poll-reader reference for the input loop lifetime
- [ ] Copy each read before sending it to the event loop
- [ ] Cover stop/restart and input-copy behavior

### 5. Width handling

Upstream files: `width_test.go`, renderer/styled changes.

Commit: `006e29f`.

- [ ] Support grapheme clusters wider than 4 columns
- [ ] Add width regression specs for ZWJ sequences and wide clusters

### 6. Conformance harness (optional but useful)

Upstream files: `internal/conformance/*`.

The new harness fuzzes renderer output against a terminal emulator. It is Go
tooling, not runtime code. Port it only if the equivalent Crystal renderer
tests cannot cover the same resize/render cases; otherwise use the corpus as a
reference when porting section 3.

### 7. Dependency and platform notes

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
