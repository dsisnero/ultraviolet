# Port Audit

---
### buffer.go

#### Structs
- [x] `Buffer` (line ?)
- [x] `RenderBuffer` (line ?)

#### Methods/Functions
- [x] `(b *Buffer) InsertCell` (line 527)
- [x] `(b *Buffer) InsertCellArea` (line 534)
- [x] `(b *Buffer) DeleteCell` (line 562)
- [x] `(b *Buffer) DeleteCellArea` (line 569)
- [x] `func TrimSpace` (line 623)
- [x] `(b *RenderBuffer) InsertCell` (line 758)
- [x] `(b *RenderBuffer) InsertCellArea` (line 765)
- [x] `(b *RenderBuffer) DeleteCell` (line 777)
- [x] `(b *RenderBuffer) DeleteCellArea` (line 784)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/buffer.cr`
Structs/Classes:
- `Buffer`
- `RenderBuffer`
Methods:
- `insert_cell`
- `insert_cell_area`
- `delete_cell`
- `delete_cell_area`
- `trim_space`

---

### cell.go

#### Structs
- [x] `Cell` (line 15)
- [x] `Link` (line 91)
- [x] `Style` (line 164)

#### Methods/Functions
- [x] `func NewCell` (line 35)
- [x] `(c *Cell) Equal` (line 55)
- [x] `func NewLink` (line 83)
- [x] `(h *Link) Equal` (line 102)
- [x] `(s *Style) Equal` (line 173)
- [x] `(s *Style) Diff` (line 252)
- [x] `func colorEqual` (line 410)
- [x] `func ConvertLink` (line 454)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/cell.cr`, `src/ultraviolet/style.cr`
Structs/Classes:
- `Cell`
- `Link`
- `Style`
Methods:
- `new_cell`
- `==` (def_equals_and_hash)
- `new_link`
- `==` (def_equals_and_hash)
- `==` (def_equals_and_hash)
- `diff`
- `color_equal`
- `convert_link`

---

### event.go

#### Structs
- [x] `MouseClickEvent` (line ?)
- [x] `MouseReleaseEvent` (line ?)
- [x] `MouseWheelEvent` (line ?)
- [x] `MouseMotionEvent` (line ?)

#### Methods/Functions
- [x] `(e MouseClickEvent) Mouse` (line ?)
- [x] `(e MouseReleaseEvent) Mouse` (line ?)
- [x] `(e MouseWheelEvent) Mouse` (line ?)
- [x] `(e MouseMotionEvent) Mouse` (line ?)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/event.cr`
Structs/Classes:
- `MouseClickEvent`
- `MouseReleaseEvent`
- `MouseWheelEvent`
- `MouseMotionEvent`
Methods:
- `mouse` (property)

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
- [x] `(*Terminal) makeRaw` (line 6)
- [x] `(*Terminal) getSize` (line 10)
- [x] `(t *Terminal) optimizeMovements` (line 14)
- [x] `(*Terminal) enableWindowsMouse` (line 16)
- [x] `(*Terminal) disableWindowsMouse` (line 17)

#### Crystal Equivalents
No Crystal file found.

---

### terminal_reader.go

#### Structs
- [x] `TerminalReader` (line 31)

#### Methods/Functions
- [x] `func NewTerminalReader` (line 93)
- [x] `(d *TerminalReader) sendBytes` (line 112)
- [x] `(d *TerminalReader) StreamEvents` (line 130)
- [x] `(d *TerminalReader) SetLogger` (line 212)
- [x] `(d *TerminalReader) sendEvents` (line 216)
- [x] `(d *TerminalReader) scanEvents` (line 224)
- [x] `(d *TerminalReader) encodeGraphemeBufs` (line 347)
- [x] `(d *TerminalReader) storeGraphemeRune` (line 390)
- [x] `(d *TerminalReader) deserializeWin32Input` (line 411)
- [x] `(d *TerminalReader) logf` (line 451)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_reader.cr`
Structs/Classes:
- `TerminalReader`
Methods:
- `initialize` (NewTerminalReader)
- `logger`, `logger=`
- `stream_events` (StreamEvents)
- `send_bytes`
- `send_events`
- `scan_events`
- `encode_grapheme_bufs`
- `store_grapheme_rune`
- `deserialize_win32_input`
- `logf`

---

### terminal_reader_other.go

#### Structs
- No structs

