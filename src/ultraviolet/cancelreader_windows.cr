{% if flag?(:win32) %}
  require "./win32_api"

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
      @cancel_event : LibC::HANDLE = LibC::HANDLE.null
      @event_lifetime = CancelEventLifetime.new
      @handle_mutex = Mutex.new

      def initialize(@conin : LibC::HANDLE)
        super(nil)
        # Store original console mode and set new mode
        modes = [
          LibC::ENABLE_VIRTUAL_TERMINAL_INPUT,
          LibC::ENABLE_WINDOW_INPUT,
          LibC::ENABLE_EXTENDED_FLAGS,
        ]
        @original_mode, @new_mode = prepare_console(@conin, *modes)

        # Manual-reset event: once signaled it stays signaled, so a reader that
        # starts waiting after Cancel/Close still wakes up.
        @cancel_event = LibC.CreateEventW(nil, 1, 0, nil)
        if @cancel_event == LibC::HANDLE.null
          LibC.SetConsoleMode(@conin, @original_mode)
          raise IO::Error.new("create cancel event")
        end

        # Flush any pending input
        if LibC.FlushConsoleInputBuffer(@conin) == 0
          # Non-fatal error
        end
      end

      # Signals the cancel event, then cancels pending console I/O. Safe to call
      # repeatedly and after close: the handle is only touched while the event
      # lifetime has not freed it.
      def cancel : Bool
        super
        @handle_mutex.synchronize do
          unless @cancel_event.null? || @event_lifetime.freed?
            LibC.SetEvent(@cancel_event)
          end
        end
        LibC.CancelIoEx(@conin, nil) != 0 || LibC.CancelIo(@conin) != 0
      end

      # Idempotent, and safe while a reader still waits: that reader takes
      # ownership of the event handle and frees it on its way out. Mirrors Go's
      # conInputReader.Close, which also leaves the console input handle alone.
      def close : Nil
        set_canceled

        free_now = @event_lifetime.close
        return if free_now.nil?

        errors = [] of String
        @handle_mutex.synchronize do
          # Wake a reader that may still wait; Close can be called without
          # Cancel and the reader only checks canceled? after waking.
          LibC.SetEvent(@cancel_event) unless @cancel_event.null?

          if @original_mode != 0
            if LibC.SetConsoleMode(@conin, @original_mode) == 0
              errors << "reset console mode"
            end
          end

          if free_now
            if LibC.CloseHandle(@cancel_event) == 0
              errors << "close cancel event"
            end
            @cancel_event = LibC::HANDLE.null
          end
        end

        raise IO::Error.new(errors.join("; ")) unless errors.empty?
      end

      # Blocks until the console has input or the reader is canceled or closed.
      # Returns immediately (raising CancelError) when the reader is already
      # closed. Mirrors Go's conInputReader.waitForInput.
      def wait_for_input : Nil
        raise CancelError.new("read canceled") unless @event_lifetime.acquire

        begin
          handles = [@conin, @cancel_event]
          LibC.WaitForMultipleObjects(2_u32, handles.to_unsafe, 0, LibC::INFINITE)
        ensure
          if @event_lifetime.release
            @handle_mutex.synchronize do
              LibC.CloseHandle(@cancel_event)
              @cancel_event = LibC::HANDLE.null
            end
          end
        end
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
