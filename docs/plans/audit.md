# Port Audit

This document tracks the porting status of each Go file, struct, and method to Crystal.

## Files

## Summary

- **Go files**: 50
- **Structs**: 45 / 51 (88.2%)
- **Methods/Functions**: 337 / 470 (71.7%)

**Note**: Checkboxes indicate ported items. Missing items have corresponding bd issues created.

### border.go

#### Structs
- [x] `Side` (line 147)
- [x] `Border` (line 154)

#### Methods/Functions
- [x] `func NormalBorder` (line 5)
- [x] `func RoundedBorder` (line 19)
- [x] `func BlockBorder` (line 33)
- [x] `func OuterHalfBlockBorder` (line 47)
- [x] `func InnerHalfBlockBorder` (line 61)
- [x] `func ThickBorder` (line 76)
- [x] `func DoubleBorder` (line 90)
- [x] `func HiddenBorder` (line 107)
- [x] `func MarkdownBorder` (line 121)
- [x] `func ASCIIBorder` (line 133)
- [x] `(b Border) Style` (line 166)
- [x] `(b Border) Link` (line 179)
- [x] `(b *Border) Draw` (line 192)
- [x] `func borderCell` (line 224)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/poll.cr`
Structs/Classes:
- `SelectReader`
Methods:
- `initialize`
- `read`
- `poll`
- `cancel`
- `close`


---

### cancelreader_windows.go

#### Structs
- [x] `conInputReader` (line 17)
- [x] `cancelMixin` (line 122)

#### Methods/Functions
- [x] `func NewCancelReader` (line 28)
- [x] `(r *conInputReader) Cancel` (line 71)
- [x] `(r *conInputReader) Close` (line 78)
- [x] `(r *conInputReader) Read` (line 90)
- [x] `func prepareConsole` (line 103)
- [x] `(c *cancelMixin) setCanceled` (line 127)
- [x] `(c *cancelMixin) isCanceled` (line 134)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/cancelreader_windows.cr`
Structs/Classes:
- `ConInputReader`
- `CancelReader`
- `CancelMixin` (module)
Methods:
- `initialize`
- `cancel`
- `close`
- `read`
- `new`
- `prepare_console`

---

### cell.go

#### Structs
- [x] `Cell` (line 15)
- [x] `Link` (line 91)
- [x] `Style` (line 164)

#### Methods/Functions
- [x] `func NewCell` (line 35)
- [x] `(c *Cell) String` (line 50)
- [x] `(c *Cell) Equal` (line 55)
- [x] `(c *Cell) IsZero` (line 64)
- [x] `(c *Cell) Clone` (line 69)
- [x] `(c *Cell) Empty` (line 77)
- [x] `func NewLink` (line 83)
- [x] `(h *Link) String` (line 97)
- [x] `(h *Link) Equal` (line 102)
- [x] `(h *Link) IsZero` (line 107)
- [x] `(s *Style) Equal` (line 173)
- [x] `(s *Style) Styled` (line 182)
- [x] `(s *Style) String` (line 190)
- [x] `(s *Style) Diff` (line 252)
- [x] `func StyleDiff` (line 258)
- [x] `func colorEqual` (line 410)
- [x] `(s *Style) IsZero` (line 423)
- [x] `func ConvertStyle` (line 428)
- [x] `func ConvertLink` (line 454)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/cell.cr`
Structs/Classes:
- `Link`
- `Cell`
- `Style` (in `src/ultraviolet/style.cr`)
Methods:
- `initialize`
- `empty`
- `string`
- `start_sequence`
- `end_sequence`
- `initialize`
- `empty`
- `new_cell`
- `string`
- `zero`
- `clone`
- `empty`
- `new_link`
- `convert_style`
- `convert_link`
- `color_equal` (private, in `src/ultraviolet/style.cr`)
- `diff` (in `src/ultraviolet/style.cr`)

---

### cursor.go

#### Structs
- No structs

#### Methods/Functions
- [x] `(s CursorShape) Encode` (line 14)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/cursor.cr`
Structs/Classes:
- `Cursor`
Methods:
- `encode`
- `initialize`
- `new_cursor`

---

### decoder.go

#### Structs
- [x] `EventDecoder` (line 199)