#### Methods/Functions
- [x] `(d *TerminalReader) streamData` (line 11)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_reader.cr` and `src/ultraviolet/terminal_reader_windows.cr`
Methods:
- `stream_data` (calls `send_bytes`)

---

### terminal_reader_windows.go

#### Structs
- No structs

#### Methods/Functions
- [x] `(d *TerminalReader) streamData` (line 21)
- [x] `(d *TerminalReader) serializeWin32InputRecords` (line 78)
- [x] `func mouseEventButton` (line 206)
- [x] `func highWord` (line 246)
- [x] `func readNConsoleInputs` (line 250)
- [x] `func readConsoleInput` (line 260)
- [x] `func peekConsoleInput` (line 272)
- [x] `func peekNConsoleInputs` (line 284)
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
Methods:
- `serialize_win32_input_records`
- `mouse_event_button`
- `high_word`
- `read_n_console_inputs`
- `peek_n_console_inputs`
- `send_bytes_windows`

---

### terminal_renderer.go

#### Structs
- [x] `cursor` (line 69)
- [x] `LineData` (line 75)
- [x] `TerminalRenderer` (line 128)

#### Methods/Functions
- [x] `(v *capabilities) Set` (line 54)
- [x] `(v *capabilities) Reset` (line 59)
- [x] `(v capabilities) Contains` (line 64)
- [x] `(v *tFlag) Set` (line 94)
- [x] `(v *tFlag) Reset` (line 99)
- [x] `(v tFlag) Contains` (line 104)
- [x] `func NewTerminalRenderer` (line 161)
- [x] `(s *TerminalRenderer) SetLogger` (line 177)
- [x] `(s *TerminalRenderer) SetColorProfile` (line 183)
- [x] `(s *TerminalRenderer) SetScrollOptim` (line 188)
- [x] `(s *TerminalRenderer) SetMapNewline` (line 199)
- [x] `(s *TerminalRenderer) SetBackspace` (line 208)
- [x] `(s *TerminalRenderer) SetTabStops` (line 219)
- [x] `(s *TerminalRenderer) SetFullscreen` (line 232)
- [x] `(s *TerminalRenderer) Fullscreen` (line 243)
- [x] `(s *TerminalRenderer) SetRelativeCursor` (line 248)
- [x] `(s *TerminalRenderer) SaveCursor` (line 260)
- [x] `(s *TerminalRenderer) RestoreCursor` (line 268)
- [x] `(s *TerminalRenderer) EnterAltScreen` (line 284)
- [x] `(s *TerminalRenderer) ExitAltScreen` (line 304)
- [x] `(s *TerminalRenderer) PrependString` (line 320)
- [x] `(s *TerminalRenderer) moveCursor` (line 363)
- [x] `(s *TerminalRenderer) move` (line 382)
- [x] `func cellEqual` (line 455)
- [x] `(s *TerminalRenderer) putCell` (line 472)
- [x] `(s *TerminalRenderer) wrapCursor` (line 482)
- [x] `(s *TerminalRenderer) putAttrCell` (line 493)
- [x] `(s *TerminalRenderer) putCellLR` (line 525)
- [x] `(s *TerminalRenderer) updatePen` (line 539)
- [x] `func canClearWith` (line 575)
- [x] `(s *TerminalRenderer) emitRange` (line 595)
- [x] `(s *TerminalRenderer) putRange` (line 677)
- [x] `(s *TerminalRenderer) clearToEnd` (line 716)
- [x] `(s *TerminalRenderer) clearBlank` (line 747)
- [x] `(s *TerminalRenderer) insertCells` (line 753)
- [x] `(s *TerminalRenderer) el0Cost` (line 777)
- [x] `(s *TerminalRenderer) transformLine` (line 787)
- [x] `(s *TerminalRenderer) deleteCells` (line 983)
- [x] `(s *TerminalRenderer) clearToBottom` (line 991)
- [x] `(s *TerminalRenderer) clearBottom` (line 1009)
- [x] `(s *TerminalRenderer) clearScreen` (line 1058)
- [x] `(s *TerminalRenderer) clearBelow` (line 1067)
- [x] `(s *TerminalRenderer) clearUpdate` (line 1073)
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
- [x] `func notLocal` (line 1313)
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
- [x] `(s *TerminalRenderer) scrollOptimize` (line 11)
- [x] `(s *TerminalRenderer) scrolln` (line 71)
- [x] `(s *TerminalRenderer) scrollBuffer` (line 120)
- [x] `(s *TerminalRenderer) touchLine` (line 152)
- [x] `(s *TerminalRenderer) scrollUp` (line 169)
- [x] `(s *TerminalRenderer) scrollDown` (line 198)
- [x] `(s *TerminalRenderer) scrollIdl` (line 227)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_renderer_hardscroll.cr`
Structs/Classes:
- `TerminalRenderer`
Methods:
- `scroll_optimize`
- `scrolln`
- `scroll_buffer`
- `touch_line`
- `scroll_up`
- `scroll_down`
- `scroll_idl`

---

### terminal_renderer_hashmap.go

