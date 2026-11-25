# Ultraviolet Parity Plan

Ultraviolet is a Crystal port of the Go
[ultraviolet](https://github.com/charmbracelet/ultraviolet) terminal UI library.
The Go source is vendored at `vendor/ultraviolet/` (commit `8ecbcf0`).

## Where we are

- **Active plan:** none open. Features closed in this stretch: the decoder golden
  now covers keys and protocol families and six decode divergences are fixed
  (below), input decoding is Go-faithful and linear, bracketed paste is amortised and no longer
  truncates, and the two verification TODOs in `event_scanner.cr` are settled —
  win32 input decoding goes through the shared ANSI parser and grapheme release
  encoding leads with the buffer's first rune, both matching a Go oracle;
  before that, `v1.1.6` made `Terminal` a facade over a `TerminalScreen` and
  `v1.1.7` made style colours keep their kind. **`src/` now carries no
  non-upstream TODO**; every remaining one is open upstream too.
- **Next up** (priority order), details below under *Closed* sections:
  1. **Optional:** re-run `./scripts/verify_parity_adversarial.sh .
     vendor/ultraviolet` (last run 2026-11-24, with `ansi` `4b19c7b`: 819 APIs /
     196 tests clean, plan complete, 481 specs green, upstream `go test ./...`
     green, tree untouched). Nothing is known to be missing against `8ecbcf0`.
  2. **Optional:** upstream the Crystal stdlib finding in the paste section
     below (`String.new(bytes, invalid: :skip)` loses a byte per kilobyte on
     1.22.3) to crystal-lang/crystal as an issue with the reproduction. This
     port no longer calls it, so nothing is blocked.
  3. **Watch upstream.** `git ls-remote
     https://github.com/charmbracelet/ultraviolet refs/heads/main` — still
     `8ecbcf0` as of 2026-11-24 (seventh check, after `d9728b6` and `ab56604`).
     If it moves, run a refresh: clone, diff `<old>..<new>`, write
     `plans/commit_<new>.md`, bump `vendor/`, then port in feature-sized phases
     ([recipe](commit_8ecbcf0.md)).
- **Vendored snapshot:** `8ecbcf0` (2026-11-19, `fix: use layout's own key`),
  fully ported. Upstream publishes no tags, so refreshes are commit-based;
  this port nonetheless tags its own releases, because that is the only thing
  `shards` resolves. Policy: patch bumps on the `1.1` line (`1.1.2`, `1.1.3`, …)
  until upstream cuts a tag at `1.2` or above, then follow upstream's numbers.
  See the Versioning section in `CHANGELOG.md`.
- **Release state:** `v1.1.11` tagged at `1302012` and pushed; `shard.yml` matches
  it, all five siblings moved to `1.1.11` with `make update_dependents`, and a
  fresh consumer resolves `1.1.11` (with the `ansi` commit it was tested
  against) and reports `KeyBackspace == 127`, the corrected modifier codes, and
  `string_width_wc("स्ते") == 2`. `v1.1.10` (style pens via parser params) was
  tagged at `fc2fac7` and `v1.1.9` at `0318ec6`; `v1.1.8` at `81ff5f3`,
  `v1.1.7` at `789880c`, `v1.1.6` at `f47e115`, `v1.1.5` at `7fda004`, `v1.1.4`
  at `2fab221`, and `v1.1.3` at `c36ff37`. Sibling repos refresh with `make
  update_dependents` after each tag push; it also re-resolves this manifest's own
  `dependencies:` in each dependent, because `shards update <name>` only
  refreshes the names it is given (a dependent keeping a stale `ansi` once failed
  to compile with `undefined constant Ansi::Grapheme`).
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
  Inline renderer re-aligned with `8ecbcf0` after the stale-fixture
  investigation (see current focus); no new symbols, so the ledger is unchanged.
- **Last code feature commit:** `01dd5aa` (`port: cover keys and protocol
  families in the decoder golden`); before it, `2e1c33d` decoded UTF-8 input like
  Go, `033367a` amortised the paste buffer, `beaa488` fixed win32 input decoding and key-up grapheme encoding,
  `6c39f53` kept a style colour's kind, `a075174` gave `Terminal` Go's
  `TerminalScreen` facade, `29bca5d` is the two-buffer renderer model and
  `9ebee98` the behavior change it restructures.
- **Examples:** every file under `vendor/ultraviolet/examples/` has a
  counterpart in `examples/`. `make check-examples` runs in CI and example
  binaries declare `src/**/*.cr` as prerequisites, so they cannot rot again the
  way four of them had (they no longer compiled, and nothing noticed).
- **Gates (last verified 2026-11-24, with the win32, paste and decoder fixes
  and `ansi` 4b19c7b):**
  `make format-check`, `make lint` (58 files), `make test` (481 examples),
  `make inventory` (819 items), `make parity` (819 APIs / 196 tests, backend
  `regex`), `make check-examples`, `make snapshot-examples` (12 goldens),
  `make check-inline-fixture`, `make check-win32`, `make test-linux` (481
  examples in the container), and `make parity-examples` (11 compared, 0
  differing, raw bytes) pass, as does
  `./scripts/verify_parity_adversarial.sh . vendor/ultraviolet`. `../bubbletea.cr`
  (165 examples), `../lipgloss` (208 examples) and `../bubbles` (355 examples)
  pass on the `v1.1.8` tag, and `make update_dependents` moves all five sibling
  checkouts onto it. The `panic` capture used to be timing-sensitive; the harness now gives
  it a window longer than its tick period and cuts the language-specific report,
  so it is deterministic.

> **Synced to:** `8ecbcf0` (vendored snapshot; Crystal behavior tracks it in
> full).

### Closed: decoder golden covers keys and protocol families

`spec/fixtures/decode_golden.tsv` is generated from the vendored Go decoder
(`make decode-golden`), but its corpus only described mouse tracking and size
reports, and the generator formatted every other event as `other:%T`. So the
golden could not fail for a keyboard or protocol difference. The corpus now
covers 19 → 67 inputs and the generator formats the families the port models:
keys, paste markers, focus/blur, cursor position, DA, mode reports, kitty
graphics, terminal version, modifyOtherKeys, keyboard enhancements, colour
schemes, and the `unknown*` family. Two aliasing facts are recorded in both
signatures rather than papered over: `KeyPressEvent`/`KeyReleaseEvent` and
`PrimaryDeviceAttributesEvent`/`SecondaryDeviceAttributesEvent` are one type
each in this port, so the golden does not distinguish them.

**Six real divergences fell out of it**, all fixed:

1. **`KeyBackspace` was 8, Go's is 127** (`rune(ansi.DEL)`). 8 is `ctrl+h`;
   every backspace keystroke reported the wrong code. Now `Ansi::DEL`.
2. **Modifier key codes were permuted.** `KeyLeftMeta`/`KeyLeftSuper`/`KeyLeftCtrl`
   (and the right-hand run) were declared in a different order from Go's `iota`
   sequence, so `leftmeta`, `leftsuper` and `leftctrl` had each other's values;
   a decoded `leftctrl` compared equal to Go's `leftsuper`.
3. **`KeyIsoLevel3Shift`/`KeyIsoLevel5Shift` did not exist**, although
   `plans/inventory/go_port_inventory.tsv` listed both as ported — the ledger
   only checks that the referenced file exists, not that the symbol does.
4. **Kitty keyboard events never carried text.** Go fills `Key.Text` from the
   code after parsing and *before* deciding press vs release, so even a release
   of `a` has `Text: "a"`; this port left it empty. Ported, including the
   keypad-text and shifted-case rules.
5. **`parse_kitty_options` raised `IndexError`** on any option entry without
   `=`: `key, value = pair.split('=', 2)` indexes a one-element array. Go skips
   such entries (and empty values), which is what the port does now.
6. **Kitty graphics payload kept everything after the first `;`.** Go splits the
   body and keeps `parts[1]`, dropping later fields; the port kept the rest.

A value audit backs the corpus: all **147** `Key*` constants and **20** mouse
constants now match the vendored Go exactly (they were compared by generating
both sides and diffing), and `spec/key_spec.cr` pins the values that were wrong,
so a future reordering fails a spec rather than a keystroke. `parse_kitty_keyboard`
was split into `fill_kitty_key_text`/`printable_key_text`/`keypad_text` to stay
under the complexity gate — and `Key` is a struct, so the helper returns the
filled key instead of mutating a copy.

**Verified:** `make test` 481 examples, `make format-check`, `make lint` (58
files), `make inventory` (819 items), `make parity` (819 APIs / 196 tests),
`make check-examples`, `make snapshot-examples` (12 goldens),
`make check-inline-fixture`, `make check-win32`, `make test-linux` (481) and
`make parity-examples` (11 compared, 0 differing).

### Closed: input decoding is Go-faithful and linear

Found by benchmarking the input path against Go after the paste fix: decoding
non-ASCII text was **quadratic**. `EventDecoder#parse_utf8` copied the whole
remaining buffer into a `String` and then handed it to
`TextSegment.each_grapheme`, whose constructor decodes every code point it is
given, so each character cost O(remaining). 7.6 KB of mixed ASCII/accented
text took **4.8 s** to decode; Go decodes the same buffer in well under a
millisecond.

Go does neither: it validates only the rune at the cursor
(`utf8.DecodeRune`, `decoder.go:1112`) and then takes the first cluster of the
buffer (`uniseg.FirstGraphemeCluster`, `decoder.go:1117`), both O(cluster). The
port now mirrors that:

- `utf8_rune_size` validates the first rune (truncated, overlong, surrogate and
  >U+10FFFF sequences rejected) — Go's `DecodeRune` returning `RuneError`.
- `first_grapheme_cluster` builds a whole-rune prefix of at most
  `FIRST_CLUSTER_WINDOW` (32) bytes and segments only that, growing the window
  for the rare cluster longer than it, and trusting a boundary only when
  `FIRST_CLUSTER_LOOKAHEAD` (4) bytes of the window follow it. An invalid byte
  ends the search, matching uniseg treating it as its own cluster.

**This also fixed a parity bug it did not set out to fix.** Because the old code
decoded the entire buffer, any invalid byte anywhere made every following call
emit `UnknownEvent` until it was consumed: `"é" + 0xff + "b"` produced three
`UnknownEvent`s. Go decodes the `é`, then the `0xff`, then the `b`, and so does
this port now. Sixteen event cases — accented text, combining marks, emoji, ZWJ
family, tag flags, regional indicators, Hangul jamo, Indic conjuncts, invalid
leads, truncated tails, overlongs, surrogates, max codepoint — are byte-identical
to the Go oracle, `total` included. (The oracle also showed Go splits an Indic
conjunct at the virama, which is why this fix deliberately keeps `TextSegment`
segmentation in the decoder instead of routing it through `Ansi`'s GB9c-aware
helper.)

**Measured** (release build, `temp/bench_decode_only.cr`, mixed ASCII/accented
text):

| buffer | before | after |
|---|---|---|
| 1900 B | 84.7 ms | 1.07 ms |
| 3800 B | 605 ms | 1.38 ms |
| 7600 B | 4787 ms | 2.31 ms |

`scan_events` on the same input was still quadratic while the `ansi` shard was
pinned (12.7 s → 5.0 s) because it calls `Ansi.decode_sequence` over the whole
buffer first and that shard segmented the whole remainder per cluster too. That
shard now vendors Go's own segmenter: `dsisnero/ansi` (`3f6576d`, code from
`37413c2`/`08621ee`) ports `uax29`'s splitter over a page-indexed property
table, bounds `DecodeSequence` parameters, and exposes
`Ansi::Grapheme.cluster_end(bytes, offset, incb : Bool = true)`.

