{% if flag?(:win32) %}
  require "c/consoleapi"

  module Ultraviolet
    # ConReader implements pollReader using Windows Console API and
    # WaitForMultipleObjects for cancelable polling.
    class ConReader < PollReader
      @reader : IO
      @conin : LibC::HANDLE
      @cancel_event : LibC::HANDLE
      @blocking_read_signal : Channel(Nil)
      @reset_console : -> Nil
      @mutex : Mutex
      @canceled : Bool

      def initialize(@reader : IO)
        @mutex = Mutex.new
        @canceled = false
        @blocking_read_signal = Channel(Nil).new(1)
        @conin = LibC::HANDLE.null
        @cancel_event = LibC::HANDLE.null
        @reset_console = -> { }

        # Check if reader is stdin and a console
        if reader.is_a?(IO::FileDescriptor) && reader.fd == STDIN.fd
          # Try to open CONIN$ in overlapped mode
          conin_path = to_utf16("CONIN$")
          @conin = LibC.CreateFileW(
            conin_path.to_unsafe.as(UInt16*),
            LibC::GENERIC_READ | LibC::GENERIC_WRITE,
            LibC::FILE_SHARE_READ | LibC::FILE_SHARE_WRITE | LibC::FILE_SHARE_DELETE,
            nil,
            LibC::OPEN_EXISTING,
            LibC::FILE_FLAG_OVERLAPPED,
            LibC::HANDLE.null
          )
          if @conin == LibC::INVALID_HANDLE_VALUE
            # Cannot open CONIN$ in overlapped mode, raise to fall back to generic poll reader
            raise IO::Error.new("open CONIN$ in overlapping mode")
          end

          # Prepare console mode
          @reset_console = prepare_poll_console(@conin)

          # Flush input buffer
          LibC.FlushConsoleInputBuffer(@conin)

          # Create cancel event
          @cancel_event = LibC.CreateEventW(nil, 0, 0, nil)
          if @cancel_event == LibC::HANDLE.null
            LibC.CloseHandle(@conin)
            @conin = LibC::HANDLE.null
            @reset_console.call
            raise IO::Error.new("create cancel event")
          end
        else
          # Not a console stdin - should not happen
          raise IO::Error.new("not a console stdin")
        end
      end

      def read(slice : Bytes) : Int32
        raise PollCanceledError.new("poll canceled") if canceled?
        begin
          @reader.read(slice)
        rescue ex
          raise PollCanceledError.new("poll canceled") if canceled?
          raise ex
        end
      end

      def poll(timeout : Time::Span) : Bool
        raise PollCanceledError.new("poll canceled") if canceled?

        timeout_ms = timeout < 0.seconds ? LibC::INFINITE : timeout.total_milliseconds.to_u32

        handles = [@conin, @cancel_event]
        event = LibC.WaitForMultipleObjects(handles.size.to_u32, handles.to_unsafe.as(LibC::HANDLE*), 0, timeout_ms)

        case event
        when LibC::WAIT_OBJECT_0
          # Console input available
          true
        when LibC::WAIT_OBJECT_0 + 1
          # Cancel event signaled
          raise PollCanceledError.new("poll canceled")
        when LibC::WAIT_ABANDONED...LibC::WAIT_ABANDONED + 2
          raise IO::Error.new("abandoned")
        when LibC::WAIT_TIMEOUT
          false
        when LibC::WAIT_FAILED
          raise IO::Error.new("failed")
        else
          raise IO::Error.new("unexpected error")
        end
      end

      def cancel : Bool
        @mutex.synchronize do
          return false if @canceled
          @canceled = true
        end

        # On Windows Terminal, WaitForMultipleObjects sometimes immediately returns
        # without input being available. In this case, graceful cancelation is not
        # possible and Cancel() returns false.
        select
        when @blocking_read_signal.send(nil)
          if !@cancel_event.null?
            LibC.SetEvent(@cancel_event)
          end
          @blocking_read_signal.receive
        else
          timeout(100.milliseconds)
          # Read() hangs in a GetOverlappedResult which is likely due to
          # WaitForMultipleObjects returning without input being available
          # so we cannot cancel this ongoing read.
          return false
        end

        true
      end

      def close : Nil
        if !@cancel_event.null?
          LibC.CloseHandle(@cancel_event)
          @cancel_event = LibC::HANDLE.null
        end

        if !@conin.null?
          @reset_console.call if @reset_console
          LibC.CloseHandle(@conin)
          @conin = LibC::HANDLE.null
        end
      end

      private def canceled? : Bool
        @mutex.synchronize { @canceled }
      end

      private def prepare_poll_console(input : LibC::HANDLE) : -> Nil
        original_mode = uninitialized LibC::DWORD
        if LibC.GetConsoleMode(input, pointerof(original_mode)) == 0
          return -> { }
        end

        new_mode = original_mode
        new_mode &= ~(LibC::ENABLE_ECHO_INPUT | LibC::ENABLE_LINE_INPUT | LibC::ENABLE_MOUSE_INPUT | LibC::ENABLE_PROCESSED_INPUT)
        new_mode |= LibC::ENABLE_EXTENDED_FLAGS | LibC::ENABLE_INSERT_MODE | LibC::ENABLE_QUICK_EDIT_MODE | LibC::ENABLE_WINDOW_INPUT
        new_mode |= LibC::ENABLE_VIRTUAL_TERMINAL_INPUT

        if LibC.SetConsoleMode(input, new_mode) == 0
          return -> { }
        end

        -> {
          LibC.SetConsoleMode(input, original_mode)
        }
      end

      private def to_utf16(string : String) : Slice(UInt16)
        # Simple ASCII to UTF-16LE conversion (sufficient for "CONIN$")
        slice = Slice(UInt16).new(string.bytesize + 1)
        string.each_char_with_index do |char, i|
          slice[i] = char.ord.to_u16
        end
        slice[string.size] = 0_u16
        slice
      end
    end

    # Override new_poll_reader to use ConReader on Windows for console stdin
    def self.new_poll_reader(reader : IO) : PollReader
      # Check if reader is stdin (console)
      if reader.is_a?(IO::FileDescriptor) && reader.fd == STDIN.fd
        # Try to create ConReader; if fails, fall back to generic poll reader
        begin
          return ConReader.new(reader)
        rescue ex : IO::Error
          # fall through to generic poll reader
        end
      end

      # Use generic poll reader (SelectReader or FallbackReader)
      if reader.is_a?(IO::FileDescriptor)
        SelectReader.new(reader)
      else
        FallbackReader.new(reader)
      end
    end
  end
{% end %}
