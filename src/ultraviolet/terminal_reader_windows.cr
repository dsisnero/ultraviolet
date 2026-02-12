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

    # Windows Console API constants
    STD_INPUT_HANDLE              =    -10_i32
    ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200_u32
    ENABLE_WINDOW_INPUT           = 0x0008_u32
    ENABLE_EXTENDED_FLAGS         = 0x0080_u32

    # Input event types
    KEY_EVENT                = 0x0001_u16
    MOUSE_EVENT              = 0x0002_u16
    WINDOW_BUFFER_SIZE_EVENT = 0x0004_u16
    MENU_EVENT               = 0x0008_u16
    FOCUS_EVENT              = 0x0010_u16

    # Mouse button constants
    FROM_LEFT_1ST_BUTTON_PRESSED = 0x0001_u32
    FROM_LEFT_2ND_BUTTON_PRESSED = 0x0004_u32
    FROM_LEFT_3RD_BUTTON_PRESSED = 0x0008_u32
    FROM_LEFT_4TH_BUTTON_PRESSED = 0x0010_u32
    RIGHTMOST_BUTTON_PRESSED     = 0x0002_u32

    # Mouse event flags
    MOUSE_MOVED    = 0x0001_u32
    DOUBLE_CLICK   = 0x0002_u32
    MOUSE_WHEELED  = 0x0004_u32
    MOUSE_HWHEELED = 0x0008_u32

    # Control key states
    RIGHT_ALT_PRESSED  = 0x0001_u32
    LEFT_ALT_PRESSED   = 0x0002_u32
    RIGHT_CTRL_PRESSED = 0x0004_u32
    LEFT_CTRL_PRESSED  = 0x0008_u32
    SHIFT_PRESSED      = 0x0010_u32
    ENHANCED_KEY       = 0x0100_u32

    fun GetStdHandle(nStdHandle : DWORD) : HANDLE
    fun GetConsoleMode(hConsoleHandle : HANDLE, lpMode : DWORD*) : BOOL
    fun SetConsoleMode(hConsoleHandle : HANDLE, dwMode : DWORD) : BOOL
    fun ReadFile(hFile : HANDLE, lpBuffer : Void*, nNumberOfBytesToRead : DWORD, lpNumberOfBytesRead : DWORD*, lpOverlapped : Void*) : BOOL
    fun CancelIo(hFile : HANDLE) : BOOL
    fun CancelIoEx(hFile : HANDLE, lpOverlapped : Void*) : BOOL
    fun CloseHandle(hObject : HANDLE) : BOOL
    fun FlushConsoleInputBuffer(hConsoleInput : HANDLE) : BOOL
  end

  module Ultraviolet
    class TerminalReader
      # Windows-specific send_bytes implementation
      private def send_bytes(readc : Channel(Bytes), stop : Channel(Nil)?) : Nil
        # Check if reader is a Windows console handle
        if @reader.is_a?(IO::FileDescriptor) && console_handle?(@reader)
          # Use Windows Console API
          send_bytes_windows(readc, stop)
        else
          # Fall back to default implementation
          super
        end
      end

      private def send_bytes_windows(readc : Channel(Bytes), stop : Channel(Nil)?) : Nil
        handle = console_handle(@reader.as(IO::FileDescriptor))

        loop do
          break if stop && stop.closed?

          # For now, use simple ReadFile like default implementation
          # TODO: Implement proper console input recording with PeekConsoleInput/ReadConsoleInput
          buf = Bytes.new(4096)
          bytes_read = uninitialized LibC::DWORD
          if LibC.ReadFile(handle, buf.to_unsafe.as(Void*), buf.size.to_u32, pointerof(bytes_read), nil) == 0
            # Read error, break
            break
          end

          if bytes_read == 0
            # EOF
            break
          end

          readc.send(buf[0, bytes_read])
        end
      end

      private def console_handle?(tty : IO::FileDescriptor) : Bool
        handle = LibC::HANDLE.new(tty.fd)
        mode = uninitialized LibC::DWORD
        LibC.GetConsoleMode(handle, pointerof(mode)) != 0
      end

      private def console_handle(tty : IO::FileDescriptor) : LibC::HANDLE
        LibC::HANDLE.new(tty.fd)
      end
    end
  end
{% end %}
