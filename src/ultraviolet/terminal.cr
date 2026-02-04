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
    @logger : Logger

    struct TerminalState
      property? altscreen : Bool
      property? cur_hidden : Bool
      property cur : Position

      def initialize(@altscreen : Bool = false, @cur_hidden : Bool = false, @cur : Position = Position.new(-1, -1))
      end
    end

    def self.default_terminal : Terminal
      Terminal.new(STDIN, STDOUT, ENV.to_a)
    end

    def initialize(@in : IO, @out : IO, env : Array(String) = [] of String)
      @environ = Environ.new(env)
      @termtype = @environ.getenv("TERM")
      @scr = TerminalRenderer.new(@out, env)
      @buf = RenderBuffer.new(0, 0)
      @method = DEFAULT_WIDTH_METHOD
      @profile = ColorProfile::TrueColor
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
      @running = false
      @size = Size.new(0, 0)
      @pixel_size = Size.new(0, 0)
      @logger = Logger.new
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

    def logger=(logger : Logger) : Nil
      @logger = logger
    end

    def color_profile : ColorProfile
      @profile
    end

    def color_profile=(profile : ColorProfile) : Nil
      @profile = profile
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

    def size_now : {Int32, Int32}
      cols = env_int("COLUMNS")
      rows = env_int("LINES")
      width = cols || 80
      height = rows || 24
      {width, height}
    end

    def fetch_size : {Int32, Int32}
      width, height = platform_size
      @size = Size.new(width, height)
      {width, height}
    end

    def size : Size
      @size
    end

    def resize(width : Int32, height : Int32) : Nil
      @buf.touched = nil
      @buf.resize(width, height)
      @scr.resize(width, height)
    end

    def start : Nil
      raise ErrRunning if @running

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
        @prepend.each { |line| @scr.prepend_string(@buf, line) }
        @prepend.clear
      end

      if state.cur != Position.new(-1, -1)
        @scr.move_to(state.cur.x, state.cur.y)
      end

      @scr.flush
      @last_state = state
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
      @winch_stop.try &.try_send(nil)
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
        cells, pixels = winch.window_size
        @evch.send(WindowSizeEvent.new(cells.width, cells.height))
        if pixels.width > 0 && pixels.height > 0
          @evch.send(PixelSizeEvent.new(pixels.width, pixels.height))
        end
      else
        width, height = platform_size
        @evch.send(WindowSizeEvent.new(width, height))
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

      spawn do
        begin
          reader.stream_events(@evch, stop)
        rescue ex
          @logger.printf("terminal reader error: %s\n", ex.message) if @logger
        ensure
          done.try_send(nil)
        end
      end
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
      stop.try_send(nil)
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
          @size = event
        when PixelSizeEvent
          @pixel_size = event
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
  end
end