#### Methods/Functions
- [x] `(l LegacyKeyEncoding) CtrlAt` (line 109)
- [x] `(l LegacyKeyEncoding) CtrlI` (line 120)
- [x] `(l LegacyKeyEncoding) CtrlM` (line 131)
- [ ] `(l LegacyKeyEncoding) CtrlOpenBracket` (line 142)
- [x] `(l LegacyKeyEncoding) Backspace` (line 153)
- [x] `(l LegacyKeyEncoding) Find` (line 164)
- [x] `(l LegacyKeyEncoding) Select` (line 175)
- [x] `(l LegacyKeyEncoding) FKeys` (line 187)
- [x] `(p *EventDecoder) Decode` (line 234)
- [x] `(p *EventDecoder) parseCsi` (line 301)
- [x] `(p *EventDecoder) parseSs3` (line 699)
- [x] `(p *EventDecoder) parseOsc` (line 763)
- [x] `(p *EventDecoder) parseStTerminated` (line 863)
- [x] `(p *EventDecoder) parseDcs` (line 941)
- [x] `(p *EventDecoder) parseApc` (line 1058)
- [x] `(p *EventDecoder) parseUtf8` (line 1085)
- [x] `(p *EventDecoder) parseControl` (line 1126)
- [x] `func parseXTermModifyOtherKeys` (line 1170)
- [x] `func init` (line 1320)
- [x] `func fromKittyMod` (line 1347)
- [x] `func parseKittyKeyboard` (line 1389)
- [x] `func parseKittyKeyboardExt` (line 1530)
- [x] `func parsePrimaryDevAttrs` (line 1545)
- [x] `func parseSecondaryDevAttrs` (line 1556)
- [x] `func parseTertiaryDevAttrs` (line 1567)
- [x] `func parseSGRMouseEvent` (line 1590)
- [x] `func parseX10MouseEvent` (line 1632)
- [x] `func parseMouseButton` (line 1658)
- [x] `func isWheel` (line 1704)
- [x] `func colorToHex` (line 1719)
- [x] `func getMaxMin` (line 1727)
- [x] `func round` (line 1743)
- [x] `func rgbToHSL` (line 1748)
- [x] `func isDarkColor` (line 1782)
- [x] `func parseTermcap` (line 1792)
- [x] `(p *EventDecoder) parseWin32InputKeyEvent` (line 1838)
- [x] `func ensureKeyCase` (line 2059)
- [x] `func translateControlKeyState` (line 2083)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/decoder.cr`
Structs/Classes:
- `EventDecoder`
Methods:
- `initialize`
- `handled`
- `unhandled`
- `initialize`
- `decode`

---

### doc.go

#### Structs
- No structs

#### Methods/Functions
- No methods

#### Crystal Equivalents
No Crystal file found.

---

### environ.go

#### Structs
- No structs

#### Methods/Functions
- [x] `(p Environ) Getenv` (line 14)
- [x] `(p Environ) LookupEnv` (line 23)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/environ.cr`
Structs/Classes:
- `Environ`
Methods:
- `initialize`
- `getenv`
- `lookup_env`

---

### event.go

#### Structs
- [x] `Size` (line 103)
- [x] `CursorPositionEvent` (line 309)
- [x] `FocusEvent` (line 315)
- [x] `BlurEvent` (line 319)
- [x] `DarkColorSchemeEvent` (line 324)
- [x] `LightColorSchemeEvent` (line 329)
- [x] `PasteEvent` (line 333)
- [x] `PasteStartEvent` (line 345)
- [x] `PasteEndEvent` (line 349)
- [x] `TerminalVersionEvent` (line 352)
- [x] `ModifyOtherKeysEvent` (line 369)
- [x] `KittyGraphicsEvent` (line 376)
- [x] `KeyboardEnhancementsEvent` (line 382)
- [x] `ModeReportEvent` (line 462)
- [x] `ForegroundColorEvent` (line 473)
- [x] `BackgroundColorEvent` (line 488)
- [x] `CursorColorEvent` (line 503)
- [x] `WindowOpEvent` (line 518)
- [x] `CapabilityEvent` (line 528)
- [x] `ClipboardEvent` (line 549)

