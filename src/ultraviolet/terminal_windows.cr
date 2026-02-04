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

  module Ultraviolet
    class Terminal
      DISABLE_NEWLINE_AUTO_RETURN = 0x0008_u32

      private def optimize_movements : Nil
        @use_tabs = true
        @use_bspace = true
      end

      private def make_raw : Nil
        raise ErrNotTerminal if @in_tty.nil? || @out_tty.nil?
        raise ErrNotTerminal unless console_handle?(@in_tty) && console_handle?(@out_tty)

        in_handle = console_handle(@in_tty)
        out_handle = console_handle(@out_tty)

        old_in_mode = uninitialized LibC::DWORD
        if LibC.GetConsoleMode(in_handle, pointerof(old_in_mode)) == 0
          raise IO::Error.from_winerror("GetConsoleMode")
        end
        @in_tty_state = old_in_mode

        new_in_mode = (old_in_mode | LibC::ENABLE_VIRTUAL_TERMINAL_INPUT) &
                      ~(LibC::ENABLE_PROCESSED_INPUT | LibC::ENABLE_LINE_INPUT | LibC::ENABLE_ECHO_INPUT)
        if LibC.SetConsoleMode(in_handle, new_in_mode) == 0
          raise IO::Error.from_winerror("SetConsoleMode")
        end

        old_out_mode = uninitialized LibC::DWORD
        if LibC.GetConsoleMode(out_handle, pointerof(old_out_mode)) == 0
          raise IO::Error.from_winerror("GetConsoleMode")
        end
        @out_tty_state = old_out_mode

        new_out_mode = old_out_mode | LibC::ENABLE_VIRTUAL_TERMINAL_PROCESSING | DISABLE_NEWLINE_AUTO_RETURN
        if LibC.SetConsoleMode(out_handle, new_out_mode) == 0
          raise IO::Error.from_winerror("SetConsoleMode")
        end
      end

      private def restore_tty : Nil
        if tty = @in_tty
          if state = @in_tty_state
            handle = console_handle(tty)
            LibC.SetConsoleMode(handle, state)
          end
        end

        if tty = @out_tty
          if state = @out_tty_state
            handle = console_handle(tty)
            LibC.SetConsoleMode(handle, state)
          end
        end
      end

      private def console_handle?(tty : IO::FileDescriptor) : Bool
        LibC.GetConsoleMode(console_handle(tty), out _) != 0
      end

      private def console_handle(tty : IO::FileDescriptor) : LibC::HANDLE
        LibC::HANDLE.new(tty.fd)
      end

      private def platform_size : {Int32, Int32}
        tty = @out_tty || @in_tty
        raise ErrNotTerminal unless tty

        info = uninitialized LibC::ConsoleScreenBufferInfo
        if LibC.GetConsoleScreenBufferInfo(console_handle(tty), pointerof(info)) == 0
          raise IO::Error.from_winerror("GetConsoleScreenBufferInfo")
        end

        width = info.srWindow.right.to_i - info.srWindow.left.to_i + 1
        height = info.srWindow.bottom.to_i - info.srWindow.top.to_i + 1
        {width, height}
      end
    end
  end
{% end %}