#### Structs
- [x] `hashmap` (line 17)

#### Methods/Functions
- [x] `func hash` (line 6)
- [x] `(s *TerminalRenderer) updateHashmap` (line 27)
- [x] `(s *TerminalRenderer) scrollOldhash` (line 129)
- [x] `(s *TerminalRenderer) growHunks` (line 152)
- [x] `(s *TerminalRenderer) costEffective` (line 235)
- [x] `(s *TerminalRenderer) updateCost` (line 278)
- [x] `(s *TerminalRenderer) updateCostBlank` (line 288)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/terminal_renderer_hashmap.cr`
Structs/Classes:
- `HashMapEntry` (maps to Go `hashmap`)
- `TerminalRenderer`
Methods:
- `hash_line` (maps to `func hash`)
- `update_hashmap`
- `scroll_oldhash`
- `grow_hunks`
- `cost_effective`
- `update_cost`
- `update_cost_blank`

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
- [x] `(t *Terminal) makeRaw` (line 10)
- [x] `(t *Terminal) getSize` (line 35)
- [x] `(t *Terminal) optimizeMovements` (line 50)

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
- [x] `(t *Terminal) makeRaw` (line 13)
- [x] `(t *Terminal) getSize` (line 55)
- [x] `(t *Terminal) optimizeMovements` (line 62)
- [x] `func supportsBackspace` (line 67)
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
- [x] `func OpenTTY` (line 11)
- [x] `func Suspend` (line 16)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/tty.cr`
Methods:
- `open_tty` (maps to `OpenTTY` and platform-specific `openTTY`)
- `suspend` (maps to `Suspend` and platform-specific `suspend`)

---

### tty_other.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func openTTY` (line 8)
- [x] `func suspend` (line 12)

#### Crystal Equivalents
No Crystal file found.

---

### tty_unix.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func openTTY` (line 12)
- [x] `func suspend` (line 20)

#### Crystal Equivalents
No Crystal file found.

---

### tty_windows.go

#### Structs
- No structs

#### Methods/Functions
- [x] `func openTTY` (line 8)
- [x] `func suspend` (line 23)

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
- [x] `Cursor` (line 51)
- [x] `ProgressBar` (line 105)

#### Methods/Functions
- [x] `(f DrawableFunc) Draw` (line 22)
- [x] `func NewCursor` (line 68)
- [x] `(s ProgressBarState) String` (line 90)
- [x] `func NewProgressBar` (line 118)

#### Crystal Equivalents
No Crystal file found.

---

### winch.go

#### Structs
- [x] `SizeNotifier` (line 12)

#### Methods/Functions
- [x] `func NewSizeNotifier` (line 23)
- [x] `(n *SizeNotifier) Start` (line 37)
- [x] `(n *SizeNotifier) Stop` (line 42)
- [x] `(n *SizeNotifier) GetWindowSize` (line 47)
- [x] `(n *SizeNotifier) GetSize` (line 52)

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
- `new_size_notifier`
- `size`

---

### winch_other.go

#### Structs
- No structs

#### Methods/Functions
- [x] `(n *SizeNotifier) start` (line 6)
- [x] `(n *SizeNotifier) stop` (line 10)
- [x] `(n *SizeNotifier) getWindowSize` (line 14)

#### Crystal Equivalents
Crystal file: src/ultraviolet/winch.cr

---

### winch_unix.go

#### Structs
- No structs

#### Methods/Functions
- [x] `(n *SizeNotifier) start` (line 14)
- [x] `(n *SizeNotifier) stop` (line 25)
- [x] `(n *SizeNotifier) getWindowSize` (line 32)

#### Crystal Equivalents
Crystal file: src/ultraviolet/winch.cr

---

### window.go

#### Structs
- [x] `Window` (line 10)

#### Methods/Functions
- [x] `(w *Window) HasParent` (line 25)
- [x] `(w *Window) Parent` (line 31)
- [x] `(w *Window) MoveTo` (line 36)
- [x] `(w *Window) MoveBy` (line 45)
- [x] `(w *Window) Clone` (line 55)
- [x] `(w *Window) CloneArea` (line 63)
- [x] `(w *Window) Resize` (line 73)
- [x] `(w *Window) WidthMethod` (line 84)
- [x] `(w *Window) Bounds` (line 89)
- [x] `(w *Window) NewWindow` (line 97)
- [x] `(w *Window) NewView` (line 104)
- [x] `func NewScreen` (line 111)
- [x] `(w *Window) SetWidthMethod` (line 117)
- [x] `func newWindow` (line 123)

#### Crystal Equivalents
Crystal file: `src/ultraviolet/window.cr`
Structs/Classes:
- `Window`
Methods:
- `initialize`
- `bounds`
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
- `new_screen`

---