**One splitter, two modes, matching Go's two libraries.** Go segments in two
places with libraries that disagree: the decoder and key encoding use `uniseg`,
which has no GB9c and *splits* an Indic conjunct at the virama ("स्ते" is two
`KeyExtended` events), while the screen and width code use `uax29`, which
*merges* it (one cluster, 2 cells). `incb: false` is uniseg's boundary and
`incb: true` (the default, unchanged) is uax29's, so the port now uses one
implementation in the right mode at each site instead of carrying `textseg`:

| site | mode | Go counterpart |
|---|---|---|
| `EventDecoder#parse_utf8` | `incb: false` | `uniseg.FirstGraphemeCluster` (decoder.go:1117) |
| `EventScanner#encode_grapheme_bufs` | `incb: false` | `uniseg.NewGraphemes` (terminal_reader.go:399) |
| `ScreenContext#draw_string_at` | `incb: true` | `graphemes.FromString` (screen/context.go:328) |

`textseg` is gone from `src/` and from `shard.yml` (it survives in `lib/` only
because `uniwidth` requires it itself). `spec/go_compatibility_spec.cr` pins the
decoder side of the split, and the width invariant holds in both modes: the
per-segment widths still sum to the 2 cells `string_width_wc("स्ते")` reports.

**Verified against a fresh Go oracle, rebuilt after the migration:** 21 event
cases (accented text, combining marks, emoji, ZWJ families, tag flags, regional
indicators, Hangul jamo, Indic conjuncts, Prepend runs, controls between
letters, invalid leads, truncated tails, overlongs, surrogates, max codepoint),
13 win32 deserialize cases and 13 bracketed-paste cases — 47 lines,
byte-identical, `total` included.

