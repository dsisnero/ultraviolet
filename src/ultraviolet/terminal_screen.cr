module Ultraviolet
  class TerminalScreen
    include Screen

    # buffer is the screen's own window, the grid an application draws into
    # (Go's `TerminalScreen.win`). It is what #render paints.
    getter buffer : ScreenBuffer
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
    @logger : Logger?
    @reset_tabs : Bool

    def initialize(writer : IO, env : Array(String) = [] of String)
      @buffer = ScreenBuffer.new(0, 0)
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

      @logger = nil
      @reset_tabs = false
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
      @buffer.cell_at(x, y)
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      @buffer.set_cell(x, y, cell)
    end

    def bounds : Rectangle
      @buffer.bounds
    end

    # The buffer helpers mirror [Ultraviolet::Window]'s: they operate on the
    # screen's own window.
    def clear : Nil
      @buffer.clear
    end

    def clear_area(area : Rectangle) : Nil
      @buffer.clear_area(area)
    end

    def fill(cell : Cell?) : Nil
      @buffer.fill(cell)
    end

    def fill_area(cell : Cell?, area : Rectangle) : Nil
      @buffer.fill_area(cell, area)
    end

    def clone : Buffer
      @buffer.clone
    end

    def clone_area(area : Rectangle) : Buffer?
      @buffer.clone_area(area)
    end

    def width_method : WidthMethod
      @buffer.width_method
    end

    # set_width_method applies an explicit width method, which also pins it: a
    # later Unicode core negotiation must not override an application's choice.
    # It propagates to the window and the renderer, as Go's `setWidthMethod`
    # does, so measurement and painting agree.
    def set_width_method(method : WidthMethod) : Nil
      @width_method_override = true
      apply_width_method(method)
    end

    private def apply_width_method(method : WidthMethod) : Nil
      @buffer.method = method
      grapheme = method == GRAPHEME_WIDTH_METHOD
      @renderer.set_width_method(grapheme ? Ansi::GraphemeWidth : Ansi::WcWidth)
      @renderer.set_grapheme_width(grapheme)
    end

    def width_method=(method : WidthMethod) : Nil
      set_width_method(method)
    end

    def set_color_profile(profile : ColorProfile) : Nil
      @profile = profile
      @renderer.color_profile = profile
    end

    def color_profile : ColorProfile
      @profile
    end

    def color_profile=(profile : ColorProfile) : Nil
      set_color_profile(profile)
    end

    def logger : Logger?
      @logger
    end

    def logger=(logger : Logger?) : Nil
      @logger = logger
      @renderer.logger = logger
    end

    # configure_movements applies the console's movement optimizations the way
    # Go's `NewTerminalScreen` does from the terminal state: hard tabs need the
    # renderer's tab stops and a tab-stop reset on restore, and backspace is the
    # cheaper way to move one column left.
    def configure_movements(use_tabs : Bool, use_bspace : Bool) : Nil
      @renderer.tab_stops = use_tabs ? width : -1
      @renderer.backspace = use_bspace
      @reset_tabs = use_tabs
    end

    def width : Int32
      @buffer.width
    end

    def height : Int32
      @buffer.height
    end

    def string_width(str : String) : Int32
      @buffer.width_method.call(str)
    end

    def set_synchronized_updates(enabled : Bool) : Nil
      @synchronized_updates = enabled
    end

    def synchronized_updates? : Bool
      @synchronized_updates
    end

    def set_mouse_encoding(encoding : MouseEncoding) : Nil
      seq = String.build { |io| Ultraviolet.encode_mouse_encoding(io, encoding) }
      queue_string(seq)
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
      apply_width_method(GRAPHEME_WIDTH_METHOD)
      # Go flushes here: the mode has to reach the terminal before the next
      # frame is measured against it.
      flush
    end

    def mouse_encoding : MouseEncoding
      @mouse_encoding
    end

    def resize(width : Int32, height : Int32) : Nil
      @buffer.resize(width, height)
      @renderer.resize(width, height)
      @renderer.erase
    end

    # erase clears the screen's window and marks the renderer for a full
    # repaint, which is what a terminal resize needs.
    def erase : Nil
      @renderer.erase
      @buffer.clear
    end

    # buffered and touched report the renderer's state for the screen's window,
    # as the renderer does for a bare [RenderBuffer].
    def buffered : Int32
      @renderer.buffered
    end

    def touched : Int32
      @renderer.touched(@buffer)
    end

    # position and set_position are the renderer's pen, not the cursor the
    # application asked for. They mirror the renderer's own accessors.
    def position : {Int32, Int32}
      @renderer.position
    end

    def set_position(x : Int32, y : Int32) : Nil
      @renderer.set_position(x, y)
    end

    def display(drawable : Drawable?) : Nil
      if drawable
        @buffer.clear
        drawable.draw(self, @buffer.bounds)
      end
      render
      flush
    end

    # drain_renderer drains bytes the renderer is holding into this screen's
    # queue. Go's `Flush` assumes a `Render` already did this; callers that queue
    # renderer output outside a frame (a kitty image transfer, for instance)
    # drain it here first.
    def drain_renderer : Nil
      @renderer.flush
    end

    # render mirrors Go's `TerminalScreen.Render`: paint the frame, then let the
    # renderer drain its own bytes into this screen's queue (`rend.Flush` in Go).
    # The queue reaches the terminal on #flush.
    def render : Nil
      @renderer.render(@buffer)
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
    # mode around it when that is enabled, and otherwise hides the cursor for the
    # duration of the update when it is visible, so a visible cursor cannot
    # flicker across a frame. Both wrappers only appear when the queue holds
    # something.
    private def drain : Nil
      return if @buf.size == 0

      cursor_visible = (cursor = @cursor) ? !cursor.hidden? : false
      if @synchronized_updates
        @writer.write(Ansi::SetModeSynchronizedOutput.to_slice)
      elsif cursor_visible
        @writer.write(Ansi::HideCursor.to_slice)
      end
      @buf.rewind
      IO.copy(@buf, @writer)
      @buf.clear
      if @synchronized_updates
        @writer.write(Ansi::ResetModeSynchronizedOutput.to_slice)
      elsif cursor_visible
        @writer.write(Ansi::ShowCursor.to_slice)
      end
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

    # exit_alt_screen mirrors Go's `TerminalScreen.ExitAltScreen`: the sequence is
    # written every time it is called (Go does not guard it), while only the
    # renderer's own flags change when the screen was actually in alt mode.
    def exit_alt_screen : Nil
      queue_string(Ansi::ResetModeAltScreenSaveCursor)
      if @cursor.nil? || (cursor = @cursor) && cursor.hidden?
        queue_string(Ansi::HideCursor)
      else
        queue_string(Ansi::ShowCursor)
      end
      if enh = @keyboard_enhancements
        queue_string(String.build { |io| Ultraviolet.encode_keyboard_enhancements(io, enh) })
      end
      return unless @alt_screen

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

      # Go emits the pop unconditionally when enhancements are set, after the
      # alt-screen block, and again here.
      queue_string(Ansi.kitty_keyboard(0, 1)) if has_keyboard

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

      @renderer.move_to(0, {height - 1, 0}.max)
    end

    def restore : Nil
      # Emit raw ANSI sequences (do NOT modify internal state via setters
      # so state survives reset/restore cycles — matching Go behavior).
      if @reset_tabs
        queue_string(Ansi::SetTabEvery8Columns)
      end

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

      unless @mouse_encoding.legacy?
        seq = String.build { |io| Ultraviolet.encode_mouse_encoding(io, @mouse_encoding) }
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

    # insert_above mirrors Go's `TerminalScreen.InsertAbove` (terminal_screen.go:
    # relative moves from the renderer's position, one InsertLine for the whole
    # block, then each line followed by EraseLineRight). It writes straight to
    # the terminal, outside the frame the renderer manages, so it needs no
    # #flush afterwards.
    def insert_above(content : String) : Nil
      return if content.empty?

      width = @buffer.width
      height = @buffer.height
      _x, y = @renderer.position

      builder = String::Builder.new
      builder << '\r'
      down = height - y - 1
      builder << Ansi.cursor_down(down) if down > 0

      lines = content.split('\n')
      offset = lines.size
      lines.each do |line|
        line_width = @buffer.width_method.call(line)
        offset += line_width // width if width > 0 && line_width > width
      end

      builder << "\n" * offset
      builder << Ansi.cursor_up(offset + height - 1)
      builder << Ansi.insert_line(offset)
      lines.each do |line|
        builder << line
        builder << Ansi::EraseLineRight
        builder << "\r\n"
      end

      @renderer.set_position(0, 0)
      @writer.write(builder.to_s.to_slice)
      @writer.flush
    end

    # prepend_string queues content above the frame through the renderer's
    # prepend path, which is what [Terminal#prepend_string] displays on the next
    # frame. Go's `InsertAbove` is the immediate variant; see above.
    def prepend_string(value : String) : Nil
      @renderer.prepend_string(@buffer, value)
    end
  end

  # Go-compatible constructor alias for [TerminalScreen.new].
  def self.new_terminal_screen(writer : IO, env : Array(String) = [] of String) : TerminalScreen
    TerminalScreen.new(writer, env)
  end
end
