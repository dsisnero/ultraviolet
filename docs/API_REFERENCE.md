# API Reference

Crystal Ultraviolet API mapped to Go upstream types.

## Core Types

### Cell

| Go | Crystal |
|----|---------|
| `uv.Cell` struct | `Ultraviolet::Cell` struct ([cell.cr](../src/ultraviolet/cell.cr)) |
| `uv.EmptyCell` | `Ultraviolet::EMPTY_CELL` |
| `uv.NewCell(method, content)` | `Ultraviolet::Cell.new(content, width, style?, link?)` |
| `c.Content` | `cell.content : String` |
| `c.Width` | `cell.width : Int32` |
| `c.Style` | `cell.style : Style` |
| `c.Link` | `cell.link : Link` |

### Style

| Go | Crystal |
|----|---------|
| `uv.Style` struct | `Ultraviolet::Style` struct ([style.cr](../src/ultraviolet/style.cr)) |
| `s.Fg`, `s.Bg` | `style.fg : Color?`, `style.bg : Color?` |
| `s.Attrs` | `style.attrs : Attr` (bitmask) |
| `s.Underline` | `style.underline : Underline` |
| `s.UnderlineColor` | `style.underline_color : Color?` |
| `uv.StyleDiff(from, to)` | `Style.diff(from, to)` / `to.diff(from)` |

### Key

| Go | Crystal |
|----|---------|
| `uv.Key` struct | `Ultraviolet::Key` struct ([key.cr](../src/ultraviolet/key.cr)) |
| `k.Code` | `key.code : Int32` |
| `k.Text` | `key.text : String` |
| `k.Mod` | `key.mod : KeyMod` |
| `k.BaseCode` | `key.base_code : Int32` |
| `k.ShiftedCode` | `key.shifted_code : Int32` |
| `k.Keystroke()` | `key.keystroke : String` |
| `k.String()` | `key.string : String` |
| `k.MatchString(s)` | `key.match_string(s : String) : Bool` |

### Mouse

| Go | Crystal |
|----|---------|
| `uv.Mouse` struct | `Ultraviolet::Mouse` struct ([mouse.cr](../src/ultraviolet/mouse.cr)) |
| `uv.MouseButton` type | `Ultraviolet::MouseButton` enum |
| `uv.MouseMode` type | `Ultraviolet::MouseMode` enum |

### Events

| Go | Crystal |
|----|---------|
| `uv.Event` interface | `Ultraviolet::Event` alias |
| `uv.KeyPressEvent` | `Ultraviolet::Key` (press) |
| `uv.KeyReleaseEvent` | `Ultraviolet::KeyReleaseEvent` |
| `uv.MouseClickEvent` | `Ultraviolet::MouseClickEvent` |
| `uv.MouseMotionEvent` | `Ultraviolet::MouseMotionEvent` |
| `uv.MouseReleaseEvent` | `Ultraviolet::MouseReleaseEvent` |
| `uv.MouseWheelEvent` | `Ultraviolet::MouseWheelEvent` |
| `uv.WindowSizeEvent` | `Ultraviolet::WindowSizeEvent` |
| `uv.PixelSizeEvent` | `Ultraviolet::PixelSizeEvent` |
| `uv.FocusEvent` | `Ultraviolet::FocusEvent` |
| `uv.BlurEvent` | `Ultraviolet::BlurEvent` |
| `uv.PasteStartEvent` | `Ultraviolet::PasteStartEvent` |
| `uv.PasteEvent` | `Ultraviolet::PasteEvent` |
| `uv.PasteEndEvent` | `Ultraviolet::PasteEndEvent` |

## Terminal

| Go | Crystal |
|----|---------|
| `uv.NewTerminal(con, opts)` | `Ultraviolet::Terminal.new(console, options?)` |
| `uv.DefaultTerminal()` | `Ultraviolet::Terminal.default_terminal` |
| `uv.ControllingTerminal()` | `Ultraviolet::Terminal.controlling_terminal` |
| `t.Start()` | `term.start` |
| `t.Stop()` | `term.shutdown(timeout)` |
| `t.Events()` returns `<-chan Event` | `term.events : Channel(Event)` |
| `t.Screen()` returns `*TerminalScreen` | Terminal itself implements `Screen` |
| `t.SendEvent(ev)` | `term.events.send(ev)` |

## TerminalScreen

| Go | Crystal |
|----|---------|
| `uv.NewTerminalScreen(w, env)` | `Ultraviolet::TerminalScreen.new(writer, env)` |
| `scr.EnterAltScreen()` | `screen.enter_alt_screen` |
| `scr.ExitAltScreen()` | Not used directly; `reset` emits exit sequence |
| `scr.Reset()` | `screen.reset : Nil` (emits ANSI, preserves state) |
| `scr.Restore()` | `screen.restore : Nil` (re-emits previous state) |
| `scr.Display(drawable)` | `screen.display(drawable?)` |
| `scr.Render()` | `screen.render` |
| `scr.Flush()` | `screen.flush` |
| `scr.SetMouseMode(m)` | `screen.set_mouse_mode(mode)` |
| `scr.SetKeyboardEnhancements(ke)` | `screen.set_keyboard_enhancements(enh)` |
| `scr.InsertAbove(content)` | `screen.insert_above(content)` |

## Buffer / RenderBuffer / ScreenBuffer

| Go | Crystal |
|----|---------|
| `uv.NewBuffer(w, h)` | `Ultraviolet::Buffer.new(width, height)` |
| `uv.NewRenderBuffer(w, h)` | `Ultraviolet::RenderBuffer.new(width, height)` |
| `uv.NewScreenBuffer(w, h)` | `Ultraviolet::ScreenBuffer.new(width, height, method?)` |
| `b.CellAt(x, y)` | `buffer.cell_at(x, y)` |
| `b.SetCell(x, y, c)` | `buffer.set_cell(x, y, cell)` |
| `b.Clear()` | `buffer.clear` |
| `b.Fill(c)` | `buffer.fill(cell)` |
| `b.Clone()` | `buffer.clone` |
| `b.Resize(w, h)` | `buffer.resize(width, height)` |

## Color Types

| Go | Crystal |
|----|---------|
| `image/color.Color` interface | `Ultraviolet::Color` struct ([event.cr](../src/ultraviolet/event.cr)) |
| `color.RGBA{R, G, B, A}` | `Ultraviolet::Color.new(r, g, b)` |
| `colorprofile.Profile` | `Ultraviolet::ColorProfile` enum ([colorprofile.cr](../src/ultraviolet/colorprofile.cr)) |
| `colorprofile.TrueColor` | `ColorProfile::TrueColor` |
| `colorprofile.ANSI256` | `ColorProfile::ANSI256` |
| `colorprofile.ANSI` | `ColorProfile::ANSI` |
| `colorprofile.Ascii` | `ColorProfile::Ascii` |
| `colorprofile.NoTTY` | `ColorProfile::NoTTY` |

## Screen Context

| Go | Crystal |
|----|---------|
| `screen.NewContext(scr)` | `Context` is not separate in Crystal; StyledString draws directly |
| `ctx.SetForeground(c)` | `StyledString`-parsed ANSI codes set styles inline |
| `ctx.DrawString(s)` | `StyledString#draw` method |
| `ctx.Print(args...)` | Use `StyledString` or `Buffer#set_cell` |