**Measured** (release build): 7.6 KB of mixed ASCII/accented text scans in
**1.1 ms** (12.7 s at the start of this work, 3.5–5.9 ms with `textseg`), plain
4.4 KB in 0.27 ms, a 54 KB paste in 3.3 ms and 4.5 KB of win32 records in
0.019 ms. `make check-inline-fixture` now swaps the sibling's `lib/ansi` for this
checkout's as well: `src` is copied into that checkout, so an `ansi` older than
the pin can lack an API `src` uses, and the fixture failed for a reason that had
nothing to do with the frame it checks.

### Closed: bracketed paste is amortised and no longer truncates

Found while benchmarking the input path after the win32 decoder fix. Output was
never affected, but a paste was both slow and lossy, and both were confirmed
against a Go oracle built from `vendor/ultraviolet` (a copy under `temp/`, so
the pinned tree stays untouched).

**Quadratic appends.** `@paste` was a `Bytes` and every decoded event rebuilt it
with `append_bytes`, copying the whole buffer per character. Go's field is a
`[]byte` grown with `append` (`terminal_reader.go:295`). `@paste` is now an
`Array(UInt8)` — Crystal's growable byte slice — so `concat`/`<<` append in
amortised time and the buffer is turned into a `Bytes` view once, at
`PasteEndEvent`. Measured on a release build, 54 KB paste:

| | before | after | Go |
|---|---|---|---|
| 54 KB paste | 504–535 ms | 5.7–6.7 ms | 3.7 ms |

