require "./terminal_screen"
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

  # Terminal is a thin facade over a [TerminalScreen], the way Go's `Terminal`
  # is a facade over `t.scr`. Every piece of screen state — alternate screen,
  # cursor, mouse mode and encoding, bracketed paste, keyboard enhancements,
  # colors, progress bar, program status, window title, synchronized updates,
  # tab stops — lives on the screen, so stopping the terminal undoes it without
  # this class tracking a second copy. The drawing helpers are delegations to
  # the screen's own window, so `examples/` and dependents keep their surface.
  #
  # Terminal owns what is not screen state: the console fds, the input poll
  # reader and its event loop, the window-size notifier, the raw-mode state, and
  # the terminal size.
  class Terminal
    include Screen

    getter environ : Environ
    getter termtype : String
    getter size : Size
    getter pixel_size : Size
    getter? running : Bool
    getter screen : TerminalScreen

    @in : IO
    @out : IO
    @in_tty : IO::FileDescriptor?
    @out_tty : IO::FileDescriptor?
    @in_tty_state : TtyState?
    @out_tty_state : TtyState?
    @use_tabs : Bool
    @use_bspace : Bool
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
      # Like Go's `NewTerminal`, the screen is built on the console's writer.
      # The renderer writes into the screen's queue, not the terminal, so a
      # cursor move made while flushing a frame reaches the terminal with the
      # next frame. See [TerminalScreen#flush].
      @screen = TerminalScreen.new(@out, env)
      @use_tabs = false
      @use_bspace = false
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

    def logger : Logger?
      @logger
    end

    def logger=(logger : Logger?) : Nil
      @logger = logger
      @screen.logger = logger
    end

    def color_profile : ColorProfile
      @screen.color_profile
    end

    def color_profile=(profile : ColorProfile) : Nil
      @screen.color_profile = profile
    end

    def color_model : ColorProfile
      @screen.color_profile
    end

    def convert(color : Color) : Color
      ColorProfileUtil.convert(@screen.color_profile, color)
    end

    def width_method : WidthMethod
      @screen.width_method
    end

    # width_method= pins an explicit measurement choice: a later Unicode core
    # negotiation leaves it alone, and the renderer measures the same way.
    def width_method=(method : WidthMethod) : Nil
      @screen.width_method = method
    end

    # request_grapheme_width asks the terminal whether it measures width by
    # grapheme cluster (DECRQM for Unicode core mode, DEC mode 2027).
    def request_grapheme_width : Nil
      @screen.request_grapheme_width
    end

    # enable_grapheme_width turns Unicode core mode on and measures by grapheme
    # cluster, so what this port draws matches what the terminal paints. An
    # explicit width method wins.
    def enable_grapheme_width : Nil
      @screen.enable_grapheme_width
    end

    def bounds : Rectangle
      @screen.bounds
    end

    def width : Int32
      @screen.width
    end

    def height : Int32
      @screen.height
    end

    def string_width(str : String) : Int32
      @screen.string_width(str)
    end

    def cell_at(x : Int32, y : Int32) : Cell?
      @screen.cell_at(x, y)
    end

    def set_cell(x : Int32, y : Int32, cell : Cell?) : Nil
      @screen.set_cell(x, y, cell)
    end

    def clear : Nil
      @screen.clear
    end

    def clear_area(area : Rectangle) : Nil
      @screen.clear_area(area)
    end

    def fill(cell : Cell?) : Nil
      @screen.fill(cell)
    end

    def fill_area(cell : Cell?, area : Rectangle) : Nil
      @screen.fill_area(cell, area)
    end

    def clone : Buffer
      @screen.clone
    end

    def clone_area(area : Rectangle) : Buffer?
      @screen.clone_area(area)
    end

    # position and set_position are the renderer's pen. Go's terminal facade has
    # no equivalent; the screen exposes them for parity with the renderer.
    def position : {Int32, Int32}
      @screen.position
    end

    def set_position(x : Int32, y : Int32) : Nil
      @screen.set_position(x, y)
    end

    # move_to asks for the cursor to be at (x, y) after the next flush, the way
    # Go's `TerminalScreen.SetCursorPosition` does.
    def move_to(x : Int32, y : Int32) : Nil
      @screen.set_cursor_position(x, y)
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
        # Note: In Go, there are type switches for interfaces with Height() and
        # Bounds() methods. In Crystal, we would need to define those interfaces
        # separately.
      end

      if frame_height != frame_area.dy
        frame_area = Ultraviolet.rect(frame_area.min.x, frame_area.min.y, frame_area.dx, frame_height)
      end

      # Resize the screen's window to match the frame area. The renderer keeps
      # its own size, which #resize updates from the terminal.
      @screen.buffer.resize(frame_area.dx, frame_height)

      # Clear our screen buffer before copying the new frame into it
      @screen.clear
      d.draw(self, @screen.bounds) unless d.nil?

      # If the frame height is greater than the screen height, we drop the
      # lines from the top of the buffer.
      if frame_height > @size.height
        @screen.buffer.lines = @screen.buffer.lines[frame_height - @size.height..]
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
      @screen.resize(width, height)
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

      width, height = fetch_size
      @size = Size.new(width, height)
      begin
        make_raw
      rescue ex
        restore_tty
        raise ex
      end
      optimize_movements
      @screen.configure_movements(@use_tabs, @use_bspace)

      @running = true
      spawn { event_loop }
      start_input
      start_winch

      # Go's Terminal.Start restores the screen state, asks whether the terminal
      # measures cell width by grapheme cluster (DEC mode 2027), then flushes.
      # The screen starts inline with a hidden cursor, so an application that
      # never entered the alternate screen emits no alt-screen sequence.
      @screen.restore
      @screen.request_grapheme_width
      @screen.flush
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
      @screen.configure_movements(@use_tabs, @use_bspace)
      start_input
      start_winch
      # The screen still holds the state the application set before Pause, so
      # restoring it re-emits mouse modes, paste mode and the rest, as Go's
      # Stop-then-Start cycle does.
      @screen.restore
      @screen.request_grapheme_width
      @screen.flush
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
    # up to make room, and leaves the cursor at the top. See
    # [TerminalScreen#insert_above].
    def insert_above(content : String) : Nil
      @screen.insert_above(content)
    end

    def prepend_string(value : String) : Nil
      @prepend << value
    end

    def prepend_lines(*lines : Line) : Nil
      lines.each { |line| @prepend << line.render }
    end

    def write(bytes : Bytes) : Int32
      @screen.write(bytes)
    end

    def write_string(value : String) : Int32
      @screen.write_string(value)
    end

    # flush writes everything the screen has queued. Go's `TerminalScreen.Flush`
    # assumes a Render already drained the renderer into the queue; this facade
    # has always drained it too, so bytes buffered by the renderer alone (a
    # kitty image transfer, for instance) reach the terminal here.
    def flush : Nil
      @screen.drain_renderer
      @screen.flush
    end

    def display : Nil
      # Render drains the renderer into the screen's queue. Prepend lines queue
      # into the renderer, which #flush leaves for the next render — that is
      # where Go puts the cursor write a frame makes, so the frame's own bytes go
      # out first.
      @screen.render
      if @prepend.size > 0
        @prepend.each { |line| prepend_line(line) }
        @prepend.clear
      end
      @screen.flush
    end

    def erase : Nil
      @screen.erase
    end

    def buffered : Int32
      @screen.buffered
    end

    def touched : Int32
      @screen.touched
    end

    def enter_alt_screen : Nil
      @screen.enter_alt_screen
    end

    def exit_alt_screen : Nil
      @screen.exit_alt_screen
    end

    def alt_screen? : Bool
      @screen.alt_screen?
    end

    def show_cursor : Nil
      @screen.show_cursor
    end

    def hide_cursor : Nil
      @screen.hide_cursor
    end

    def cursor_visible? : Bool
      @screen.cursor_visible?
    end

    def set_mouse_mode(mode : MouseMode) : Nil
      @screen.set_mouse_mode(mode)
    end

    def mouse_mode : MouseMode
      @screen.mouse_mode
    end

    def set_mouse_encoding(encoding : MouseEncoding) : Nil
      @screen.set_mouse_encoding(encoding)
    end

    def mouse_encoding : MouseEncoding
      @screen.mouse_encoding
    end

    def enable_bracketed_paste : Nil
      @screen.enable_bracketed_paste
    end

    def disable_bracketed_paste : Nil
      @screen.disable_bracketed_paste
    end

    def bracketed_paste? : Bool
      @screen.bracketed_paste?
    end

    def set_window_title(title : String) : Nil
      @screen.set_window_title(title)
    end

    def set_program_status(status : ProgramStatus?) : Nil
      @screen.set_program_status(status)
    end

    def set_progress_bar(progress : ProgressBar?) : Nil
      @screen.set_progress_bar(progress)
    end

    def set_keyboard_enhancements(enhancements : KeyboardEnhancements?) : Nil
      @screen.set_keyboard_enhancements(enhancements)
    end

    def set_synchronized_updates(enabled : Bool) : Nil
      @screen.set_synchronized_updates(enabled)
    end

    private def prepend_line(line : String) : Nil
      str_lines = line.split("\n")
      str_lines.each_with_index do |str, i|
        str_lines[i] = Ansi.truncate(str, @size.width, "")
      end
      @screen.prepend_string(str_lines.join("\n"))
    end

    # restore mirrors Go's `Terminal.Stop`: reset the screen (`Reset`) and flush
    # it, then restore the console. Reset undoes everything the screen tracked —
    # alternate screen, cursor, mouse modes and encoding, bracketed paste,
    # keyboard enhancements, colors, title, progress bar — and deliberately
    # leaves the application's frame and the program status on screen.
    private def restore : Nil
      stop_winch
      stop_input
      @screen.reset
      @screen.flush
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