#### Methods/Functions
- [x] `(e UnknownEvent) String` (line 30)
- [x] `(e UnknownCsiEvent) String` (line 38)
- [x] `(e UnknownSs3Event) String` (line 46)
- [x] `(e UnknownOscEvent) String` (line 54)
- [x] `(e UnknownDcsEvent) String` (line 62)
- [x] `(e UnknownSosEvent) String` (line 70)
- [x] `(e UnknownPmEvent) String` (line 78)
- [x] `(e UnknownApcEvent) String` (line 86)
- [x] `(e MultiEvent) String` (line 94)
- [x] `(s Size) Bounds` (line 109)
- [x] `(s WindowSizeEvent) Bounds` (line 120)
- [x] `(s PixelSizeEvent) Bounds` (line 128)
- [x] `(s CellSizeEvent) Bounds` (line 136)
- [x] `(k KeyPressEvent) MatchString` (line 148)
- [x] `(k KeyPressEvent) String` (line 154)
- [x] `(k KeyPressEvent) Keystroke` (line 172)
- [x] `(k KeyPressEvent) Key` (line 178)
- [x] `(k KeyReleaseEvent) MatchString` (line 190)
- [x] `(k KeyReleaseEvent) String` (line 196)
- [x] `(k KeyReleaseEvent) Keystroke` (line 214)
- [x] `(k KeyReleaseEvent) Key` (line 221)
- [x] `(e MouseClickEvent) String` (line 247)
- [x] `(e MouseClickEvent) Mouse` (line 254)
- [x] `(e MouseReleaseEvent) String` (line 262)
- [x] `(e MouseReleaseEvent) Mouse` (line 269)
- [x] `(e MouseWheelEvent) String` (line 277)
- [x] `(e MouseWheelEvent) Mouse` (line 284)
- [x] `(e MouseMotionEvent) String` (line 292)
- [x] `(e MouseMotionEvent) Mouse` (line 303)
- [x] `(e PasteEvent) String` (line 339)
- [x] `(e TerminalVersionEvent) String` (line 357)
- [x] `(e KeyboardEnhancementsEvent) Contains` (line 398)
- [x] `(e KeyboardEnhancementsEvent) SupportsKeyDisambiguation` (line 404)
- [x] `(e KeyboardEnhancementsEvent) SupportsKeyReleases` (line 410)
- [x] `(e KeyboardEnhancementsEvent) SupportsUniformKeyLayout` (line 416)
- [x] `(e ForegroundColorEvent) String` (line 476)
- [x] `(e ForegroundColorEvent) IsDark` (line 481)
- [x] `(e BackgroundColorEvent) String` (line 491)
- [x] `(e BackgroundColorEvent) IsDark` (line 496)
- [x] `(e CursorColorEvent) String` (line 506)
- [x] `(e CursorColorEvent) IsDark` (line 511)
- [x] `(e CapabilityEvent) String` (line 533)
- [x] `(e ClipboardEvent) String` (line 555)
- [x] `(e ClipboardEvent) Clipboard` (line 561)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/event.cr`
Structs/Classes:
- `UnknownEvent`
- `UnknownCsiEvent`
- `UnknownSs3Event`
- `UnknownOscEvent`
- `UnknownDcsEvent`
- `UnknownSosEvent`
- `UnknownPmEvent`
- `UnknownApcEvent`
- `Size`
- `WindowSizeEvent`
- `PixelSizeEvent`
- `CellSizeEvent`
- `MouseClickEvent`
- `MouseReleaseEvent`
- `MouseWheelEvent`
- `MouseMotionEvent`
- `CursorPositionEvent`
- `FocusEvent`
- `BlurEvent`
- `DarkColorSchemeEvent`
- `LightColorSchemeEvent`
- `PasteEvent`
- `PasteStartEvent`
- `PasteEndEvent`
- `TerminalVersionEvent`
- `ModifyOtherKeysEvent`
- `KittyGraphicsEvent`
- `KeyboardEnhancementsEvent`
- `ModeReportEvent`
- `ForegroundColorEvent`
- `BackgroundColorEvent`
- `CursorColorEvent`
- `WindowOpEvent`
- `CapabilityEvent`
- `ClipboardEvent`
Methods:
- `initialize`
- `string`
- `initialize`
- `string`
- `initialize`
- `string`
- `initialize`
- `string`
- `initialize`
- `string`
- `initialize`
- `string`
- `initialize`
- `string`
- `initialize`
- `string`
- `multi_event_string`
- `initialize`
- `bounds`
- `initialize`
- `bounds`
- `initialize`
- `bounds`
- `initialize`
- `bounds`
- `initialize`
- `x`
- `y`
- `button`
- `mod`
- `string`
- `initialize`
- `x`
- `y`
- `button`
- `mod`
- `string`
- `initialize`
- `x`
- `y`
- `button`
- `mod`
- `string`
- `initialize`
- `x`
- `y`
- `button`
- `mod`
- `string`
- `initialize`
- `initialize`
- `string`
- `initialize`
- `string`
- `initialize`
- `initialize`
- `initialize`
- `contains`
- `supports_key_disambiguation`
- `supports_key_releases`
- `supports_event_types`
- `supports_event_types`
- `supports_uniform_key_layout`
- `initialize`
- `initialize`
- `string`
- `dark`
- `initialize`
- `string`
- `dark`
- `initialize`
- `string`
- `dark`
- `initialize`
- `initialize`
- `string`
- `initialize`
- `string`
- `clipboard`
- `color_to_hex`
- `dark_color`
- `rgb_to_hsl`

---

### key.go

#### Structs
- [x] `Key` (line 267)

#### Methods/Functions
- [x] `(m KeyMod) Contains` (line 43)
- [x] `(k Key) MatchString` (line 315)
- [x] `func keyMatchString` (line 324)
- [x] `(k Key) String` (line 391)
- [x] `(k Key) Keystroke` (line 412)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/key.cr`
Structs/Classes:
- `Key`
Methods:
- `mod_contains`
- `initialize`
- `match_string`
- `string`
- `keystroke`
- `key`
- `key_match_string`
- `safe_char`
- `printable_char`

---

### key_table.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func buildKeysTable` (line 13)
- [x] `func buildTerminfoKeys` (line 396)
- [x] `func defaultTerminfoKeys` (line 444)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/key_table.cr`
Structs/Classes:
- `LegacyKeyEncoding`
Methods:
- `initialize`
- `ctrl_at`
- `ctrl_i`
- `ctrl_m`
- `ctrl_open_bracket`
- `backspace`
- `find`
- `select`
- `fkeys`
- `contains`
- `build_keys_table`
- `build_terminfo_keys`
- `default_terminfo_keys`

---

### layout.go

#### Structs
- No structs

#### Methods/Functions
- [x] `(p Percent) Apply` (line 16)
- [x] `func Ratio` (line 28)
- [x] `(f Fixed) Apply` (line 39)
- [x] `func SplitVertical` (line 53)
- [x] `func SplitHorizontal` (line 64)
- [x] `func CenterRect` (line 73)
- [x] `func TopLeftRect` (line 85)
- [x] `func TopCenterRect` (line 91)
- [x] `func TopRightRect` (line 99)
- [x] `func RightCenterRect` (line 105)
- [x] `func LeftCenterRect` (line 113)
- [x] `func BottomLeftRect` (line 121)
- [x] `func BottomCenterRect` (line 127)
- [x] `func BottomRightRect` (line 135)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/layout.cr`
Structs/Classes:
- `Percent`
- `Fixed`
Methods:
- `initialize`
- `apply`
- `ratio`
- `initialize`
- `apply`
- `split_vertical`
- `split_horizontal`
- `center_rect`
- `top_left_rect`
- `top_center_rect`
- `top_right_rect`
- `right_center_rect`
- `left_center_rect`
- `bottom_left_rect`
- `bottom_center_rect`
- `bottom_right_rect`