Plain text (4.4 KB), escape-heavy input (10 KB) and win32 records are unchanged
(0.52 / 0.67 / 0.04 ms before and after), so the change is confined to the paste
path. `append_bytes` in `event_scanner.cr` existed only for the old buffer and
is deleted; `terminal_reader.cr` keeps its own copy, where it only ever appends
the unprocessed tail of a read.

**Silent truncation.** `decode_paste_bytes` used
`String.new(bytes, "UTF-8", invalid: :skip)`, which on **Crystal 1.22.3 drops one
valid byte per kilobyte**: `String.encode` treats iconv's `E2BIG` ("output
buffer full", raised once the 1 KB output buffer fills) as invalid input and
skips a byte. An 8 KB paste arrived 8 bytes short; an ASCII reproduction is
`String.new(("a" * 9600).to_slice, "UTF-8", invalid: :skip).bytesize # => 9591`
(1023 bytes is intact, 1024 is intact, 1025 is one short). It is documented here
rather than filed upstream — this port no longer calls it, and `src/` has no
other `invalid:` conversion.

The replacement is Go's own algorithm (`terminal_reader.go:357`): walk the buffer
a rune at a time with `Char::Reader` and keep every rune that is not
`Char::REPLACEMENT`, which is `utf8.RuneError`'s behaviour — an invalid byte is
dropped without eating its neighbours, and a *valid* U+FFFD is dropped too,
because Go cannot tell the two apart either. NUL is a valid rune and is kept.

**Verified:** 13 paste cases are byte-identical to the oracle (hex-compared):
ASCII, UTF-8, invalid bytes, a truncated sequence, a lone continuation byte, a
valid U+FFFD, NUL, win32 records and escape sequences inside the paste,
`ESC` immediately before the end marker, an empty paste, and a 9.6 KB paste.
Two specs in `spec/terminal_reader_spec.cr` pin the truncation regression (an
8.4 KB paste delivered intact) and the rune walk (invalid byte, U+FFFD, NUL).

### Closed: win32 input decoding and grapheme encoding match Go

The two `TODO: verify against Go` notes in `event_scanner.cr` were the only
open questions in `src/` that were not also open upstream, and both hid real
drift. Each was settled against a Go oracle built from `vendor/ultraviolet`
(a copy under `temp/` with a probe test, so the pinned tree stays untouched),
never against a reading of the Go source alone.

**Grapheme encoding** (`encodeGraphemeBufs`, `terminal_reader.go:390`). A
release (key-up) buffer holding several graphemes emitted a kitty sequence per
grapheme using *that* grapheme's first rune. Go uses `graphemeBuf[kd][0]` — the
buffer's first rune — for every sequence, so typing `ab` produced
`\e[97;1:3;97u\e[98;…` here and `\e[97;1:3;97u\e[97;…` in Go. Two smaller Go
details came with it: codepoints are joined by the rune's byte offset
(`for i, r := range gr`), and a grapheme whose runes are all NUL still emits a
sequence (`\e[0;1:3;u`) instead of being skipped.

**Win32 input decoding** (`deserializeWin32Input`, `terminal_reader.go:454`).
The hand-rolled `parse_win32_sequence` matched `CSI … _` shapes by hand and
required exactly six parameters, so a short record (`\e[0;0;97;1_`,
`\e[0_`, `\e[;;;;;_`) was forwarded verbatim where Go consumes it as a
serialized key record, and it missed what the shared parser classifies
(prefixes, intermediates, colon sub-parameters). It now decodes through
`Ansi.decode_sequence` with a pooled `Ansi.get_parser`, mirroring Go's
`ansi.DecodeSequence` + `GetParser`/`PutParser`; the helper that existed only
for it is deleted.

