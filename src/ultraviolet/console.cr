module Ultraviolet
  {% if flag?(:win32) %}
    require "c/consoleapi"

    lib LibC
      struct Coord
        x : Int16
        y : Int16
      end

      struct SmallRect
        left : Int16
        top : Int16
        right : Int16
        bottom : Int16
      end

      struct ConsoleScreenBufferInfo
        dwSize : Coord
        dwCursorPosition : Coord
        wAttributes : UInt16
        srWindow : SmallRect
        dwMaximumWindowSize : Coord
      end

      fun GetConsoleScreenBufferInfo(hConsoleOutput : HANDLE, lpConsoleScreenBufferInfo : ConsoleScreenBufferInfo*) : BOOL
    end
  {% end %}

  class Console
    getter input : IO
    getter output : IO
    getter environ : Array(String)

    @input_state : TtyState?
    @output_state : TtyState?

    def initialize(input : IO? = nil, output : IO? = nil, environ : Array(String)? = nil)
      @input = input || STDIN
      @output = output || STDOUT
      @environ = environ || ENV.map { |k, v| "#{k}=#{v}" }
      @input_state = nil
      @output_state = nil
    end

    def self.default : Console
      new_console(STDIN, STDOUT, ENV.map { |k, v| "#{k}=#{v}" })
    end

    def self.controlling : Console
      in_tty, out_tty = Ultraviolet.open_tty
      new_console(in_tty, out_tty, ENV.map { |k, v| "#{k}=#{v}" })
    end

    def self.new_console(input : IO? = nil, output : IO? = nil, environ : Array(String)? = nil) : Console
      in_io = input || STDIN
      out_io = output || STDOUT
      env = environ || ENV.map { |k, v| "#{k}=#{v}" }
      {% if flag?(:win32) %}
        WinCon.new(in_io, out_io, env)
      {% else %}
        TTY.new(in_io, out_io, env)
      {% end %}
    end

    def reader : IO
      @input
    end

    def writer : IO
      @output
    end

    def read(slice : Bytes) : Int32
      @input.read(slice)
    end

    def write(slice : Bytes) : Int32
      @output.write(slice)
      slice.size
    end

    def close : Nil
      restore
    end

    def getenv(key : String) : String
      value, _found = lookup_env(key)
      value
    end

    def lookup_env(key : String) : {String, Bool}
      Environ.new(@environ).lookup_env(key)
    end

    def make_raw : TtyState?
      in_state, out_state = make_raw_impl
      @input_state = in_state
      @output_state = out_state
      in_state || out_state
    end

    def restore : Nil
      restore_impl
      @input_state = nil
      @output_state = nil
    end

    def size : {Int32, Int32}
      ws = winsize
      {ws.col.to_i, ws.row.to_i}
    end

    def winsize : Winsize
      get_winsize_impl
    end

    # ameba:disable Naming/AccessorMethodName
    def get_size : {Int32, Int32}
      size
    end

    # ameba:enable Naming/AccessorMethodName

    # ameba:disable Naming/AccessorMethodName
    def get_winsize : Winsize
      winsize
    end

    # ameba:enable Naming/AccessorMethodName

    private def input_tty : IO::FileDescriptor?
      @input.as?(IO::FileDescriptor)
    end

    private def output_tty : IO::FileDescriptor?
      @output.as?(IO::FileDescriptor)
    end

    {% if flag?(:win32) %}
      private def console_handle(tty : IO::FileDescriptor) : LibC::HANDLE
        LibC::HANDLE.new(tty.fd)
      end

      private def console_handle?(tty : IO::FileDescriptor) : Bool
        LibC.GetConsoleMode(console_handle(tty), out _) != 0
      end

      private def make_raw_impl : {TtyState?, TtyState?}
        in_tty = input_tty
        out_tty = output_tty
        raise ErrNotTerminal if in_tty.nil? || out_tty.nil?
        raise ErrNotTerminal unless console_handle?(in_tty) && console_handle?(out_tty)

        in_handle = console_handle(in_tty)
        out_handle = console_handle(out_tty)

        old_in_mode = uninitialized LibC::DWORD
        if LibC.GetConsoleMode(in_handle, pointerof(old_in_mode)) == 0
          raise IO::Error.from_winerror("GetConsoleMode")
        end

        new_in_mode = (old_in_mode | LibC::ENABLE_VIRTUAL_TERMINAL_INPUT) &
                      ~(LibC::ENABLE_PROCESSED_INPUT | LibC::ENABLE_LINE_INPUT | LibC::ENABLE_ECHO_INPUT)
        if LibC.SetConsoleMode(in_handle, new_in_mode) == 0
          raise IO::Error.from_winerror("SetConsoleMode")
        end

        old_out_mode = uninitialized LibC::DWORD
        if LibC.GetConsoleMode(out_handle, pointerof(old_out_mode)) == 0
          raise IO::Error.from_winerror("GetConsoleMode")
        end

        new_out_mode = old_out_mode | LibC::ENABLE_VIRTUAL_TERMINAL_PROCESSING | 0x0008_u32
        if LibC.SetConsoleMode(out_handle, new_out_mode) == 0
          raise IO::Error.from_winerror("SetConsoleMode")
        end

        {old_in_mode, old_out_mode}
      end

      private def restore_impl : Nil
        if tty = input_tty
          if state = @input_state
            LibC.SetConsoleMode(console_handle(tty), state)
          end
        end

        if tty = output_tty
          if state = @output_state
            LibC.SetConsoleMode(console_handle(tty), state)
          end
        end
      end

      private def get_winsize_impl : Winsize
        tty = output_tty || input_tty
        raise ErrNotTerminal unless tty

        info = uninitialized LibC::ConsoleScreenBufferInfo
        if LibC.GetConsoleScreenBufferInfo(console_handle(tty), pointerof(info)) == 0
          raise IO::Error.from_winerror("GetConsoleScreenBufferInfo")
        end

        width = info.srWindow.right.to_i - info.srWindow.left.to_i + 1
        height = info.srWindow.bottom.to_i - info.srWindow.top.to_i + 1
        Winsize.new(row: height.to_u16, col: width.to_u16)
      end
    {% elsif flag?(:darwin) || flag?(:dragonfly) || flag?(:freebsd) || flag?(:linux) || flag?(:netbsd) || flag?(:openbsd) || flag?(:solaris) || flag?(:aix) %}
      private def make_raw_impl : {TtyState?, TtyState?}
        in_tty = input_tty
        out_tty = output_tty
        raise ErrNotTerminal if in_tty.nil? && out_tty.nil?

        last_error = nil.as(Exception?)
        {in_tty, out_tty}.each do |tty|
          next unless tty

          state = TtyState.new
          if LibC.tcgetattr(tty.fd, pointerof(state)) != 0
            last_error = IO::Error.from_errno("tcgetattr")
            next
          end

          raw_state = state
          LibC.cfmakeraw(pointerof(raw_state))
          if LibC.tcsetattr(tty.fd, LibC::TCSANOW, pointerof(raw_state)) != 0
            last_error = IO::Error.from_errno("tcsetattr")
            next
          end

          if tty == in_tty
            return {state, nil}
          end
          return {nil, state}
        end

        raise last_error if last_error
        raise ErrNotTerminal
      end

      private def restore_impl : Nil
        last_error = nil.as(Exception?)
        if tty = input_tty
          if state = @input_state
            tty_state = state.as(TtyState)
            if LibC.tcsetattr(tty.fd, LibC::TCSANOW, pointerof(tty_state)) != 0
              last_error = IO::Error.from_errno("tcsetattr")
            end
          end
        end

        if tty = output_tty
          if state = @output_state
            tty_state = state.as(TtyState)
            if LibC.tcsetattr(tty.fd, LibC::TCSANOW, pointerof(tty_state)) != 0
              last_error = IO::Error.from_errno("tcsetattr")
            end
          end
        end

        raise last_error if last_error
      end

      private def get_winsize_impl : Winsize
        err = ErrNotTerminal
        {input_tty, output_tty}.each do |tty|
          next unless tty

          ws = uninitialized LibC::Winsize
          if LibC.ioctl(tty.fd, TIOCGWINSZ, pointerof(ws).as(Void*)) == 0
            return Winsize.new(row: ws.ws_row, col: ws.ws_col, xpixel: ws.ws_xpixel, ypixel: ws.ws_ypixel)
          end
          err = IO::Error.from_errno("ioctl")
        end

        raise err
      end
    {% else %}
      private def make_raw_impl : {TtyState?, TtyState?}
        raise ErrPlatformNotSupported
      end

      private def restore_impl : Nil
      end

      private def get_winsize_impl : Winsize
        raise ErrPlatformNotSupported
      end
    {% end %}
  end

  class TTY < Console
  end

  class WinCon < Console
  end
end