---

### logger.go

#### Structs
- No structs

#### Methods/Functions
- No methods

#### Crystal Equivalents
Crystal file: `src/ultraviolet/logger.cr`

---

### mouse.go

#### Structs
- [x] `Mouse` (line 72)

#### Methods/Functions
- [x] `(m Mouse) String` (line 79)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/mouse.cr`
Structs/Classes:
- `Mouse`
Methods:
- `string`
- `initialize`
- `string`

---

### poll.go

#### Structs
- No structs

#### Methods/Functions
- No methods

#### Crystal Equivalents
Crystal file: `src/ultraviolet/poll.cr`
Structs/Classes:
- `PollCanceledError`
- `SelectReader`
- `FallbackReader`
Methods:
- `initialize`
- `unbuffered_read`
- `unbuffered_write`
- `unbuffered_flush`
- `unbuffered_close`
- `unbuffered_rewind`
- `write`
- `flush`
- `new_poll_reader`
- `new_fallback_reader`
- `initialize`
- `read`
- `poll`
- `cancel`
- `close`
- `initialize`
- `read`
- `poll`
- `cancel`
- `close`

---

### poll_bsd.go

#### Structs
- [x] `kqueueReader` (line 54)

#### Methods/Functions
- [x] `func newPollReader` (line 19)
- [x] `(r *kqueueReader) Read` (line 66)
- [x] `(r *kqueueReader) Poll` (line 78)
- [x] `(r *kqueueReader) Cancel` (line 129)
- [x] `(r *kqueueReader) Close` (line 140)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/poll_bsd.cr`
Structs/Classes:
- `KqueueReader`
Methods:
- `initialize`
- `read`
- `poll`
- `cancel`
- `close`
- `new_poll_reader` (module method override)

---

### poll_default.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func newPollReader` (line 10)

#### Crystal Equivalents
No Crystal file found.

---

### poll_fallback.go

#### Structs
- [x] `fallbackReader` (line 21)

#### Methods/Functions
- [x] `func newFallbackReader` (line 11)
- [x] `(r *fallbackReader) Read` (line 31)
- [x] `(r *fallbackReader) Poll` (line 55)
- [x] `(r *fallbackReader) checkBuffered` (line 104)
- [x] `(r *fallbackReader) Cancel` (line 141)
- [x] `(r *fallbackReader) Close` (line 155)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/poll.cr`
Structs/Classes:
- `FallbackReader`
- `BufferedReader` (wrapper for buffered IO)
Methods:
- `new_fallback_reader`
- `initialize`
- `read`
- `poll`
- `check_buffered` (private)
- `cancel`
- `close`
- `canceled?` (private)

---

### poll_linux.go

#### Structs
- [x] `epollReader` (line 67)

#### Methods/Functions
- [x] `func newPollReader` (line 18)
- [x] `(r *epollReader) Read` (line 78)
- [x] `(r *epollReader) Poll` (line 90)
- [x] `(r *epollReader) Cancel` (line 139)
- [x] `(r *epollReader) Close` (line 150)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/poll_linux.cr`
Structs/Classes:
- `EpollReader`
Methods:
- `initialize`
- `read`
- `poll`
- `cancel`
- `close`
- `canceled?` (private)
- `new_poll_reader` (module method override)

---

### poll_select.go

#### Structs
- [x] `selectReader` (line 40)

#### Methods/Functions
- [x] `func newSelectPollReader` (line 19)
- [x] `(r *selectReader) Read` (line 50)
- [x] `(r *selectReader) Poll` (line 62)
- [x] `(r *selectReader) Cancel` (line 126)
- [x] `(r *selectReader) Close` (line 137)

#### Crystal Equivalents
No Crystal file found.

---

### poll_solaris.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func newPollReader` (line 10)

#### Crystal Equivalents
No Crystal file found.

---

### poll_windows.go

#### Structs
- [x] `conReader` (line 75)

#### Methods/Functions
- [x] `func newPollReader` (line 19)
- [x] `(r *conReader) Read` (line 86)
- [x] `(r *conReader) Poll` (line 98)
- [x] `(r *conReader) Cancel` (line 138)
- [x] `(r *conReader) Close` (line 161)
- [x] `func preparePollConsole` (line 180)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/poll_windows.cr`
Structs/Classes:
- `ConReader`
Methods:
- `initialize`
- `read`
- `poll`
- `cancel`
- `close`
- `new_poll_reader`

---

### screen/screen.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func Clear` (line 13)
- [x] `func ClearArea` (line 28)
- [x] `func Fill` (line 43)
- [x] `func FillArea` (line 58)
- [x] `func CloneArea` (line 79)
- [x] `func Clone` (line 104)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/screen.cr`
Structs/Classes:
- `Buffer`
Methods:
- `clear`
- `clear_area`
- `fill`
- `fill_area`
- `clone_area`
- `clone`

---

### styled.go

#### Structs
- [x] `StyledString` (line 17)

#### Methods/Functions
- [x] `func NewStyledString` (line 31)
- [x] `(s *StyledString) String` (line 40)
- [x] `(s *StyledString) Draw` (line 46)
- [x] `(s *StyledString) Height` (line 62)
- [x] `(s *StyledString) UnicodeWidth` (line 68)
- [x] `(s *StyledString) WcWidth` (line 75)
- [x] `(s *StyledString) widthHeight` (line 80)
- [x] `(s *StyledString) Bounds` (line 90)
- [x] `func ReadStyle` (line 199)
- [ ] `func ReadLink` (line 305)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/styled.cr`
Structs/Classes:
- `StyledString`
Methods:
- `initialize`
- `to_s`
- `draw`
- `height`
- `unicode_width`
- `wc_width`
- `bounds`
- `strip_ansi`
- `print_string`

