require "./terminal_renderer"
require "./buffer"
require "./event"
require "./environ"
require "./colorprofile"
require "./poll"

module Ultraviolet
  ErrNotTerminal          = Exception.new("not a terminal")
  ErrPlatformNotSupported = Exception.new("platform not supported")
  ErrRunning              = Exception.new("terminal is running")
  ErrNotRunning           = Exception.new("terminal not running")

  class Terminal
    include Screen

    getter environ : Environ
    getter termtype : String
    getter size : Size
    getter pixel_size : Size
    getter? running : Bool
    property logger : Logger?
    property profile : ColorProfile
    getter method : WidthMethod

    @in : IO
    @out : IO
    @in_tty : IO::FileDescriptor?
    @out_tty : IO::FileDescriptor?
    @in_tty_state : TtyState?
    @out_tty_state : TtyState?
    @buf : RenderBuffer
    @scr : TerminalRenderer
    @method : WidthMethod
    @width_method_override : Bool
    @profile : ColorProfile
    @use_tabs : Bool
    @use_bspace : Bool
    @state : TerminalState
    @last_state : TerminalState?
    @pending_cursor : Bytes
    @prepend : Array(String)
    @evs : Channel(Event)
    @evch : Channel(Event)
    @evloop : Channel(Nil)
    @winch : SizeNotifier?
    @winch_stop : Channel(Nil)?
    @reader : TerminalReader?
    @reader_stop : Channel(Nil)?
    @reader_done : Channel(Nil)?
    @poll_reader : PollReader?
    @logger : Logger?
    @opts : Options

    struct TerminalState
      property? altscreen : Bool
      property? cur_hidden : Bool
      property cur : Position

      def initialize(@altscreen : Bool = false, @cur_hidden : Bool = false, @cur : Position = Position.new(-1, -1))
      end
    end

    def self.default_terminal : Terminal
      Terminal.new(Console.default, Options.default)
    end

    def self.controlling_terminal : Terminal
      Terminal.new(Console.controlling, Options.default)
    end

    def initialize(console : Console, options : Options = Options.default)
      @opts = options
      initialize(console.reader, console.writer, console.environ, options)
    end

    def initialize(@in : IO, @out : IO, env : Array(String) = [] of String, @opts : Options = Options.default)
      @opts = Options.new(
        buffer_size: @opts.buffer_size <= 0 ? DEFAULT_BUFFER_SIZE : @opts.buffer_size,
        event_timeout: @opts.event_timeout <= Time::Span.zero ? DEFAULT_EVENT_TIMEOUT : @opts.event_timeout,
        legacy_key_encoding: @opts.legacy_key_encoding,
        lookup_keys: @opts.lookup_keys,
        use_terminfo_keys: @opts.use_terminfo_keys,
      )
      @environ = Environ.new(env)
      @termtype = @environ.getenv("TERM")
      @scr = TerminalRenderer.new(@out, env)
      @buf = RenderBuffer.new(0, 0)
      @method = DEFAULT_WIDTH_METHOD
      @width_method_override = false
      @profile = ColorProfile.detect(@out, env)
      @scr.color_profile = @profile
      @use_tabs = false
      @use_bspace = false
      @state = TerminalState.new
      @last_state = nil
      @pending_cursor = Bytes.empty
      @prepend = [] of String
      @evs = Channel(Event).new
      @evch = Channel(Event).new
      @evloop = Channel(Nil).new(1)
      @winch_stop = nil
      @reader = nil
      @reader_stop = nil
      @reader_done = nil
      @poll_reader = nil
      @owned_tty = nil.as(IO::FileDescriptor?)
      @running = false
      @size = Size.new(0, 0)
      @pixel_size = Size.new(0, 0)
      @logger = nil
      @in_tty = @in.as?(IO::FileDescriptor)
      @out_tty = @out.as?(IO::FileDescriptor)
      @in_tty_state = nil
      @out_tty_state = nil
      {% unless flag?(:win32) %}
        @winch = SizeNotifier.new(@in_tty || @out_tty)
      {% else %}
        @winch = nil
      {% end %}
    end

    def opts : Options
      @opts
    end

    def logger=(logger : Logger?) : Nil
      @logger = logger
    end

    def color_profile : ColorProfile
      @profile
    end

    def color_profile=(profile : ColorProfile) : Nil
      @profile = profile
    end

    def state : TerminalState
      @state
    end

    def color_model : ColorProfile
      @profile
    end

    def convert(color : Color) : Color
      ColorProfileUtil.convert(@profile, color)
    end

    def width_method : WidthMethod
      @method
    end

    # width_method= pins an explicit measurement choice: a later Unicode core
    # negotiation leaves it alone, and the renderer measures the same way.
    def width_method=(method : WidthMethod) : Nil
      @width_method_override = true
      apply_width_method(method)
    end

    # apply_width_method propagates one choice to every consumer: this terminal
    # (measurement), the renderer (cell widths while painting), and the
    # renderer's grapheme flag.
    private def apply_width_method(method : WidthMethod) : Nil
      @method = method
      grapheme = method == GRAPHEME_WIDTH_METHOD
      @scr.set_width_method(grapheme ? Ansi::GraphemeWidth : Ansi::WcWidth)
      @scr.set_grapheme_width(grapheme)
    end

    # request_grapheme_width asks the terminal whether it measures width by
    # grapheme cluster (DECRQM for Unicode core mode, DEC mode 2027).
    def request_grapheme_width : Nil
      @scr.write_string(Ansi::RequestModeUnicodeCore)
    end

    # enable_grapheme_width turns Unicode core mode on and measures by grapheme
    # cluster, so what this port draws matches what the terminal paints. An
    # explicit width method wins.
    def enable_grapheme_width : Nil
      return if @width_method_override

      @scr.write_string(Ansi::SetModeUnicodeCore)
      apply_width_method(GRAPHEME_WIDTH_METHOD)
      # Go flushes in enableGraphemeWidth: the mode has to reach the terminal
      # before the next frame is measured against it.
      @scr.flush
    end

    def bounds : Rectangle
      Ultraviolet.rect(0, 0, @buf.width, @buf.height)
    end

    def width : Int32
      @buf.width
    end

    def height : Int32
      @buf.height
    end

    def cell_at(x : Int32, y : Int32) : Cell?
      @buf.cell_at(x, y)
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      @buf.set_cell(x, y, cell)
    end

    def clear : Nil
      @buf.clear
    end

    def clear_area(area : Rectangle) : Nil
      @buf.clear_area(area)
    end

    def fill(cell : Cell?) : Nil
      @buf.fill(cell)
    end

    def fill_area(cell : Cell?, area : Rectangle) : Nil
      @buf.fill_area(cell, area)
    end

    def clone : Buffer
      @buf.clone
    end

    def clone_area(area : Rectangle) : Buffer?
      @buf.clone_area(area)
    end

    def position : {Int32, Int32}
      @scr.position
    end

    def set_position(x : Int32, y : Int32) : Nil
      @scr.set_position(x, y)
    end

    def move_to(x : Int32, y : Int32) : Nil
      @state.cur = Position.new(x, y)
    end

    def draw(d : Drawable) : Nil
      frame_area = @size.bounds
      if d.nil?
        # If the component is nil, we should clear the screen buffer.
        frame_area = Ultraviolet.rect(frame_area.min.x, frame_area.min.y, frame_area.dx, 0)
      end

      # We need to resize the screen based on the frame height and
      # terminal width. This is because the frame height can change based on
      # the content of the frame.
      frame_height = frame_area.dy
      case d
      when StyledString
        frame_height = d.height
      else
        # For other Drawable types, use default height
        # Note: In Go, there are type switches for interfaces with Height() and Bounds() methods
        # In Crystal, we would need to define those interfaces separately
      end

      if frame_height != frame_area.dy
        frame_area = Ultraviolet.rect(frame_area.min.x, frame_area.min.y, frame_area.dx, frame_height)
      end

      # Resize the screen buffer to match the frame area
      @buf.resize(frame_area.dx, frame_area.dy)

      # Clear our screen buffer before copying the new frame into it
      @buf.clear
      d.draw(self, @buf.bounds) unless d.nil?

      # If the frame height is greater than the screen height, we drop the
      # lines from the top of the buffer.
      if frame_height > @size.height
        @buf.lines = @buf.lines[frame_height - @size.height..]
      end
    end

    def size_now : {Int32, Int32}
      cols = env_int("COLUMNS")
      rows = env_int("LINES")
      width = cols || 80
      height = rows || 24
      {width, height}
    end

    def fetch_size : {Int32, Int32}
      width, height = platform_size
      size = sanitize_size(width, height)
      @size = size
      {size.width, size.height}
    end

    def size : Size
      @size
    end

    def get_size : {Int32, Int32}
      {@size.width, @size.height}
    end

    def get_winsize : Winsize
      Winsize.new(@size.height.to_u16, @size.width.to_u16, @pixel_size.width.to_u16, @pixel_size.height.to_u16)
    end

    def resize(width : Int32, height : Int32) : Nil
      @buf.resize(width, height)
      @buf.touched = Array(LineData?).new(height) { LineData.new(-1, -1) }
      @scr.resize(width, height)
      # Go's TerminalScreen.Resize marks the renderer for a full erase, so the
      # next frame clears instead of patching a stale screen.
      @scr.erase
    end

    def start : Nil
      raise ErrRunning if @running
      in_tty = @in_tty
      out_tty = @out_tty
      if (!in_tty || !in_tty.tty?) && (!out_tty || !out_tty.tty?)
        raise ErrNotTerminal
      end

      ensure_input_tty
      if ENV["UV_DEBUG_IO"]?
        in_fd = @in_tty.try &.fd
        out_fd = @out_tty.try &.fd
        stdin_fd = STDIN.as(IO::FileDescriptor).fd
        stdout_fd = STDOUT.as(IO::FileDescriptor).fd
        STDERR.puts("uv: fds in=#{in_fd} out=#{out_fd} stdin=#{stdin_fd} stdout=#{stdout_fd}")
      end

      if @last_state.nil?
        # Go's TerminalScreen starts inline and hidden-cursor; the example decides
        # whether to enter the alternate screen before Start. Forcing it here made
        # inline examples emit an exit-alt-screen sequence they never asked for.
        hide_cursor
        @state.cur = Position.new(-1, -1)
      end

      width, height = fetch_size
      @size = Size.new(width, height)
      # Go's TerminalScreen owns a 0x0 window until the application resizes it
      # from its first WindowSizeEvent. Pre-sizing here painted an extra frame
      # that Go does not paint, and the app's own resize then repainted.
      @scr.resize(@buf.width, @buf.height)
      begin
        make_raw
      rescue ex
        restore
        raise ex
      end
      optimize_movements
      configure_renderer
      reset_tab_stops

      @running = true
      spawn { event_loop }
      start_input
      start_winch

      # Write the state the screen is in, then ask whether the terminal measures
      # cell width by grapheme cluster (DEC mode 2027), the way Go's
      # Terminal.Start does through TerminalScreen.Restore + Flush. The reply
      # reaches #handle_event through the event loop.
      set_alt_screen(true) if @state.altscreen?
      @scr.write_string(@state.cur_hidden? ? "\e[?25l" : "\e[?25h")
      # Go's TerminalScreen.Restore renders the (still 0x0) buffer before asking
      # about grapheme width. The cursor write that Flush makes afterwards is
      # queued behind everything else and only reaches the terminal with the
      # first frame, so it is taken as pending here rather than flushed.
      @scr.render(@buf)
      request_grapheme_width
      @scr.flush
      @pending_cursor = take_cursor_write
      @last_state = @state
    end

    def pause : Nil
      raise ErrNotRunning unless @running
      @running = false
      restore
    end

    def resume : Nil
      raise ErrRunning if @running
      @running = true
      make_raw
      optimize_movements
      configure_renderer
      start_input
      start_winch
      initialize_state
    end

    def stop : Nil
      # Stop is idempotent and safe before Start: there is nothing to restore
      # when the terminal was never running.
      return unless @running

      restore
      @running = false
    end

    def teardown : Nil
      stop if @running
      @evch.close
      @evs.close
      close_owned_tty
    end

    def wait(timeout : Time::Span? = nil) : Bool
      if timeout
        select
        when @evloop.receive
          true
        when timeout(timeout)
          false
        end
      else
        @evloop.receive
        true
      end
    end

    def shutdown(timeout : Time::Span) : Bool
      teardown
      wait(timeout)
    end

    def events : Channel(Event)
      @evs
    end

    def send_event(ev : Event) : Nil
      return if @evch.closed?
      @evch.send(ev)
    end

    # insert_above writes *content* above the current frame, scrolling the screen
    # up to make room, and leaves the cursor at the top. It mirrors Go's
    # TerminalScreen.InsertAbove (terminal_screen.go:817): relative moves from the
    # renderer's current position, one InsertLine for the whole block, then each
    # line followed by EraseLineRight.
    #
    # This is separate from the renderer's prepend queue: Go's examples call
    # InsertAbove for immediate output, and the renderer's prependString (with its
    # own ported specs) is a different path.
    def insert_above(content : String) : Nil
      return if content.empty?

      width = @buf.width
      height = @buf.height
      _x, y = @scr.position

      builder = String::Builder.new
      builder << '\r'
      down = height - y - 1
      builder << Ansi.cursor_down(down) if down > 0

      lines = content.split('\n')
      offset = lines.size
      lines.each do |line|
        line_width = @method.call(line)
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

      @scr.set_position(0, 0)
      @scr.write_string(builder.to_s)
      @scr.flush
    end

    def prepend_string(value : String) : Nil
      @prepend << value
    end

    def prepend_lines(*lines : Line) : Nil
      lines.each { |line| @prepend << line.render }
    end

    def write(bytes : Bytes) : Int32
      @scr.write(bytes)
    end

    def write_string(value : String) : Int32
      @scr.write_string(value)
    end

    def flush : Nil
      @scr.write(@pending_cursor) unless @pending_cursor.empty?
      @pending_cursor = Bytes.empty
      @scr.flush
      @pending_cursor = take_cursor_write
    end

    # take_cursor_write reproduces Go's TerminalScreen.Flush cursor handling and
    # takes its bytes out of the queue: an application-supplied position is moved
    # to, otherwise in inline mode a cursor left at the end of the line is moved
    # to column 0 of the same row (it can make some terminals wrap).
    #
    # Go writes both into the renderer's own buffer, which is only drained by the
    # next render, so the bytes belong to the next frame, not to this flush.
    private def take_cursor_write : Bytes
      mark = @scr.buffered
      state = @state
      if state.cur != Position.new(-1, -1)
        @scr.move_to(state.cur.x, state.cur.y)
      elsif !state.altscreen?
        x, y = @scr.position
        @scr.move_to(0, y) if x >= @buf.width - 1
      end
      @scr.take_buffered(mark)
    end

    def display : Nil
      state = @state
      if last = @last_state
        if last.altscreen? != state.altscreen?
          set_alt_screen(state.altscreen?)
        end
      elsif state.altscreen?
        set_alt_screen(true)
      end

      if last = @last_state
        if last.cur_hidden? != state.cur_hidden?
          @scr.write_string(state.cur_hidden? ? "\e[?25l" : "\e[?25h")
        end
      else
        @scr.write_string(state.cur_hidden? ? "\e[?25l" : "\e[?25h")
      end

      # A cursor write made while flushing the last frame waited in Go's
      # renderer buffer; put it back ahead of this frame so the bytes land in
      # the same place.
      @scr.write(@pending_cursor) unless @pending_cursor.empty?
      @pending_cursor = Bytes.empty

      @scr.render(@buf)

      if @prepend.size > 0
        @prepend.each { |line| prepend_line(line) }
        @prepend.clear
      end

      @scr.flush
      @pending_cursor = take_cursor_write
      @last_state = state
    end

    def erase : Nil
      @buf.touched = [] of LineData?
      @scr.erase
      clear
    end

    def buffered : Int32
      @scr.buffered
    end

    def touched : Int32
      @scr.touched(@buf)
    end

    def enter_alt_screen : Nil
      @state.altscreen = true
    end

    def exit_alt_screen : Nil
      @state.altscreen = false
    end

    def show_cursor : Nil
      @state.cur_hidden = false
    end

    def hide_cursor : Nil
      @state.cur_hidden = true
    end

    # reset_tab_stops makes the terminal's tab stops every 8 columns. When hard
    # tabs are used, the renderer computes tab positions from that spacing, so
    # the terminal has to agree. Go writes the same sequence from
    # TerminalScreen.Restore when resetTabs is set.
    private def reset_tab_stops : Nil
      @scr.write_string(Ansi::SetTabEvery8Columns) if @use_tabs
    end

    private def configure_renderer : Nil
      @scr.fullscreen = false
      @scr.relative_cursor = true
      @scr.color_profile = @profile
      if @use_tabs
        @scr.tab_stops = @size.width
      end
      @scr.backspace = @use_bspace
      @scr.logger = @logger
    end

    private def set_alt_screen(enable : Bool) : Nil
      if enable
        @scr.enter_alt_screen
      else
        @scr.exit_alt_screen
      end
    end

    private def prepend_line(line : String) : Nil
      str_lines = line.split("\n")
      str_lines.each_with_index do |str, i|
        str_lines[i] = Ansi.truncate(str, @size.width, "")
      end
      @scr.prepend_string(@buf, str_lines.join("\n"))
    end

    private def initialize_state : Nil
      if last = @last_state
        set_alt_screen(last.altscreen?)
        @scr.write_string(last.cur_hidden? ? "\e[?25l" : "\e[?25h")
        if last.cur != Position.new(-1, -1)
          move_to(last.cur.x, last.cur.y)
        end
      else
        set_alt_screen(true)
      end
      @scr.flush
    end

    # restore mirrors Go's `Terminal.Stop`, which resets the screen
    # (`TerminalScreen.Reset`) and flushes it: it undoes the state it queued
    # (alternate screen, cursor visibility, styles) and deliberately leaves the
    # application's frame on screen — it does not clear, and it does not reset
    # tab stops, which Go only ever writes from `Restore` at start.
    #
    # The state Reset undoes that this port tracks lives in `@state`; the rest
    # (mouse modes, bracketed paste, styles) belongs to [TerminalScreen], which
    # applications drive directly, so a [Terminal] never queued them.
    private def restore : Nil
      stop_winch
      stop_input
      set_alt_screen(false) if @state.altscreen?
      @scr.write_string("\e[?25h")
      # Go's Reset parks the cursor on the bottom row, but it does that through
      # the renderer's own buffer, which Stop never drains: the move is computed
      # and then dropped, and only the state writes above reach the terminal.
      # Take the move back out of the queue to keep the same bytes on the wire.
      mark = @scr.buffered
      bottom = @buf.height > 0 ? @buf.height - 1 : 0
      @scr.move_to(0, bottom)
      @scr.take_buffered(mark)
      @scr.flush
      @pending_cursor = Bytes.empty
      @scr.set_position(-1, -1)
      restore_tty
    end

    private def start_winch : Nil
      winch = @winch
      unless winch
        # No size notifier on this platform: still report the size once, the way
        # Go's Start does, so an app that paints from the first event has one.
        spawn { send_event(WindowSizeEvent.new(@size.width, @size.height)) }
        return
      end

      winch.start
      send_resize_event(force: true)

      stop = Channel(Nil).new(1)
      @winch_stop = stop
      spawn { winch_loop(winch, stop) }
    end

    private def stop_winch : Nil
      winch = @winch
      return unless winch
      winch.stop
      if stop = @winch_stop
        begin
          stop.send(nil)
        rescue Channel::ClosedError
        end
      end
      @winch_stop = nil
    end

    private def winch_loop(winch : SizeNotifier, stop : Channel(Nil)) : Nil
      loop do
        select
        when stop.receive
          break
        when winch.sig.receive
          break unless @running
          send_resize_event
        end
      end
    end

    # force reports the size even when it matches @size, which Start wants: Go
    # reports the initial size unconditionally.
    private def send_resize_event(force : Bool = false) : Nil
      if winch = @winch
        cells, pixels = window_sizes_from_winch(winch)
        debug_resize_event(cells, pixels)
        apply_resize_updates(cells, pixels, force)
        return
      end

      width, height = platform_size
      size = sanitize_size(width, height)
      if size != @size
        @evch.send(WindowSizeEvent.new(size.width, size.height))
        @size = size
      end
    end

    private def window_sizes_from_winch(winch : SizeNotifier) : {Size, Size}
      cells, pixels = winch.window_size
      {sanitize_size(cells.width, cells.height), sanitize_pixel_size(pixels)}
    rescue
      fallback_width, fallback_height = size_now
      {Size.new(fallback_width, fallback_height), Size.new(0, 0)}
    end

    private def sanitize_pixel_size(pixels : Size) : Size
      return pixels if pixels.width > 0 && pixels.height > 0 && pixels.width <= 10000 && pixels.height <= 10000
      Size.new(0, 0)
    end

    private def debug_resize_event(cells : Size, pixels : Size) : Nil
      return unless ENV["UV_DEBUG_EVENTS"]?
      STDERR.puts("uv: winch cells=#{cells.width}x#{cells.height} pixels=#{pixels.width}x#{pixels.height}")
    end

    private def apply_resize_updates(cells : Size, pixels : Size, force : Bool = false) : Nil
      if force || cells != @size
        @evch.send(WindowSizeEvent.new(cells.width, cells.height))
        @size = cells
      end
      if pixels.width > 0 && pixels.height > 0 && (force || pixels != @pixel_size)
        @evch.send(PixelSizeEvent.new(pixels.width, pixels.height))
        @pixel_size = pixels
      end
    end

    private def input_loop(reader : TerminalReader, stop : Channel(Nil), done : Channel(Nil)) : Nil
      # Hold a local reference for the loop's lifetime. stop_input clears
      # @reader, and a loop that read the field each iteration could evaluate it
      # after that has happened.
      STDERR.puts("uv: reader start") if ENV["UV_DEBUG_IO"]?
      reader.stream_events(@evch, stop)
    rescue ex
      STDERR.puts("uv: reader error #{ex.class}: #{ex.message}") if ENV["UV_DEBUG_IO"]?
      if logger = @logger
        logger.printf("terminal reader error: %s\n", ex.message)
      end
    ensure
      begin
        done.send(nil)
      rescue Channel::ClosedError
      end
    end

    private def start_input : Nil
      return if @reader

      # Go's Terminal.start builds a poll reader (terminal.go: `t.pr, err =
      # newPollReader(...)`). CancelReader's POSIX read wakes from EAGAIN with
      # `sleep 5.milliseconds`, so input latency and idle CPU are quantized by
      # that sleep; the poll readers suspend the fiber in Crystal's event loop
      # instead and still wake on cancel/close.
      poll_reader = Ultraviolet.new_poll_reader(@in)
      reader = TerminalReader.new(poll_reader, @termtype, @opts.legacy_key_encoding, @opts.use_terminfo_keys)
      reader.esc_timeout = @opts.event_timeout
      reader.buffer_size = @opts.buffer_size
      reader.lookup = @opts.lookup_keys
      reader.logger = @opts.logger if @opts.logger
      reader.logger = @logger
      @reader = reader
      @poll_reader = poll_reader

      stop = Channel(Nil).new(1)
      done = Channel(Nil).new(1)
      @reader_stop = stop
      @reader_done = done

      spawn { input_loop(reader, stop, done) }
    end

    private def stop_input : Nil
      stop = @reader_stop
      done = @reader_done
      poll_reader = @poll_reader
      @reader_stop = nil
      @reader_done = nil
      @reader = nil
      @poll_reader = nil

      # Cancel wakes a read blocked in the poll reader; the wait below lets the
      # reader fiber leave its loop before close releases the dup.
      poll_reader.try &.cancel
      if stop && done
        begin
          stop.send(nil)
        rescue Channel::ClosedError
        end
        select
        when done.receive
        when timeout(500.milliseconds)
        end
      end

      # Go's Stop cancels and then closes its poll reader (terminal.go). The
      # readers make close idempotent, so repeated restore/teardown is safe.
      begin
        poll_reader.try &.close
      rescue
      end
    end

    private def event_loop : Nil
      loop do
        event = @evch.receive?
        break unless event
        handle_event(event)
        case event
        when WindowSizeEvent
          @size = Size.new(event.width, event.height)
        when PixelSizeEvent
          @pixel_size = Size.new(event.width, event.height)
        end
        @evs.send(event)
      end
      @evloop.send(nil)
    end

    # handle_event reacts to internal events before they are forwarded to the
    # application, mirroring Go's Terminal.handleEvent. Unicode core mode (DEC
    # mode 2027) is enabled when the terminal reports it as settable or already
    # set; a terminal that does not recognize it keeps wcwidth measurement.
    private def handle_event(event : Event) : Nil
      return unless event.is_a?(ModeReportEvent)
      report = event.as(ModeReportEvent)
      return unless report.mode == Ansi::ModeUnicodeCore.value

      # Enable only for states where the terminal can honor the mode: set,
      # permanently set, or reset-but-settable. A terminal that does not
      # recognize it (or has it permanently reset) keeps wcwidth measurement.
      case report.value
      when Ansi::ModeSet.value.to_i32, Ansi::ModePermanentlySet.value.to_i32, Ansi::ModeReset.value.to_i32
        enable_grapheme_width
      end
    end

    private def env_int(key : String) : Int32?
      value, ok = @environ.lookup_env(key)
      return nil unless ok
      value.to_i?
    end

    private def sanitize_size(width : Int32, height : Int32) : Size
      if width <= 0 || height <= 0 || width > 1000 || height > 1000
        fallback_width, fallback_height = size_now
        return Size.new(fallback_width, fallback_height)
      end
      Size.new(width, height)
    end

    private def ensure_input_tty : Nil
      in_tty = @in_tty
      return if in_tty && in_tty.tty?

      out_tty = @out_tty
      return unless out_tty && out_tty.tty?

      in_tty, _ = Ultraviolet.open_tty
      @owned_tty = in_tty
      @in = in_tty
      @in_tty = in_tty.as?(IO::FileDescriptor)
      {% unless flag?(:win32) %}
        @winch = SizeNotifier.new(@in_tty || @out_tty)
      {% end %}
    end

    private def close_owned_tty : Nil
      if tty = @owned_tty
        begin
          tty.close
        rescue
        end
      end
      @owned_tty = nil
    end
  end

  # Go-compatible constructor alias for [Terminal.new].
  def self.new_terminal(console : Console, options : Options = Options.default) : Terminal
    Terminal.new(console, options)
  end
end
