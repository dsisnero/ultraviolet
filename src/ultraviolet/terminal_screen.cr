module Ultraviolet
  class TerminalScreen
    include Screen

    @screen : ScreenBuffer
    @writer : IO
    @buf : IO::Memory
    @renderer : TerminalRenderer
    @profile : ColorProfile
    @alt_screen : Bool
    @keyboard_enhancements : KeyboardEnhancements?
    @bracketed_paste : Bool
    @mouse_mode : MouseMode
    @mouse_encoding : MouseEncoding
    @synchronized_updates : Bool
    @width_method_override : Bool
    @cursor : Cursor?
    @background_color : Color?
    @foreground_color : Color?
    @progress_bar : ProgressBar?
    @program_status : ProgramStatus?
    @window_title : String

    def initialize(writer : IO, env : Array(String) = [] of String)
      @screen = ScreenBuffer.new(0, 0)
      # Like Go's `NewTerminalRenderer(s.buf, …)`: the renderer writes into this
      # screen's own queue, and only #render drains it, so a cursor write made by
      # #flush waits for the next frame.
      @writer = writer
      @buf = IO::Memory.new
      @renderer = TerminalRenderer.new(@buf, env)
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
      @width_method_override = false
      @cursor = nil
      @background_color = nil
      @foreground_color = nil
      @progress_bar = nil
      @program_status = nil
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

    # set_width_method applies an explicit width method, which also pins it: a
    # later Unicode core negotiation must not override an application's choice.
    def set_width_method(method : WidthMethod) : Nil
      @width_method_override = true
      apply_width_method(method)
    end

    private def apply_width_method(method : WidthMethod) : Nil
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

    # request_grapheme_width asks the terminal whether it measures cell width by
    # grapheme cluster (DECRQM for Unicode core mode, DEC mode 2027). The reply
    # arrives as a ModeReportEvent; see Terminal#handle_event.
    def request_grapheme_width : Nil
      queue_string(Ansi::RequestModeUnicodeCore)
    end

    # enable_grapheme_width turns Unicode core mode on and switches every width
    # consumer to grapheme measurement, so what this port draws matches what the
    # terminal paints. An explicit width method wins: the negotiation is a no-op
    # once the application has set one.
    def enable_grapheme_width : Nil
      return if @width_method_override

      queue_string(Ansi::SetModeUnicodeCore)
      @renderer.set_width_method(Ansi::GraphemeWidth)
      @renderer.set_grapheme_width(true)
      apply_width_method(GRAPHEME_WIDTH_METHOD)
      # Go flushes here: the mode has to reach the terminal before the next
      # frame is measured against it.
      flush
    end

    def mouse_encoding : MouseEncoding
      @mouse_encoding
    end

    def resize(width : Int32, height : Int32) : Nil
      @screen.resize(width, height)
      @renderer.resize(width, height)
      @renderer.erase
    end

    def display(drawable : Drawable?) : Nil
      if drawable
        @screen.clear
        drawable.draw(self, @screen.bounds)
      end
      render
      flush
    end

    # render mirrors Go's `TerminalScreen.Render`: paint the frame, then let the
    # renderer drain its own bytes into this screen's queue (`rend.Flush` in Go).
    # The queue reaches the terminal on #flush.
    def render : Nil
      @renderer.render(@screen)
      @renderer.flush
    end

    # flush mirrors Go's `TerminalScreen.Flush`: write the queue, then decide
    # where the cursor belongs. The cursor move goes through the renderer, which
    # only #render drains, so those bytes land with the next frame.
    def flush : Nil
      if cursor = @cursor
        if !cursor.hidden? && cursor.position.x >= 0 && cursor.position.y >= 0
          @renderer.move_to(cursor.position.x, cursor.position.y)
        end
      elsif !@alt_screen
        x, y = @renderer.position
        @renderer.move_to(0, y) if x >= width - 1
      end

      drain
    end

    # drain writes the queue to the terminal. Go writes the synchronized-update
    # mode around it, and only when it holds something.
    private def drain : Nil
      return if @buf.size == 0

      @writer.write(Ansi::SetModeSynchronizedOutput.to_slice) if @synchronized_updates
      @buf.rewind
      IO.copy(@buf, @writer)
      @buf.clear
      @writer.write(Ansi::ResetModeSynchronizedOutput.to_slice) if @synchronized_updates
      @writer.flush
    end

    # enter_alt_screen mirrors Go's `TerminalScreen.EnterAltScreen`: the mode is
    # queued for the terminal and only the renderer's own flags change with it.
    def enter_alt_screen : Nil
      queue_string(Ansi::SetModeAltScreenSaveCursor)
      if (cursor = @cursor) && !cursor.hidden?
        queue_string(Ansi::ShowCursor)
      else
        queue_string(Ansi::HideCursor)
      end
      if enh = @keyboard_enhancements
        queue_string(String.build { |io| Ultraviolet.encode_keyboard_enhancements(io, enh) })
      end
      unless @alt_screen
        @renderer.save_cursor
        @renderer.erase
        @renderer.fullscreen = true
        @renderer.relative_cursor = false
        @alt_screen = true
      end
    end

    # exit_alt_screen mirrors Go's `TerminalScreen.ExitAltScreen`.
    def exit_alt_screen : Nil
      return unless @alt_screen

      queue_string(Ansi::ResetModeAltScreenSaveCursor)
      if @cursor.nil? || (cursor = @cursor) && cursor.hidden?
        queue_string(Ansi::HideCursor)
      else
        queue_string(Ansi::ShowCursor)
      end
      if enh = @keyboard_enhancements
        queue_string(String.build { |io| Ultraviolet.encode_keyboard_enhancements(io, enh) })
      end
      @renderer.restore_cursor
      @renderer.erase
      @renderer.fullscreen = false
      @renderer.relative_cursor = true
      @alt_screen = false
    end

    def alt_screen? : Bool
      @alt_screen
    end

    def hide_cursor : Nil
      queue_string(Ansi::HideCursor)
      if cursor = @cursor
        cursor.hidden = true
        @cursor = cursor
      end
    end

    def show_cursor : Nil
      queue_string(Ansi::ShowCursor)
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
      queue_string(Ansi.set_cursor_style(shape.encode(blink)))
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
      queue_string(seq)
      cursor = @cursor || Ultraviolet.new_cursor(-1, -1)
      cursor.color = color
      @cursor = cursor
    end

    def cursor_color : Color?
      @cursor.try(&.color)
    end

    def set_background_color(color : Color?) : Nil
      seq = String.build { |io| Ultraviolet.encode_background_color(io, color) }
      queue_string(seq)
      @background_color = color
    end

    def background_color : Color?
      @background_color
    end

    def set_foreground_color(color : Color?) : Nil
      seq = String.build { |io| Ultraviolet.encode_foreground_color(io, color) }
      queue_string(seq)
      @foreground_color = color
    end

    def foreground_color : Color?
      @foreground_color
    end

    def enable_bracketed_paste : Nil
      queue_string(Ansi::SetModeBracketedPaste)
      @bracketed_paste = true
    end

    def disable_bracketed_paste : Nil
      queue_string(Ansi::ResetModeBracketedPaste)
      @bracketed_paste = false
    end

    def bracketed_paste? : Bool
      @bracketed_paste
    end

    def set_mouse_mode(mode : MouseMode) : Nil
      seq = String.build { |io| Ultraviolet.encode_mouse_mode(io, mode) }
      queue_string(seq)
      @mouse_mode = mode
    end

    def mouse_mode : MouseMode
      @mouse_mode
    end

    def set_window_title(title : String) : Nil
      seq = String.build { |io| Ultraviolet.encode_window_title(io, title) }
      queue_string(seq)
      @window_title = title
    end

    def window_title : String
      @window_title
    end

    def set_keyboard_enhancements(enhancements : KeyboardEnhancements?) : Nil
      seq = String.build { |io| Ultraviolet.encode_keyboard_enhancements(io, enhancements) }
      queue_string(seq)
      @keyboard_enhancements = enhancements
    end

    def keyboard_enhancements : KeyboardEnhancements?
      @keyboard_enhancements
    end

    def set_progress_bar(progress : ProgressBar?) : Nil
      seq = String.build { |io| Ultraviolet.encode_progress_bar(io, progress) }
      queue_string(seq)
      @progress_bar = progress
    end

    def progress_bar : ProgressBar?
      @progress_bar
    end

    def set_program_status(status : ProgramStatus?) : Nil
      seq = String.build { |io| Ultraviolet.encode_program_status(io, status) }
      queue_string(seq)
      @program_status = status
    end

    def program_status : ProgramStatus?
      @program_status
    end

    def reset : Nil
      has_keyboard = !@keyboard_enhancements.nil?

      if @alt_screen
        # Emit KittyKeyboard(0,1) before exiting alt screen to prevent
        # mis-rendered characters in terminals that support the kitty
        # keyboard protocol.
        queue_string(Ansi.kitty_keyboard(0, 1)) if has_keyboard
        queue_string(Ansi::ResetModeAltScreenSaveCursor)
      end

      # Show the cursor unless the cursor is explicitly hidden.
      if (cursor = @cursor) ? !cursor.hidden? : true
        queue_string(Ansi::ShowCursor)
      end

      # Emit mouse mode reset directly; don't change @mouse_mode so Restore works.
      unless @mouse_mode.none?
        seq = String.build { |io| Ultraviolet.encode_mouse_mode(io, MouseMode::None) }
        queue_string(seq)
      end

      # Reset mouse encoding to legacy; preserve @mouse_encoding for Restore.
      unless @mouse_encoding.legacy?
        seq = String.build { |io| Ultraviolet.encode_mouse_encoding(io, MouseEncoding::Legacy) }
        queue_string(seq)
      end

      if cursor = @cursor
        if cursor.shape != CursorShape::Block || !cursor.blink?
          queue_string(Ansi.set_cursor_style(0))
        end
        if cursor.color
          queue_string(Ansi::ResetCursorColor)
        end
      end

      if @background_color
        queue_string(Ansi::ResetBackgroundColor)
      end

      if @foreground_color
        queue_string(Ansi::ResetForegroundColor)
      end

      if @bracketed_paste
        queue_string(Ansi::ResetModeBracketedPaste)
      end

      unless @window_title.empty?
        queue_string(Ansi.set_window_title(""))
      end

      if (pb = @progress_bar) && !pb.state.none?
        seq = String.build { |io| Ultraviolet.encode_progress_bar(io, nil) }
        queue_string(seq)
      end

      # The program status is deliberately left in place. The Program Status
      # Protocol expects done and error records to outlive the program, and
      # terminals drop working and blocked records on their own when the
      # process exits or the next shell prompt starts.

      # KittyKeyboard(0,1) is also emitted here if keyboard enhancements exist.
      # Preserve @keyboard_enhancements so Restore can re-emit them.
      if has_keyboard
        queue_string(Ansi.kitty_keyboard(0, 1))
      end

      @renderer.move_to(0, {height - 1, 0}.max)
    end

    def restore : Nil
      # Emit raw ANSI sequences (do NOT modify internal state via setters
      # so state survives reset/restore cycles — matching Go behavior).
      if @alt_screen
        queue_string(Ansi::SetModeAltScreenSaveCursor)
      end

      if (cursor = @cursor) && !cursor.hidden?
        queue_string(Ansi::ShowCursor)
      else
        queue_string(Ansi::HideCursor)
      end

      if enh = @keyboard_enhancements
        seq = String.build { |io| Ultraviolet.encode_keyboard_enhancements(io, enh) }
        queue_string(seq)
      end

      unless @mouse_mode.none?
        seq = String.build { |io| Ultraviolet.encode_mouse_mode(io, @mouse_mode) }
        queue_string(seq)
      end

      if cursor = @cursor
        if cursor.shape != CursorShape::Block || !cursor.blink?
          queue_string(Ansi.set_cursor_style(cursor.shape.encode(cursor.blink?)))
        end
        if cursor.color
          seq = String.build { |io| Ultraviolet.encode_cursor_color(io, cursor.color) }
          queue_string(seq)
        end
      end

      if @background_color
        seq = String.build { |io| Ultraviolet.encode_background_color(io, @background_color) }
        queue_string(seq)
      end

      if @foreground_color
        seq = String.build { |io| Ultraviolet.encode_foreground_color(io, @foreground_color) }
        queue_string(seq)
      end

      if @bracketed_paste
        queue_string(Ansi::SetModeBracketedPaste)
      end

      unless @window_title.empty?
        seq = String.build { |io| Ultraviolet.encode_window_title(io, @window_title) }
        queue_string(seq)
      end

      if (pb = @progress_bar) && !pb.state.none?
        seq = String.build { |io| Ultraviolet.encode_progress_bar(io, pb) }
        queue_string(seq)
      end

      if ps = @program_status
        seq = String.build { |io| Ultraviolet.encode_program_status(io, ps) }
        queue_string(seq)
      end

      render
    end

    # write queues bytes for the terminal, like Go's `TerminalScreen.Write`.
    def write(bytes : Bytes) : Int32
      queue_bytes(bytes)
      bytes.size
    end

    # write_string queues a string for the terminal, like Go's
    # `TerminalScreen.WriteString`.
    def write_string(value : String) : Int32
      queue_string(value)
      value.bytesize
    end

    # queue_string queues bytes this screen sends on its own behalf, the way Go
    # writes them straight into `TerminalScreen.buf`. They go out on #flush.
    private def queue_string(value : String) : Nil
      @buf.write(value.to_slice)
    end

    private def queue_bytes(bytes : Bytes) : Nil
      @buf.write(bytes)
    end

    # insert_above mirrors Go's `TerminalScreen.InsertAbove`: write straight to
    # the terminal, outside the frame the renderer manages.
    def insert_above(content : String) : Nil
      return if content.empty?
      @renderer.prepend_string(@screen, content)
      render
      drain
    end
  end

  # Go-compatible constructor alias for [TerminalScreen.new].
  def self.new_terminal_screen(writer : IO, env : Array(String) = [] of String) : TerminalScreen
    TerminalScreen.new(writer, env)
  end
end
