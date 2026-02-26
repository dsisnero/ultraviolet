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
      if cursor = @cursor
        if !cursor.hidden? && cursor.position.x >= 0 && cursor.position.y >= 0
          @renderer.move_to(cursor.position.x, cursor.position.y)
        end
      elsif !@alt_screen
        x, y = @renderer.position
        @renderer.move_to(0, y) if x >= width - 1
      end
      @renderer.flush
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
      if @alt_screen
        @renderer.write_string(Ansi::ResetModeAltScreenSaveCursor)
      end
      @renderer.write_string(Ansi::ShowCursor)
      set_mouse_mode(MouseMode::None) unless @mouse_mode.none?
      set_cursor_style(CursorShape::Block, true) if @cursor
      set_cursor_color(nil) if @cursor.try(&.color)
      set_background_color(nil) if @background_color
      set_foreground_color(nil) if @foreground_color
      disable_bracketed_paste if @bracketed_paste
      set_window_title("") unless @window_title.empty?
      set_progress_bar(nil) if @progress_bar
      set_keyboard_enhancements(nil) if @keyboard_enhancements
      @renderer.move_to(0, {height - 1, 0}.max)
    end

    def restore : Nil
      enter_alt_screen if @alt_screen
      if cursor_visible?
        @renderer.write_string(Ansi::ShowCursor)
      else
        @renderer.write_string(Ansi::HideCursor)
      end
      set_keyboard_enhancements(@keyboard_enhancements) if @keyboard_enhancements
      set_mouse_mode(@mouse_mode) unless @mouse_mode.none?
      if cursor = @cursor
        set_cursor_style(cursor.shape, cursor.blink?) if cursor.shape != CursorShape::Block || !cursor.blink?
        set_cursor_color(cursor.color) if cursor.color
      end
      set_background_color(@background_color) if @background_color
      set_foreground_color(@foreground_color) if @foreground_color
      enable_bracketed_paste if @bracketed_paste
      set_window_title(@window_title) unless @window_title.empty?
      set_progress_bar(@progress_bar) if @progress_bar
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