---

### tabstop.go

#### Structs
- [x] `TabStops` (line 7)

#### Methods/Functions
- [x] `func NewTabStops` (line 15)
- [x] `func DefaultTabStops` (line 25)
- [x] `(ts *TabStops) Resize` (line 30)
- [x] `(ts *TabStops) Width` (line 48)
- [x] `(ts TabStops) IsStop` (line 53)
- [x] `(ts TabStops) Next` (line 63)
- [x] `(ts TabStops) Prev` (line 68)
- [x] `(ts TabStops) Find` (line 76)
- [x] `(ts *TabStops) Set` (line 112)
- [x] `(ts *TabStops) Reset` (line 118)
- [x] `(ts *TabStops) Clear` (line 124)
- [ ] `(ts *TabStops) mask` (line 129)
- [x] `(ts *TabStops) init` (line 134)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/tabstop.cr`
Structs/Classes:
- `TabStops`
Methods:
- `initialize`
- `default`
- `resize`
- `stop`
- `next`
- `prev`
- `find`
- `set`
- `reset`
- `clear`

---

### terminal.go

#### Structs
- [x] `Terminal` (line 49)
- [ ] `state` (line 92)

#### Methods/Functions
- [ ] `func DefaultTerminal` (line 100)
- [ ] `func NewTerminal` (line 106)
- [x] `(t *Terminal) SetLogger` (line 156)
- [ ] `(t *Terminal) ColorProfile` (line 161)
- [ ] `(t *Terminal) SetColorProfile` (line 168)
- [ ] `(t *Terminal) ColorModel` (line 173)
- [x] `(t *Terminal) SetWidthMethod` (line 181)
- [x] `(t *Terminal) WidthMethod` (line 188)
- [ ] `(t *Terminal) Convert` (line 197)
- [x] `(t *Terminal) GetSize` (line 203)
- [x] `(t *Terminal) Size` (line 219)
- [x] `(t *Terminal) Bounds` (line 231)
- [ ] `(t *Terminal) SetCell` (line 236)
- [ ] `(t *Terminal) CellAt` (line 241)
- [x] `(t *Terminal) Clear` (line 252)
- [x] `(t *Terminal) ClearArea` (line 257)
- [x] `(t *Terminal) Fill` (line 263)
- [x] `(t *Terminal) FillArea` (line 269)
- [x] `(t *Terminal) Clone` (line 276)
- [x] `(t *Terminal) CloneArea` (line 283)
- [x] `(t *Terminal) Position` (line 288)
- [x] `(t *Terminal) SetPosition` (line 295)
- [x] `(t *Terminal) MoveTo` (line 301)
- [x] `(t *Terminal) configureRenderer` (line 305)
- [x] `(t *Terminal) Erase` (line 321)
- [x] `(t *Terminal) Draw` (line 332)
- [x] `(t *Terminal) Display` (line 384)
- [x] `(t *Terminal) Flush` (line 433)
- [ ] `func prependLine` (line 440)
- [x] `(t *Terminal) Buffered` (line 450)
- [x] `(t *Terminal) Touched` (line 455)
- [ ] `(t *Terminal) EnterAltScreen` (line 463)
- [x] `(t *Terminal) ExitAltScreen` (line 475)
- [ ] `(t *Terminal) ShowCursor` (line 486)
- [ ] `(t *Terminal) HideCursor` (line 497)
- [x] `(t *Terminal) Resize` (line 504)
- [x] `(t *Terminal) Start` (line 517)
- [x] `(t *Terminal) Pause` (line 570)
- [x] `(t *Terminal) Resume` (line 586)
- [x] `(t *Terminal) Stop` (line 602)
- [x] `(t *Terminal) Teardown` (line 609)
- [x] `(t *Terminal) Wait` (line 621)
- [x] `(t *Terminal) Shutdown` (line 631)
- [x] `(t *Terminal) Events` (line 649)
- [ ] `(t *Terminal) SendEvent` (line 656)
- [ ] `(t *Terminal) PrependString` (line 677)
- [ ] `(t *Terminal) PrependLines` (line 694)
- [x] `(t *Terminal) Write` (line 709)
- [x] `(t *Terminal) WriteString` (line 722)
- [x] `(t *Terminal) stop` (line 726)
- [ ] `func setAltScreen` (line 739)
- [x] `(t *Terminal) initializeState` (line 747)
- [x] `(t *Terminal) initialize` (line 767)
- [x] `(t *Terminal) initialResizeEvent` (line 803)
- [x] `(t *Terminal) resizeLoop` (line 831)
- [ ] `(t *Terminal) inputLoop` (line 874)
- [ ] `(t *Terminal) eventLoop` (line 883)
- [x] `(t *Terminal) restoreTTY` (line 912)
- [ ] `(t *Terminal) restoreState` (line 937)
- [x] `(t *Terminal) restore` (line 971)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal.cr`
Structs/Classes:
- `TerminalState`
- `Terminal`
Methods:
- `initialize`
- `default_terminal`
- `initialize`
- `logger`
- `color_profile`
- `color_profile`
- `width_method`
- `width_method`
- `bounds`
- `width`
- `height`
- `cell_at`
- `set_cell`
- `clear`
- `clear_area`
- `fill`
- `fill_area`
- `clone`
- `clone_area`
- `position`
- `set_position`
- `move_to`
- `size_now`
- `fetch_size`
- `size`
- `resize`
- `start`
- `pause`
- `resume`
- `stop`
- `teardown`
- `wait`
- `shutdown`
- `events`
- `send_event`
- `prepend_string`
- `prepend_lines`
- `write`
- `write_string`
- `flush`
- `display`
- `erase`
- `buffered`
- `touched`
- `enter_alt_screen`
- `exit_alt_screen`
- `show_cursor`
- `hide_cursor`

