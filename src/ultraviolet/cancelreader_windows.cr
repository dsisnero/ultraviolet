{% if flag?(:win32) %}
  require "c/consoleapi"

  lib LibC
    STD_INPUT_HANDLE = -10_i32

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
    private def prepare_console(input : LibC::HANDLE, *modes : UInt32) : Tuple(UInt32, UInt32)
      original_mode = uninitialized LibC::DWORD
      if LibC.GetConsoleMode(input, pointerof(original_mode)) == 0
        raise IO::Error.from_winerror("GetConsoleMode")
      end

      new_mode = original_mode
      modes.each do |mode|
        new_mode |= mode
      end

      if LibC.SetConsoleMode(input, new_mode) == 0
        raise IO::Error.from_winerror("SetConsoleMode")
      end

      {original_mode, new_mode}
    end

    class ConInputReader < CancelReader
      @conin : LibC::HANDLE
      @original_mode : UInt32 = 0
      @new_mode : UInt32 = 0

      def initialize(@conin : LibC::HANDLE)
        super(nil)
        # Store original console mode and set new mode
        modes = [
          LibC::ENABLE_VIRTUAL_TERMINAL_INPUT,
          LibC::ENABLE_WINDOW_INPUT,
          LibC::ENABLE_EXTENDED_FLAGS,
        ]
        @original_mode, @new_mode = prepare_console(@conin, *modes)

        # Flush any pending input
        if LibC.FlushConsoleInputBuffer(@conin) == 0
          # Non-fatal error
        end
      end

      def cancel : Bool
        super
        # Cancel I/O operations
        LibC.CancelIoEx(@conin, nil) != 0 || LibC.CancelIo(@conin) != 0
      end

      def close : Nil
        if @original_mode != 0
          LibC.SetConsoleMode(@conin, @original_mode)
        end
        LibC.CloseHandle(@conin)
        super
      end

      def read(slice : Bytes) : Int32
        return 0 if canceled?

        bytes_read = uninitialized LibC::DWORD
        if LibC.ReadFile(@conin, slice.to_unsafe.as(Void*), slice.size.to_u32, pointerof(bytes_read), nil) == 0
          return 0
        end
        bytes_read.to_i
      end
    end

    class CancelReader
      def self.new(io : IO) : CancelReader
        # Check if this is stdin and a console
        if io.is_a?(IO::FileDescriptor) && io.fd == STDIN.fd
          # Try to create Windows console reader
          handle = LibC.GetStdHandle(LibC::STD_INPUT_HANDLE)
          if handle != LibC::INVALID_HANDLE_VALUE
            mode = uninitialized LibC::DWORD
            if LibC.GetConsoleMode(handle, pointerof(mode)) != 0
              # It's a console, use ConInputReader
              return ConInputReader.new(handle)
            end
          end
        end
        # Fall back to generic implementation
        super
      end
    end
  end
{% end %}