**Verified:** 17 deserialize cases and 12 encode cases are byte-identical to
the oracle (hex-compared, including malformed records, NUL runes, astral
pairs, colon sub-parameters and multi-grapheme buffers). Six specs in
`spec/terminal_reader_spec.cr` pin the oracle values: buffer-first-rune
prefixes, byte-offset joining, the NUL grapheme, short parameter lists,
defaulted params with the key-down clamp, and records the parser does not
classify as win32 input mode. `scan_events` cost was measured before and after
in a release build: unchanged or faster for escape-heavy and win32 chunks,
+0.2 ms per 4.4 KB of plain text (each ASCII byte now goes through
`decode_sequence`'s fast path instead of the hand-rolled loop). `make test`
471 examples, `make lint` 58 files, `make format-check`, `make inventory`
819 items and `make check-win32` all green.

### Closed: `Terminal` owns a `TerminalScreen`

The last structural difference from upstream is gone. Go's `Terminal` is a thin
facade over a `TerminalScreen` (`t.scr`), and this port's is now too: the screen
owns every piece of screen state (alternate screen, mouse mode and encoding,
bracketed paste, keyboard enhancements, cursor, colors, progress bar, program
status, window title, synchronized updates, reset tab stops), so `stop` undoes
what the application enabled without `Terminal` tracking a second copy. The
`TerminalState`/`@last_state` delta machinery, `@buf`, `@scr`, and `@queue` are
deleted; `Terminal` keeps a `@screen : TerminalScreen` and delegates.

**What landed:**

- `Terminal#screen` is the screen; `write`, `write_string`, `render`, `flush`,
  alt-screen switching, cursor visibility, grapheme-width negotiation, and the
  drawing helpers (`set_cell`, `clear`, `fill_area`, `bounds`, `resize`,
  `buffered`, `touched`, `clone`, …) delegate to it. Examples and dependents
  kept their surface; `lipgloss`, `bubbletea.cr`, `bubbletea-examples`, and
  `bubbles-examples` build and pass on the release they pin.
- `start` is Go's `Terminal.Start` tail: `screen.restore` → `request_grapheme_width`
  → `screen.flush`, which re-emits tab-stop reset, alt screen, cursor, mouse,
  paste, keyboard, colors, title, progress, and program status.
- `stop` is Go's `Terminal.Stop`: `screen.reset` → `screen.flush` → console
  restore. **`examples/mouse.cr` and `examples/boxes.cr` dropped their manual
  mouse resets** and now set the modes through `set_mouse_mode`/
  `set_mouse_encoding`; `Pause`/`Resume` use the same pair.
- Timeline fixes the new model exposed, all at the example layer: `boxes` and
  `splits` enter the alternate screen before `start` (as Go does), `widths` and
  `altscreen` render once before the event loop on the still-0x0 screen (as Go
  does) instead of sizing first, and `altscreen`/`panic` no longer carry the
  "this port starts in the alternate screen" workaround.
- Gaps the shared screen uncovered and fixed: `exit_alt_screen` writes the reset
  sequence unconditionally (Go does), `reset` emits the keyboard pop where Go
  emits it, `restore` re-emits the mouse encoding, `set_mouse_encoding` queues
  its sequence, `set_width_method` propagates to the renderer, and `flush` wraps
  output in hide/show cursor when synchronized updates are off.

**Verified:** `make parity-examples` reports 11 compared / 0 differing, and a
full-session byte diff (not just the first frame) against the same Go binaries is
identical for `altscreen`, `boxes`, `draw`, `helloworld`, `panic`, `rgbimage`,
`tv`, and `widths` — colours included, no masking. `spec/testdata/examples/*.golden`
were regenerated because the startup handshake now matches Go's.

### Closed: palette-preserving colours

Go's `Style.Fg/Bg/UnderlineColor` are `color.Color` (stdlib `image/color`), so the
concrete type survives into encoding: `ansi.BasicColor` is `3x`/`9x`,
`ansi.IndexedColor` is `38;5;N` and `ansi.RGBColor` is `38;2;r;g;b`
(`vendor/ultraviolet/cell.go` `String`, `ConvertStyle`, `colorEqual`). This port
resolved every colour to RGB at construction, so its escapes were always
truecolor and `make parity-examples` had to rewrite each SGR colour before it
could compare anything.

**What landed:**

- `Color` carries a kind — basic, indexed or RGB — with `Color.basic(i)`,
  `Color.indexed(i)` and `to_rgb` for consumers that need channels. Encoding is
  kind-driven, so `AnsiColor.basic(1)` is `31`, `AnsiColor.indexed(240)` is
  `38;5;240` and an RGB value stays `38;2;r;g;b`, in `Style#string`,
  `Style.diff` and the `to_*_code` helpers.
- Equality is Go's `colorEqual`: resolved channels, not the kind, so
  `indexed(1) == basic(1)` but `basic(1) != Color.new(205, 0, 0)` (the ANSI
  palette's red is `#800000`, xterm's is `#cd0000`). `Cell`/`Style` equality and
  the renderer's cell diffing follow it.
- `ColorProfileUtil.convert` mirrors `colorprofile.Convert` by delegating to the
  `ansi` shard's ports of `ansi.Convert256`/`Convert16`: basic passes through, an
  index survives every profile but ANSI, and RGB becomes the closest entry the
  profile can show (so `#cd0000` is `38;5;160` under ANSI256 and `91` under ANSI).
  The palette itself is the shard's `ansiHex`, the same table `x/ansi` uses.
- `scripts/parity_examples.cr` lost its palette→RGB rewrite: `make
  parity-examples` is a raw byte comparison — **11 compared, 0 differing** — which
  is the acceptance signal. `spec/testdata/examples/{image,mouse,splits}.golden`
  were regenerated because those examples now emit the palette escapes Go does.
- Pinned by five cases in `spec/style_spec.cr` whose expectations were read off
  the vendored Go (kind encoding, palette channels, cross-kind equality, and the
  per-profile table), plus SGR parsing in `styled.cr` staying kind-faithful
  through `AnsiColor`.

**Verified:** `make parity-examples` 0 differing with no colour normalisation;
`make snapshot-examples` (12), `make check-inline-fixture`, `make decode-golden`
(no fixture change), `make test-linux` (465 examples); `../bubbletea.cr` (160
examples) and `../lipgloss` (198 examples) pass against the changed `Color`.

### Closed: inline-renderer byte parity

Shipped as `v1.1.4`, with two follow-ups shipped as `v1.1.5` (`9ebee98`,
`29bca5d`).

**Verify (two commands):**

```bash
make check-inline-fixture   # sibling Go-fixture spec against this src/
make inline-golden          # re-derive the inline golden from vendored Go
```

`make check-inline-fixture` temporarily swaps this checkout's `src/` into the
sibling's `lib/ultraviolet`, runs `spec/parity/v2_control_sequences_spec.cr`, and
restores the sibling on exit.

**Root cause:** `bubbletea.cr`'s Go-fixture spec
(`spec/parity/v2_control_sequences_spec.cr`) expected
`<CR><LF><ESC>[A<ESC>[30C` at a frame boundary where this renderer emitted
`<CR><ESC>[30C`. The expected bytes were **stale, not this port's**: they were
captured in Feb 2026 from ultraviolet `524a660`, whose renderer tracked a
`scrollHeight` and moved to a frame's last row at the end of every inline render.
Upstream removed both in 2026-05 (`948f4557`, `6b8d4baf`, and the vendored
`8ecbcf0`). Go oracles built from the vendored `ultraviolet`, from the sibling's
pinned Go ultraviolet, and from bubbletea v2.0.7/v2.1.0 all emit
`<CR><ESC>[30C`, byte-identical to this port; only bubbletea v2.0.0/2.0.2 with uv
`524a660` produced the old sequence. The fixture had already mixed eras — its
kitty sequences were updated to the v2.0.9 goldens while the frame boundary
stayed behind. It is now re-derived from Go, with the recipe recorded in the
spec itself.

**Real port drift found in the same pass:** the renderer still carried the
pre-`948f4557` inline machinery upstream deleted — `@scroll_height` (and the
`should_scroll` branch that switched long inline downward jumps to `CSI n B`
instead of newlines; only a newline scrolls the screen), the `ovw` space padding
for nil cells in the overwrite optimization, and `Cell#zero?` where upstream
tests `isWidePlaceholder` (width only) in `put_attr_cell`, `put_cell_lr`,
`put_range` and `transform_line`. `Cell#wide_placeholder?` is the new predicate.
Pinned by `spec/terminal_renderer_inline_spec.cr` against
`spec/fixtures/inline_moves_golden.tsv`, regenerated from the vendored Go
renderer by `make inline-golden` (`scripts/inline_oracle/`).

**Follow-ups after `v1.1.4` (shipped in `v1.1.5`):**

1. `9ebee98` — every comparable example matches Go (11/11; `mouse` and `panic`
   were the holdouts). `Terminal#stop` mirrors `Terminal.Stop` →
   `TerminalScreen.Reset`, and the harness gives `panic` a capture window longer
   than its 1 Hz tick and cuts its panic report.
2. `29bca5d` — replaced that commit's byte-capture workaround with Go's actual
   two-buffer model (renderer writes into a queue, `render` drains it), so the
   cursor-write deferral is structural. Output is unchanged: same 11/11 and the
   same twelve goldens byte for byte.

**Repro recipe for the Go oracle** (used above): a program under `temp/` with
`replace github.com/charmbracelet/ultraviolet => vendor/ultraviolet` and
`replace charm.land/bubbletea/v2 => ../bubbletea.cr/vendor/bubbletea`, memory
input/output, `WithoutSignalHandler`, `WithWindowSize(70, 30)`, one second ticks,
quit at 1.2 s. Five runs were byte-identical.

### Reset checklist

1. Read this block, then `git log --oneline -10` and `git status`. If `main` is
   ahead of origin, read *Next up* item 1 first: the unpushed commits are
   releasable as they stand.
2. Run `make lint && make test && make inventory` (add `make check-win32` for
   win32 files; `make test-linux` needs Apple `container` or docker). The
   example harnesses (`parity-examples`, `snapshot-examples`,
   `check-inline-fixture`) need the example binaries: `make build-examples`
   first, or use the make targets that depend on them.
3. `make inventory` / `make parity` forward to the locally installed
   `cross-language-crystal-parity` skill — they do **not** run in CI.
4. After tagging, run `make update_dependents` and confirm the sibling locks
   moved; the release procedure is in [Releasing](../AGENTS.md#releasing).
5. Environment quirks (exFAT AppleDouble sidecars, git exec bits) are in
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
  `examples/mouse.cr` asks for one the way the Go example does: XTWINOPS 4
  (`\e[4t`, Go's `ansi.WindowOp(4)`). xterm reads that as a *resize* request and
  answers nothing, so — exactly as in Go — the conversion relies on the winsize
  ioctl's pixel fields, and reports `(0, 0)` on a terminal that does not fill
  them. An earlier revision sent XTWINOPS 14 (`\e[14t`), which does get answered,
  but it cost byte parity and was reverted in `d495ad8`.
- `Terminal` is a facade over its `TerminalScreen`: `stop` resets the screen
  state, so mouse modes, bracketed paste, keyboard enhancements, colors, title,
  and progress bar are undone the way Go's `TerminalScreen.Reset` undoes them,
  while the application's frame and the program status stay on screen. The
  renderer keeps Go's two-buffer model (`NewTerminalRenderer(s.buf, …)`): a
  cursor move made while flushing a frame waits for the next one.
- `examples/` output is compared against the vendored Go examples with
  `make parity-examples` (local only: it needs Go). Frames are compared byte for
  byte after trimming the startup handshake — colours included, now that a palette
  entry keeps its kind — and `make snapshot-examples` pins each example's own
  frame as a regression golden (`spec/testdata/examples/`), regenerated with
  `make snapshot-update`; `space` (wall-clock animation) and `prependline`
  (random colour) are skipped. Since the screen owns the state, a full-session
  diff against the same Go binaries is also identical for every compared example.
- **Closed: the width-method default matches Go.** Go's default is
  `ansi.WcWidth` (`buffer.go:617`) until the terminal confirms DEC mode 2027, and
  so is this port's: `DEFAULT_WIDTH_METHOD` is `Ansi.string_width_wc`, and both
  `ScreenBuffer` and `TerminalScreen` start there. A Devanagari conjunct measures
  2 columns (grapheme clustering would say 1), `examples/widths` prints
  `width method: wcwidth` on a terminal that never answers the query, and
  `make parity-examples` compares it to the vendored Go example with 0
  differing. Pinned by `spec/buffer_spec.cr` (the old assertion only measured
  `"a"`, which both methods agree on) and by a `spec/terminal_screen_spec.cr`
  case for a fresh screen.
- Colors keep their kind, as Go's do. `Ultraviolet::Color` is a basic, indexed or
  RGB value, so `AnsiColor.basic`/`.indexed` emit `3x`/`4x` and `38;5;N` the way
  Go's `ansi.BasicColor`/`ansi.IndexedColor` do, and `parity-examples` compares
  the escapes byte for byte. Equality is Go's `colorEqual` (resolved channels,
  not the kind), and `ColorProfileUtil.convert` mirrors `colorprofile.Convert`:
  basic passes through, an index survives every profile but ANSI, RGB becomes the
  closest entry the profile can show. The palette itself is `ansiHex` from
  `charmbracelet/x/ansi` via the `ansi` shard, which is why `basic(1)` resolves
  to `#800000` rather than xterm's brighter `#cd0000`.
- `FallbackReader#read` is not interruptible. Upstream behaves the same way
  (`poll_fallback.go`), and its test unblocks the reader manually, so this is a
  ported behavior rather than a gap.

## Example output parity

`make parity-examples` compares each vendored Go example against this port's
counterpart and diffs the first frame: byte-identical after handshake trimming,
SGR colours included. `crystal run scripts/parity_examples.cr -- <name>` checks
one example.

| Example | Status | Notes |
|---------|--------|-------|
| `altscreen` | ✅ identical | renders once before the event loop on the still-0x0 screen, as Go does |
| `boxes` | ✅ identical | enters the alternate screen before `start`, and sets its mouse mode through the screen |
| `draw` | ✅ identical | needed `enter_alt_screen` before `start`, as Go's example does |
| `helloworld` | ✅ identical | — |
| `image` | ✅ identical | needs its data file in cwd; the harness runs each side from its own directory |
| `mouse` | ✅ identical | the inline `\r\e[A` nudge is deferred to the next frame, as Go's renderer buffer does; the example sets its modes through the screen and lets `stop` reset them |
| `panic` | ✅ identical | captured with a window longer than its 1 Hz tick; the panic report and backtrace are cut, since only one language can produce them |
| `rgbimage` | ✅ identical | the 0x0 image payload case matches Go |
| `splits` | ✅ identical | enters the alternate screen before `start`, as Go does |
| `tv` | ✅ identical | — |
| `widths` | ✅ identical | renders once before the event loop on the still-0x0 screen, as Go does; reports `wcwidth` on a terminal that never answers DEC mode 2027, as Go does |
| `layout` | ⏭ skipped | Go's example is built on lipgloss, which this port does not depend on |
| `space` | ⏭ skipped | animates from the wall clock on both sides |
| `prependline` | ⏭ skipped | random colour per frame and scheduling-dependent frame count |

All eleven comparable examples are byte-identical, in the first frame and for the
whole captured session.

`mouse` used to differ in where a two-byte inline cursor nudge was written: Go
queues its mode writes first and nudges during the first display, this port
nudged inside `start`. The cause was structural: Go's `TerminalScreen` builds
its renderer on *its own* buffer (`NewTerminalRenderer(s.buf, …)`), so a cursor
move made while flushing a frame waits in the renderer buffer until the next
render drains it. `Terminal` and `TerminalScreen` now do the same — the renderer
writes into a queue, `render` drains it into the terminal's buffer (`rend.Flush`
in Go), and screen-level writes go straight into that buffer. The deferral is
therefore a property of the structure, for both the explicit cursor position and
the inline nudge.

`panic` needed a capture change rather than a code change: it ticks at 1 Hz and
the harness stopped after a 1 s idle gap, so whichever side drifted past the gap
was cut first. `PtyCapture::IDLE_OVERRIDES` gives it a 2 s window and
`PtyCapture::CUT` drops the panic report and backtrace, which are
language-specific by construction.

`Terminal#stop` mirrors Go's `Terminal.Stop` → `TerminalScreen.Reset`: it undoes
the state the screen tracked (mouse modes and encoding, bracketed paste, keyboard
enhancements, alternate screen, cursor visibility, colors, title, progress bar),
leaves the application's frame on screen, and does not reset tab stops or clear
below the frame. Go's `Reset` also parks the cursor on the bottom row, but through
the renderer buffer that `Stop` never drains, so the move is computed and dropped;
this port drops it too, to keep the same bytes on the wire.

`Terminal` now configures its renderer like Go's `TerminalScreen`
(`fullscreen = false`, `relative_cursor = true`, terminal_screen.go:64-65);
that is what made `mouse` identical and kept `splits`/`widths`/`tv` green. My
earlier note that this path painted nothing was wrong: it was measured before
the resize-erase and inline-nudge fixes and does not reproduce.

No comparable example differs. `prependline` stays skipped rather than compared:
its frame count and colours depend on scheduling and randomness, so a match is
luck rather than evidence.

Specs: the grapheme-width negotiation is now covered by faithful ports of
upstream's `grapheme_width_test.go` — `TestGraphemeWidthNegotiation` and
`TestGraphemeWidthOverride` in `spec/terminal_screen_spec.cr`, and the five-case
`TestGraphemeWidthGating` matrix plus `TestGraphemeWidthGatingPreservesOverride`
in `spec/terminal_spec.cr`. The inventory already listed those rows as ported;
they were not, and the rows are now true. Upstream has **no** tests for
`TerminalScreen.InsertAbove`, the flush cursor nudge, or the initial size
event, so the characterization specs for those live only here.

Shard patch (per the patch-shard workflow):

- `lib/ansi` gained `Ansi.each_grapheme_cluster`, so `StyledString` segments
  exactly as the width functions measure (virama-joined conjuncts are one
  cluster). Specs were written first and failed without it, and it is what made
  `widths` identical. Merged upstream on `dsisnero/ansi` main (`5d23aa9`), so
  `shard.yml` resolves the plain dependency with no branch pin.
- `ansi` should also gain a single-argument `Ansi.window_op(p)` overload: its
  `ps.empty?` branch is dead because Crystal rejects a call that only fills a
  typed splat, so `Ansi.window_op(4)` does not compile and the examples write
  `"\e[4t"` literals.

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
| **Test coverage** | 196 Go tests | 481 Crystal specs |
| **Source API parity** | 819 Go APIs | 776 ported, 43 intentional divergences |
| **Test parity** | 196 Go tests | 178 ported, 18 intentional divergences |
| **Port inventory** | 1015 items | 954 ported, 61 intentional divergences |

No `missing` rows remain. The 61 divergences are examples, Go-only conformance
tooling, or Go-specific safety/allocation guards.

\* `Terminal` is a facade over a `TerminalScreen`, as Go's is over `t.scr`, so
screen state lives in one place in both. Crystal also extracts `EventScanner`
from `TerminalReader`, matching Go's `eventScanner`.

## Remaining work (upstream-limited)

Every remaining Crystal TODO matches a Go TODO. They are open investigations in
both codebases, not porting gaps:

| Crystal Line | Go Line | Description |
|-------------|---------|-------------|
| `terminal_renderer.cr:271` | `terminal_renderer.go:355` | Use scrolling region if available |
| `terminal_renderer.cr:272` | `terminal_renderer.go:356` | Use `Screen.Write`/`io.Writer` interface |
| `terminal_renderer.cr:343` | `terminal_renderer.go:445` | Investigate erase case handling |
| `terminal_renderer.cr:907` | `terminal_renderer.go:1114` | Unnecessary cursor movements on resize |
| `terminal_renderer.cr:1314` | `terminal_renderer.go:1657` | Guard against unintentional scrolling |
| `terminal_renderer.cr:1344` | `terminal_renderer.go:1691` | Linux console terminal edge case |
| `buffer.cr:786` | `terminal_renderer.go:493` | Empty-line scroll-optimization artifacts |

Two upstream TODO comments have no Crystal counterpart, so they are tracked as
upstream-open rather than as work here:

- `terminal_renderer.go:1453` — whether tab-stop handling needs to go further;
  the note is attached to commented-out code the port never carried.
- `terminal_renderer.go:1503` — whether scrolling should also be optimized in
  inline mode; the block it annotates (`scroll_optimize` under
  `ScrollOptim && fullscreen`) is ported, so the question becomes port work if
  upstream answers it.

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