---

### terminal_bsdly.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func supportsBackspace` (line 8)

#### Crystal Equivalents
No Crystal file found.

---

### terminal_bsdly_other.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func supportsBackspace` (line 6)

#### Crystal Equivalents
No Crystal file found.

---

### terminal_other.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(*Terminal) makeRaw` (line 6)
- [ ] `(*Terminal) getSize` (line 10)
- [x] `(t *Terminal) optimizeMovements` (line 14)
- [ ] `(*Terminal) enableWindowsMouse` (line 16)
- [ ] `(*Terminal) disableWindowsMouse` (line 17)

#### Crystal Equivalents
No Crystal file found.

---

### terminal_reader.go

#### Structs
- [x] `TerminalReader` (line 31)

#### Methods/Functions
- [ ] `func NewTerminalReader` (line 93)
- [x] `(d *TerminalReader) sendBytes` (line 112)
- [ ] `(d *TerminalReader) StreamEvents` (line 130)
- [x] `(d *TerminalReader) SetLogger` (line 212)
- [ ] `(d *TerminalReader) sendEvents` (line 216)
- [ ] `(d *TerminalReader) scanEvents` (line 224)
- [ ] `(d *TerminalReader) encodeGraphemeBufs` (line 347)
- [ ] `(d *TerminalReader) storeGraphemeRune` (line 390)
- [ ] `(d *TerminalReader) deserializeWin32Input` (line 411)
- [x] `(d *TerminalReader) logf` (line 451)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_reader.cr`
Structs/Classes:
- `TerminalReader`
Methods:
- `initialize`
- `logger`
- `stream_events`

---

### terminal_reader_other.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(d *TerminalReader) streamData` (line 11)

#### Crystal Equivalents
No Crystal file found.

---

