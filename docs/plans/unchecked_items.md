# Unchecked Items (Missing Ports)












## poll_linux.go
- `epollReader`

## poll_select.go
- `selectReader`

## poll_windows.go
- `conReader`

## styled.go
- `func ReadLink`

## tabstop.go
- `(ts *TabStops) mask`

## terminal.go
- `state`
- `func DefaultTerminal`
- `func NewTerminal`
- `(t *Terminal) ColorProfile`
- `(t *Terminal) SetColorProfile`
- `(t *Terminal) ColorModel`
- `(t *Terminal) Convert`
- `(t *Terminal) SetCell`
- `(t *Terminal) CellAt`
- `func prependLine`
- `(t *Terminal) EnterAltScreen`
- `(t *Terminal) ShowCursor`
- `(t *Terminal) HideCursor`
- `(t *Terminal) SendEvent`
- `(t *Terminal) PrependString`
- `(t *Terminal) PrependLines`
- `func setAltScreen`
- `(t *Terminal) inputLoop`
- `(t *Terminal) eventLoop`
- `(t *Terminal) restoreState`

## terminal_other.go
- `(*Terminal) makeRaw`
- `(*Terminal) getSize`
- `(*Terminal) enableWindowsMouse`
- `(*Terminal) disableWindowsMouse`

## terminal_reader.go
- `func NewTerminalReader`
- `(d *TerminalReader) StreamEvents`
- `(d *TerminalReader) sendEvents`
- `(d *TerminalReader) scanEvents`
- `(d *TerminalReader) encodeGraphemeBufs`
- `(d *TerminalReader) storeGraphemeRune`
- `(d *TerminalReader) deserializeWin32Input`

## terminal_reader_other.go
- `(d *TerminalReader) streamData`

## terminal_reader_windows.go
- `(d *TerminalReader) streamData`
- `(d *TerminalReader) serializeWin32InputRecords`
- `func mouseEventButton`
- `func highWord`
- `func readNConsoleInputs`
- `func readConsoleInput`
- `func peekConsoleInput`
- `func peekNConsoleInputs`

## terminal_renderer.go
- `cursor`
- `LineData`
- `(v *capabilities) Reset`
- `(v capabilities) Contains`
- `(v *tFlag) Reset`
- `(v tFlag) Contains`
- `(s *TerminalRenderer) SetColorProfile`
- `(s *TerminalRenderer) SetScrollOptim`
- `(s *TerminalRenderer) SetMapNewline`
- `(s *TerminalRenderer) SetRelativeCursor`
- `(s *TerminalRenderer) SaveCursor`
- `(s *TerminalRenderer) RestoreCursor`
- `(s *TerminalRenderer) EnterAltScreen`
- `(s *TerminalRenderer) PrependString`
- `func cellEqual`
- `(s *TerminalRenderer) putCell`
- `(s *TerminalRenderer) wrapCursor`
- `(s *TerminalRenderer) putAttrCell`
- `(s *TerminalRenderer) putCellLR`
- `(s *TerminalRenderer) updatePen`
- `func canClearWith`
- `(s *TerminalRenderer) emitRange`
- `(s *TerminalRenderer) putRange`
- `(s *TerminalRenderer) clearToEnd`
- `(s *TerminalRenderer) clearBlank`
- `(s *TerminalRenderer) insertCells`
- `(s *TerminalRenderer) el0Cost`
- `(s *TerminalRenderer) transformLine`
- `(s *TerminalRenderer) deleteCells`
- `(s *TerminalRenderer) clearToBottom`
- `(s *TerminalRenderer) clearBottom`
- `(s *TerminalRenderer) clearScreen`
- `(s *TerminalRenderer) clearBelow`
- `(s *TerminalRenderer) clearUpdate`
- `func notLocal`

## terminal_renderer_hardscroll.go
- `(s *TerminalRenderer) scrollOptimize`
- `(s *TerminalRenderer) scrolln`
- `(s *TerminalRenderer) scrollBuffer`
- `(s *TerminalRenderer) touchLine`
- `(s *TerminalRenderer) scrollUp`
- `(s *TerminalRenderer) scrollDown`
- `(s *TerminalRenderer) scrollIdl`

## terminal_renderer_hashmap.go
- `hashmap`
- `func hash`
- `(s *TerminalRenderer) updateHashmap`
- `(s *TerminalRenderer) scrollOldhash`
- `(s *TerminalRenderer) growHunks`
- `(s *TerminalRenderer) costEffective`
- `(s *TerminalRenderer) updateCost`
- `(s *TerminalRenderer) updateCostBlank`

## terminal_unix.go
- `(t *Terminal) makeRaw`
- `(t *Terminal) getSize`
- `(t *Terminal) optimizeMovements`

## terminal_windows.go
- `(t *Terminal) makeRaw`
- `(t *Terminal) getSize`
- `(t *Terminal) optimizeMovements`
- `func supportsBackspace`

## tty.go
- `func OpenTTY`

## tty_other.go
- `func openTTY`
- `func suspend`

## tty_unix.go
- `func openTTY`
- `func suspend`

## tty_windows.go
- `func openTTY`
- `func suspend`

## uv.go
- `Cursor`
- `ProgressBar`
- `func NewCursor`
- `(s ProgressBarState) String`
- `func NewProgressBar`

## winch.go
- `func NewSizeNotifier`
- `(n *SizeNotifier) GetWindowSize`
- `(n *SizeNotifier) GetSize`

## winch_other.go
- `(n *SizeNotifier) start`
- `(n *SizeNotifier) stop`
- `(n *SizeNotifier) getWindowSize`

## winch_unix.go
- `(n *SizeNotifier) start`
- `(n *SizeNotifier) stop`
- `(n *SizeNotifier) getWindowSize`

## window.go
- `(w *Window) HasParent`
- `(w *Window) MoveTo`
- `(w *Window) MoveBy`
- `(w *Window) Bounds`
- `(w *Window) NewWindow`
- `(w *Window) NewView`
- `func NewScreen`
- `func newWindow`

