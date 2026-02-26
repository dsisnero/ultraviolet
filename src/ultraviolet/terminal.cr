require "./terminal_renderer"
require "./buffer"
require "./event"
require "./environ"
require "./colorprofile"
require "./cancelreader"

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
    @profile : ColorProfile
    @use_tabs : Bool
    @use_bspace : Bool
    @state : TerminalState
    @last_state : TerminalState?
    @prepend : Array(String)
    @evs : Channel(Event)
    @evch : Channel(Event)
    @evloop : Channel(Nil)
    @winch : SizeNotifier?
    @winch_stop : Channel(Nil)?
    @reader : TerminalReader?
    @reader_stop : Channel(Nil)?
    @reader_done : Channel(Nil)?
    @cancel_reader : CancelReader?
    @logger : Logger?

    struct TerminalState
      property? altscreen : Bool
      property? cur_hidden : Bool
      property cur : Position

      def initialize(@altscreen : Bool = false, @cur_hidden : Bool = false, @cur : Position = Position.new(-1, -1))
      end
    end

    def self.default_terminal : Terminal
      Terminal.new(Console.default)
    end

    def self.controlling_terminal : Terminal
      Terminal.new(Console.controlling)
    end

    def initialize(console : Console)
      initialize(console.reader, console.writer, console.environ)
    end

    def initialize(@in : IO, @out : IO, env : Array(String) = [] of String)
      @environ = Environ.new(env)
      @termtype = @environ.getenv("TERM")
      @scr = TerminalRenderer.new(@out, env)
      @buf = RenderBuffer.new(0, 0)
      @method = DEFAULT_WIDTH_METHOD
      @profile = ColorProfile.detect(@out, env)
      @scr.color_profile = @profile
      @use_tabs = false
      @use_bspace = false
      @state = TerminalState.new
      @last_state = nil
      @prepend = [] of String
      @evs = Channel(Event).new
      @evch = Channel(Event).new
      @evloop = Channel(Nil).new(1)
      @winch_stop = nil
      @reader = nil
      @reader_stop = nil
      @reader_done = nil
      @cancel_reader = nil
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

    def width_method=(method : WidthMethod) : Nil
      @method = method
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

    def resize(width : Int32, height : Int32) : Nil
      @buf.resize(width, height)
      @buf.touched = Array(LineData?).new(height) { LineData.new(-1, -1) }
      @scr.resize(width, height)
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
        enter_alt_screen
        hide_cursor
        @state.cur = Position.new(-1, -1)
      end

      width, height = fetch_size
      @size = Size.new(width, height)
      if @buf.width == 0 && @buf.height == 0
        @buf.resize(@size.width, @size.height)
        @scr.erase
      end
      @scr.resize(@buf.width, @buf.height)
      begin
        make_raw
      rescue ex
        restore
        raise ex
      end
      optimize_movements
      configure_renderer

      @running = true
      spawn { event_loop }
      start_input
      start_winch
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
      raise ErrNotRunning unless @running
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
      @scr.flush
    end

    def display : Nil
      state = @state
      if last = @last_state
        if last.altscreen? != state.altscreen?
          set_alt_screen(state.altscreen?)
        end
      else
        set_alt_screen(state.altscreen?)
      end

      if last = @last_state
        if last.cur_hidden? != state.cur_hidden?
          @scr.write_string(state.cur_hidden? ? "\e[?25l" : "\e[?25h")
        end
      else
        @scr.write_string(state.cur_hidden? ? "\e[?25l" : "\e[?25h")
      end

      @scr.render(@buf)

      if @prepend.size > 0
        @prepend.each { |line| prepend_line(line) }
        @prepend.clear
      end

      if state.cur != Position.new(-1, -1)
        @scr.move_to(state.cur.x, state.cur.y)
      end

      @scr.flush
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

    def display : Nil
      @scr.render(@buf)
      @scr.flush
    end

    def flush : Nil
      @scr.flush
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

    private def configure_renderer : Nil
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

    private def restore : Nil
      stop_winch
      stop_input
      if last = @last_state
        if last.altscreen?
          set_alt_screen(false)
        else
          bottom = @buf.height > 0 ? @buf.height - 1 : 0
          @scr.move_to(0, bottom)
          @scr.write_string("\r\e[J")
        end
        @scr.write_string("\e[?25h") if last.cur_hidden?
      end
      @scr.flush
      @scr.set_position(-1, -1)
      restore_tty
    end

    private def restore_state : Nil
      stop_input
      # Wait for event loop to exit
      select
      when @evloop.receive
      when timeout(500.milliseconds)
      end
      if last = @last_state
        if last.altscreen?
          set_alt_screen(false)
        else
          bottom = @buf.height > 0 ? @buf.height - 1 : 0
          @scr.move_to(0, bottom)
          @scr.write_string("\r\e[J")
        end
        @scr.write_string("\e[?25h") if last.cur_hidden?
      end
      @scr.flush
      @scr.set_position(-1, -1)
    end

    private def start_winch : Nil
      winch = @winch
      return unless winch

      winch.start
      send_resize_event

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

    private def send_resize_event : Nil
      if winch = @winch
        cells, pixels = window_sizes_from_winch(winch)
        debug_resize_event(cells, pixels)
        apply_resize_updates(cells, pixels)
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

    private def apply_resize_updates(cells : Size, pixels : Size) : Nil
      if cells != @size
        @evch.send(WindowSizeEvent.new(cells.width, cells.height))
        @size = cells
      end
      if pixels.width > 0 && pixels.height > 0 && pixels != @pixel_size
        @evch.send(PixelSizeEvent.new(pixels.width, pixels.height))
        @pixel_size = pixels
      end
    end

    private def input_loop(reader : TerminalReader, stop : Channel(Nil), done : Channel(Nil)) : Nil
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

      cancel_reader = CancelReader.new(@in)
      reader = TerminalReader.new(cancel_reader, @termtype)
      reader.logger = @logger
      @reader = reader
      @cancel_reader = cancel_reader

      stop = Channel(Nil).new(1)
      done = Channel(Nil).new(1)
      @reader_stop = stop
      @reader_done = done

      spawn { input_loop(reader, stop, done) }
    end

    private def stop_input : Nil
      stop = @reader_stop
      done = @reader_done
      cancel_reader = @cancel_reader
      @reader_stop = nil
      @reader_done = nil
      @reader = nil
      @cancel_reader = nil
      return unless stop && done

      cancel_reader.try &.cancel
      begin
        stop.send(nil)
      rescue Channel::ClosedError
      end
      select
      when done.receive
      when timeout(500.milliseconds)
      end
    end

    private def event_loop : Nil
      loop do
        event = @evch.receive?
        break unless event
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
end