### terminal_reader_windows.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(d *TerminalReader) streamData` (line 21)
- [ ] `(d *TerminalReader) serializeWin32InputRecords` (line 78)
- [ ] `func mouseEventButton` (line 206)
- [ ] `func highWord` (line 246)
- [ ] `func readNConsoleInputs` (line 250)
- [ ] `func readConsoleInput` (line 260)
- [ ] `func peekConsoleInput` (line 272)
- [ ] `func peekNConsoleInputs` (line 284)
- [x] `func keyEventString` (line 295)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_reader_windows.cr`
Structs/Classes:
- `Coord`
- `SmallRect`
- `ConsoleScreenBufferInfo`
- `KeyEventRecord`
- `MouseEventRecord`
- `WindowBufferSizeRecord`
- `MenuEventRecord`
- `FocusEventRecord`
- `InputRecord`
- `TerminalReader`

---

### terminal_renderer.go

#### Structs
- [ ] `cursor` (line 69)
- [ ] `LineData` (line 75)
- [x] `TerminalRenderer` (line 128)

#### Methods/Functions
- [x] `(v *capabilities) Set` (line 54)
- [ ] `(v *capabilities) Reset` (line 59)
- [ ] `(v capabilities) Contains` (line 64)
- [x] `(v *tFlag) Set` (line 94)
- [ ] `(v *tFlag) Reset` (line 99)
- [ ] `(v tFlag) Contains` (line 104)
- [x] `func NewTerminalRenderer` (line 161)
- [x] `(s *TerminalRenderer) SetLogger` (line 177)
- [ ] `(s *TerminalRenderer) SetColorProfile` (line 183)
- [ ] `(s *TerminalRenderer) SetScrollOptim` (line 188)
- [ ] `(s *TerminalRenderer) SetMapNewline` (line 199)
- [x] `(s *TerminalRenderer) SetBackspace` (line 208)
- [x] `(s *TerminalRenderer) SetTabStops` (line 219)
- [x] `(s *TerminalRenderer) SetFullscreen` (line 232)
- [x] `(s *TerminalRenderer) Fullscreen` (line 243)
- [ ] `(s *TerminalRenderer) SetRelativeCursor` (line 248)
- [ ] `(s *TerminalRenderer) SaveCursor` (line 260)
- [ ] `(s *TerminalRenderer) RestoreCursor` (line 268)
- [ ] `(s *TerminalRenderer) EnterAltScreen` (line 284)
- [x] `(s *TerminalRenderer) ExitAltScreen` (line 304)
- [ ] `(s *TerminalRenderer) PrependString` (line 320)
- [x] `(s *TerminalRenderer) moveCursor` (line 363)
- [x] `(s *TerminalRenderer) move` (line 382)
- [ ] `func cellEqual` (line 455)
- [ ] `(s *TerminalRenderer) putCell` (line 472)
- [ ] `(s *TerminalRenderer) wrapCursor` (line 482)
- [ ] `(s *TerminalRenderer) putAttrCell` (line 493)
- [ ] `(s *TerminalRenderer) putCellLR` (line 525)
- [ ] `(s *TerminalRenderer) updatePen` (line 539)
- [ ] `func canClearWith` (line 575)
- [ ] `(s *TerminalRenderer) emitRange` (line 595)
- [ ] `(s *TerminalRenderer) putRange` (line 677)
- [ ] `(s *TerminalRenderer) clearToEnd` (line 716)
- [ ] `(s *TerminalRenderer) clearBlank` (line 747)
- [ ] `(s *TerminalRenderer) insertCells` (line 753)
- [ ] `(s *TerminalRenderer) el0Cost` (line 777)
- [ ] `(s *TerminalRenderer) transformLine` (line 787)
- [ ] `(s *TerminalRenderer) deleteCells` (line 983)
- [ ] `(s *TerminalRenderer) clearToBottom` (line 991)
- [ ] `(s *TerminalRenderer) clearBottom` (line 1009)
- [ ] `(s *TerminalRenderer) clearScreen` (line 1058)
- [ ] `(s *TerminalRenderer) clearBelow` (line 1067)
- [ ] `(s *TerminalRenderer) clearUpdate` (line 1073)
- [x] `(s *TerminalRenderer) logf` (line 1095)
- [x] `(s *TerminalRenderer) Buffered` (line 1103)
- [x] `(s *TerminalRenderer) Flush` (line 1108)
- [x] `(s *TerminalRenderer) Touched` (line 1122)
- [x] `(s *TerminalRenderer) Redraw` (line 1136)
- [x] `(s *TerminalRenderer) Render` (line 1143)
- [x] `(s *TerminalRenderer) Erase` (line 1264)
- [x] `(s *TerminalRenderer) Resize` (line 1270)
- [x] `(s *TerminalRenderer) Position` (line 1279)
- [x] `(s *TerminalRenderer) SetPosition` (line 1288)
- [x] `(s *TerminalRenderer) WriteString` (line 1293)
- [x] `(s *TerminalRenderer) Write` (line 1298)
- [x] `(s *TerminalRenderer) MoveTo` (line 1305)
- [ ] `func notLocal` (line 1313)
- [x] `func relativeCursorMove` (line 1330)
- [x] `func moveCursor` (line 1488)
- [x] `func xtermCaps` (line 1565)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_renderer.cr`
Structs/Classes:
- `CursorState`
- `TerminalRenderer`
Methods:
- `initialize`
- `x`
- `y`
- `x`
- `y`
- `initialize`
- `logger`
- `color_profile`
- `scroll_optim`
- `map_newline`
- `backspace`
- `tab_stops`
- `fullscreen`
- `fullscreen`
- `relative_cursor`
- `save_cursor`
- `restore_cursor`
- `enter_alt_screen`
- `exit_alt_screen`
- `prepend_string`
- `move_cursor`
- `move`
- `put_cell`
- `wrap_cursor`
- `put_attr_cell`
- `put_cell_lr`
- `update_pen`
- `emit_range`
- `put_range`
- `clear_to_end`
- `clear_blank`
- `insert_cells`
- `el0_cost`
- `transform_line`
- `delete_cells`
- `clear_to_bottom`
- `clear_bottom`
- `clear_screen`
- `clear_below`
- `clear_update`
- `logf`
- `buffered`
- `flush`
- `touched`
- `redraw`
- `render`
- `erase`
- `resize`
- `position`
- `set_position`
- `write_string`
- `write`
- `move_to`

---

### terminal_renderer_hardscroll.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(s *TerminalRenderer) scrollOptimize` (line 11)
- [ ] `(s *TerminalRenderer) scrolln` (line 71)
- [ ] `(s *TerminalRenderer) scrollBuffer` (line 120)
- [ ] `(s *TerminalRenderer) touchLine` (line 152)
- [ ] `(s *TerminalRenderer) scrollUp` (line 169)
- [ ] `(s *TerminalRenderer) scrollDown` (line 198)
- [ ] `(s *TerminalRenderer) scrollIdl` (line 227)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_renderer_hardscroll.cr`
Structs/Classes:
- `TerminalRenderer`

---

### terminal_renderer_hashmap.go

#### Structs
- [ ] `hashmap` (line 17)

#### Methods/Functions
- [ ] `func hash` (line 6)
- [ ] `(s *TerminalRenderer) updateHashmap` (line 27)
- [ ] `(s *TerminalRenderer) scrollOldhash` (line 129)
- [ ] `(s *TerminalRenderer) growHunks` (line 152)
- [ ] `(s *TerminalRenderer) costEffective` (line 235)
- [ ] `(s *TerminalRenderer) updateCost` (line 278)
- [ ] `(s *TerminalRenderer) updateCostBlank` (line 288)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_renderer_hashmap.cr`
Structs/Classes:
- `HashMapEntry`
- `TerminalRenderer`
Methods:
- `initialize`

