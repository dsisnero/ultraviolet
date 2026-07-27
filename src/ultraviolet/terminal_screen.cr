module Ultraviolet
  class TerminalScreen
    include Screen

    @screen : ScreenBuffer
    @renderer : TerminalRenderer
    @profile : ColorProfile
    @alt_screen : Bool
    @keyboard_enhancements : KeyboardEnhancements?
    @bracketed_paste : Bool
    @mouse_mode : MouseMode
    @mouse_encoding : MouseEncoding
    @synchronized_updates : Bool
    @cursor : Cursor?
    @background_color : Color?
    @foreground_color : Color?
    @progress_bar : ProgressBar?
    @window_title : String

    def initialize(writer : IO, env : Array(String) = [] of String)
      @screen = ScreenBuffer.new(0, 0)
      @renderer = TerminalRenderer.new(writer, env)
      @profile = ColorProfile.detect(writer, env)
      @renderer.fullscreen = false
      @renderer.relative_cursor = true
      @renderer.color_profile = @profile
      @renderer.map_newline = false

      @alt_screen = false
      @keyboard_enhancements = nil
      @bracketed_paste = false
      @mouse_mode = MouseMode::None
      @mouse_encoding = MouseEncoding::Legacy
      @synchronized_updates = false
      @cursor = nil
      @background_color = nil
      @foreground_color = nil
      @progress_bar = nil
      @window_title = ""
    end

    def cell_at(x : Int32, y : Int32) : Cell?
      @screen.cell_at(x, y)
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      @screen.set_cell(x, y, cell)
    end

    def bounds : Rectangle
      @screen.bounds
    end

    def width_method : WidthMethod
      @screen.width_method
    end

    def set_width_method(method : WidthMethod) : Nil
      @screen.method = method
    end

    def width_method=(method : WidthMethod) : Nil
      set_width_method(method)
    end

    def set_color_profile(profile : ColorProfile) : Nil
      @profile = profile
      @renderer.color_profile = profile
    end

    def color_profile=(profile : ColorProfile) : Nil
      set_color_profile(profile)
    end

    def width : Int32
      @screen.width
    end

    def height : Int32
      @screen.height
    end

    def string_width(str : String) : Int32
      @screen.width_method.call(str)
    end

    def set_synchronized_updates(enabled : Bool) : Nil
      @synchronized_updates = enabled
    end

    def synchronized_updates? : Bool
      @synchronized_updates
    end

    def set_mouse_encoding(encoding : MouseEncoding) : Nil
      @mouse_encoding = encoding
    end

    def request_grapheme_width : Nil
      @renderer.write_string(Ansi::RequestModeUnicodeCore)
    end

    def enable_grapheme_width : Nil
      @renderer.write_string(Ansi::SetModeUnicodeCore)
      @renderer.set_width_method(Ansi::GraphemeWidth)
      @renderer.set_grapheme_width(true)
    end

    def mouse_encoding : MouseEncoding
      @mouse_encoding
    end

    def resize(width : Int32, height : Int32) : Nil
      @screen.resize(width, height)
      @renderer.resize(width, height)
      @renderer.erase
      @screen.touched = Array(LineData?).new(height, nil)
    end

    def display(drawable : Drawable?) : Nil
      if drawable
        @screen.clear
        drawable.draw(self, @screen.bounds)
      end
      render
      flush
    end

    def render : Nil
      @renderer.render(@screen)
    end

    def flush : Nil
      if @synchronized_updates
        @renderer.write_string(Ansi::SetModeSynchronizedOutput)
      end

      if cursor = @cursor
        if !cursor.hidden? && cursor.position.x >= 0 && cursor.position.y >= 0
          @renderer.move_to(cursor.position.x, cursor.position.y)
        end
      elsif !@alt_screen
        x, y = @renderer.position
        @renderer.move_to(0, y) if x >= width - 1
      end

      @renderer.flush

      if @synchronized_updates
        @renderer.write_string(Ansi::ResetModeSynchronizedOutput)
        @renderer.flush
      end
    end

    def enter_alt_screen : Nil
      return if @alt_screen
      @renderer.enter_alt_screen
      @alt_screen = true
    end

    def exit_alt_screen : Nil
      return unless @alt_screen
      @renderer.exit_alt_screen
      @alt_screen = false
    end

    def alt_screen? : Bool
      @alt_screen
    end

    def hide_cursor : Nil
      @renderer.write_string(Ansi::HideCursor)
      if cursor = @cursor
        cursor.hidden = true
        @cursor = cursor
      end
    end

    def show_cursor : Nil
      @renderer.write_string(Ansi::ShowCursor)
      if cursor = @cursor
        cursor.hidden = false
        @cursor = cursor
      else
        cursor = Ultraviolet.new_cursor(-1, -1)
        cursor.hidden = false
        @cursor = cursor
      end
    end

    def cursor_visible? : Bool
      if cursor = @cursor
        !cursor.hidden?
      else
        false
      end
    end

    def set_cursor_position(x : Int32, y : Int32) : Nil
      if cursor = @cursor
        cursor.position = Position.new(x, y)
        @cursor = cursor
      else
        cursor = Ultraviolet.new_cursor(x, y)
        cursor.hidden = true
        @cursor = cursor
      end
    end

    def cursor_position : {Int32, Int32}
      if cursor = @cursor
        {cursor.position.x, cursor.position.y}
      else
        {-1, -1}
      end
    end

    def set_cursor_style(shape : CursorShape, blink : Bool) : Nil
      @renderer.write_string(Ansi.set_cursor_style(shape.encode(blink)))
      cursor = @cursor || Ultraviolet.new_cursor(-1, -1)
      cursor.shape = shape
      cursor.blink = blink
      @cursor = cursor
    end

    def cursor_style : {CursorShape, Bool}
      if cursor = @cursor
        {cursor.shape, cursor.blink?}
      else
        {CursorShape::Block, true}
      end
    end

    def set_cursor_color(color : Color?) : Nil
      seq = String.build { |io| Ultraviolet.encode_cursor_color(io, color) }
      @renderer.write_string(seq)
      cursor = @cursor || Ultraviolet.new_cursor(-1, -1)
      cursor.color = color
      @cursor = cursor
    end

    def cursor_color : Color?
      @cursor.try(&.color)
    end

    def set_background_color(color : Color?) : Nil
      seq = String.build { |io| Ultraviolet.encode_background_color(io, color) }
      @renderer.write_string(seq)
      @background_color = color
    end

    def background_color : Color?
      @background_color
    end

    def set_foreground_color(color : Color?) : Nil
      seq = String.build { |io| Ultraviolet.encode_foreground_color(io, color) }
      @renderer.write_string(seq)
      @foreground_color = color
    end

    def foreground_color : Color?
      @foreground_color
    end

    def enable_bracketed_paste : Nil
      @renderer.write_string(Ansi::SetModeBracketedPaste)
      @bracketed_paste = true
    end

    def disable_bracketed_paste : Nil
      @renderer.write_string(Ansi::ResetModeBracketedPaste)
      @bracketed_paste = false
    end

    def bracketed_paste? : Bool
      @bracketed_paste
    end

    def set_mouse_mode(mode : MouseMode) : Nil
      seq = String.build { |io| Ultraviolet.encode_mouse_mode(io, mode) }
      @renderer.write_string(seq)
      @mouse_mode = mode
    end

    def mouse_mode : MouseMode
      @mouse_mode
    end

    def set_window_title(title : String) : Nil
      seq = String.build { |io| Ultraviolet.encode_window_title(io, title) }
      @renderer.write_string(seq)
      @window_title = title
    end

    def window_title : String
      @window_title
    end

    def set_keyboard_enhancements(enhancements : KeyboardEnhancements?) : Nil
      seq = String.build { |io| Ultraviolet.encode_keyboard_enhancements(io, enhancements) }
      @renderer.write_string(seq)
      @keyboard_enhancements = enhancements
    end

    def keyboard_enhancements : KeyboardEnhancements?
      @keyboard_enhancements
    end

    def set_progress_bar(progress : ProgressBar?) : Nil
      seq = String.build { |io| Ultraviolet.encode_progress_bar(io, progress) }
      @renderer.write_string(seq)
      @progress_bar = progress
    end

    def progress_bar : ProgressBar?
      @progress_bar
    end

    def reset : Nil
      has_keyboard = !@keyboard_enhancements.nil?

      if @alt_screen
        # Emit KittyKeyboard(0,1) before exiting alt screen to prevent
        # mis-rendered characters in terminals that support the kitty
        # keyboard protocol.
        @renderer.write_string(Ansi.kitty_keyboard(0, 1)) if has_keyboard
        @renderer.write_string(Ansi::ResetModeAltScreenSaveCursor)
      end

      # Show the cursor unless the cursor is explicitly hidden.
      if (cursor = @cursor) ? !cursor.hidden? : true
        @renderer.write_string(Ansi::ShowCursor)
      end

      # Emit mouse mode reset directly; don't change @mouse_mode so Restore works.
      unless @mouse_mode.none?
        seq = String.build { |io| Ultraviolet.encode_mouse_mode(io, MouseMode::None) }
        @renderer.write_string(seq)
      end

      # Reset mouse encoding to legacy; preserve @mouse_encoding for Restore.
      unless @mouse_encoding.legacy?
        seq = String.build { |io| Ultraviolet.encode_mouse_encoding(io, MouseEncoding::Legacy) }
        @renderer.write_string(seq)
      end

      if cursor = @cursor
        if cursor.shape != CursorShape::Block || !cursor.blink?
          @renderer.write_string(Ansi.set_cursor_style(0))
        end
        if cursor.color
          @renderer.write_string(Ansi::ResetCursorColor)
        end
      end

      if @background_color
        @renderer.write_string(Ansi::ResetBackgroundColor)
      end

      if @foreground_color
        @renderer.write_string(Ansi::ResetForegroundColor)
      end

      if @bracketed_paste
        @renderer.write_string(Ansi::ResetModeBracketedPaste)
      end

      unless @window_title.empty?
        @renderer.write_string(Ansi.set_window_title(""))
      end

      if (pb = @progress_bar) && !pb.state.none?
        seq = String.build { |io| Ultraviolet.encode_progress_bar(io, nil) }
        @renderer.write_string(seq)
      end

      # KittyKeyboard(0,1) is also emitted here if keyboard enhancements exist.
      # Preserve @keyboard_enhancements so Restore can re-emit them.
      if has_keyboard
        @renderer.write_string(Ansi.kitty_keyboard(0, 1))
      end

      @renderer.move_to(0, {height - 1, 0}.max)
    end

    def restore : Nil
      # Emit raw ANSI sequences (do NOT modify internal state via setters
      # so state survives reset/restore cycles — matching Go behavior).
      if @alt_screen
        @renderer.write_string(Ansi::SetModeAltScreenSaveCursor)
      end

      if (cursor = @cursor) && !cursor.hidden?
        @renderer.write_string(Ansi::ShowCursor)
      else
        @renderer.write_string(Ansi::HideCursor)
      end

      if enh = @keyboard_enhancements
        seq = String.build { |io| Ultraviolet.encode_keyboard_enhancements(io, enh) }
        @renderer.write_string(seq)
      end

      unless @mouse_mode.none?
        seq = String.build { |io| Ultraviolet.encode_mouse_mode(io, @mouse_mode) }
        @renderer.write_string(seq)
      end

      if cursor = @cursor
        if cursor.shape != CursorShape::Block || !cursor.blink?
          @renderer.write_string(Ansi.set_cursor_style(cursor.shape.encode(cursor.blink?)))
        end
        if cursor.color
          seq = String.build { |io| Ultraviolet.encode_cursor_color(io, cursor.color) }
          @renderer.write_string(seq)
        end
      end

      if @background_color
        seq = String.build { |io| Ultraviolet.encode_background_color(io, @background_color) }
        @renderer.write_string(seq)
      end

      if @foreground_color
        seq = String.build { |io| Ultraviolet.encode_foreground_color(io, @foreground_color) }
        @renderer.write_string(seq)
      end

      if @bracketed_paste
        @renderer.write_string(Ansi::SetModeBracketedPaste)
      end

      unless @window_title.empty?
        seq = String.build { |io| Ultraviolet.encode_window_title(io, @window_title) }
        @renderer.write_string(seq)
      end

      if (pb = @progress_bar) && !pb.state.none?
        seq = String.build { |io| Ultraviolet.encode_progress_bar(io, pb) }
        @renderer.write_string(seq)
      end

      render
    end

    def write(bytes : Bytes) : Int32
      @renderer.write(bytes)
    end

    def write_string(value : String) : Int32
      @renderer.write_string(value)
    end

    def insert_above(content : String) : Nil
      return if content.empty?
      @renderer.prepend_string(@screen, content)
      @renderer.render(@screen)
      @renderer.flush
    end
  end
end