---

### terminal_tabdly.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func supportsHardTabs` (line 8)

#### Crystal Equivalents
No Crystal file found.

---

### terminal_tabdly_other.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func supportsHardTabs` (line 6)

#### Crystal Equivalents
No Crystal file found.

---

### terminal_unix.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(t *Terminal) makeRaw` (line 10)
- [ ] `(t *Terminal) getSize` (line 35)
- [ ] `(t *Terminal) optimizeMovements` (line 50)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_unix.cr`
Structs/Classes:
- `Terminal`
Methods:
- `supports_hard_tabs`
- `supports_backspace`

---

### terminal_windows.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(t *Terminal) makeRaw` (line 13)
- [ ] `(t *Terminal) getSize` (line 55)
- [ ] `(t *Terminal) optimizeMovements` (line 62)
- [ ] `func supportsBackspace` (line 67)
- [x] `func supportsHardTabs` (line 71)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_windows.cr`
Structs/Classes:
- `Coord`
- `SmallRect`
- `ConsoleScreenBufferInfo`
- `Terminal`
Methods:
- `supports_hard_tabs`
- `supports_backspace`

---

### tty.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `func OpenTTY` (line 11)
- [x] `func Suspend` (line 16)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/tty.cr`
Methods:
- `open_tty`
- `suspend`
- `open_tty`
- `suspend`

---

### tty_other.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `func openTTY` (line 8)
- [ ] `func suspend` (line 12)

#### Crystal Equivalents
No Crystal file found.

---

### tty_unix.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `func openTTY` (line 12)
- [ ] `func suspend` (line 20)

#### Crystal Equivalents
No Crystal file found.

---

### tty_windows.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `func openTTY` (line 8)
- [ ] `func suspend` (line 23)

#### Crystal Equivalents
No Crystal file found.

---

### utils.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func abs` (line 3)
- [x] `func clamp` (line 10)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/utils.cr`
Methods:
- `abs`
- `clamp`

---

### uv.go

#### Structs
- [ ] `Cursor` (line 51)
- [ ] `ProgressBar` (line 105)

#### Methods/Functions
- [x] `(f DrawableFunc) Draw` (line 22)
- [ ] `func NewCursor` (line 68)
- [ ] `(s ProgressBarState) String` (line 90)
- [ ] `func NewProgressBar` (line 118)

#### Crystal Equivalents
No Crystal file found.

---

### winch.go

#### Structs
- [x] `SizeNotifier` (line 12)

#### Methods/Functions
- [ ] `func NewSizeNotifier` (line 23)
- [x] `(n *SizeNotifier) Start` (line 37)
- [x] `(n *SizeNotifier) Stop` (line 42)
- [ ] `(n *SizeNotifier) GetWindowSize` (line 47)
- [ ] `(n *SizeNotifier) GetSize` (line 52)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/winch.cr`
Structs/Classes:
- `Coord`
- `SmallRect`
- `ConsoleScreenBufferInfo`
- `SizeNotifier`
Methods:
- `initialize`
- `start`
- `stop`
- `window_size`

---

### winch_other.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(n *SizeNotifier) start` (line 6)
- [ ] `(n *SizeNotifier) stop` (line 10)
- [ ] `(n *SizeNotifier) getWindowSize` (line 14)

#### Crystal Equivalents
No Crystal file found.

---

### winch_unix.go

#### Structs
- No structs

#### Methods/Functions
- [ ] `(n *SizeNotifier) start` (line 14)
- [ ] `(n *SizeNotifier) stop` (line 25)
- [ ] `(n *SizeNotifier) getWindowSize` (line 32)

#### Crystal Equivalents
No Crystal file found.

---

### window.go

#### Structs
- [x] `Window` (line 10)

#### Methods/Functions
- [ ] `(w *Window) HasParent` (line 25)
- [x] `(w *Window) Parent` (line 31)
- [ ] `(w *Window) MoveTo` (line 36)
- [ ] `(w *Window) MoveBy` (line 45)
- [x] `(w *Window) Clone` (line 55)
- [x] `(w *Window) CloneArea` (line 63)
- [x] `(w *Window) Resize` (line 73)
- [x] `(w *Window) WidthMethod` (line 84)
- [ ] `(w *Window) Bounds` (line 89)
- [ ] `(w *Window) NewWindow` (line 97)
- [ ] `(w *Window) NewView` (line 104)
- [ ] `func NewScreen` (line 111)
- [x] `(w *Window) SetWidthMethod` (line 117)
- [ ] `func newWindow` (line 123)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/window.cr`
Structs/Classes:
- `Window`
Methods:
- `initialize`
- `has_parent`
- `move_to`
- `move_by`
- `clone`
- `clone_area`
- `resize`
- `width_method`
- `width`
- `height`
- `cell_at`
- `set_cell`
- `draw`
- `new_window`
- `new_view`
- `width_method`
- `new_screen`
- `new_screen`

---

