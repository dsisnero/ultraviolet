{% if flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) || flag?(:dragonfly) %}
  require "c/sys/event"
  require "c/sys/time"

  module Ultraviolet
    # Helper to set kevent struct fields (similar to BSD's EV_SET macro)
    def self.ev_set(kevent : LibC::Kevent*, ident : UInt64, filter : Int16, flags : UInt16, fflags : UInt32, data : Int64, udata : Void*)
      kevent.value.ident = ident
      kevent.value.filter = filter
      kevent.value.flags = flags
      kevent.value.fflags = fflags
      kevent.value.data = data
      kevent.value.udata = udata
    end

    # KqueueReader implements PollReader using the BSD kqueue API.
    class KqueueReader < PollReader
      @reader : IO
      @file : IO::FileDescriptor?
      @cancel_signal_reader : IO::FileDescriptor
      @cancel_signal_writer : IO::FileDescriptor
      @kqueue : Int32
      @kqueue_events : StaticArray(LibC::Kevent, 2)
      @mutex : Mutex
      @canceled : Bool

      # Creates a new KqueueReader for the given IO.
      def initialize(reader : IO)
        @reader = reader
        @file = reader.is_a?(IO::FileDescriptor) ? reader.as(IO::FileDescriptor) : nil
        @mutex = Mutex.new
        @canceled = false
        @kqueue_events = uninitialized StaticArray(LibC::Kevent, 2)

        # Create kqueue
        @kqueue = LibC.kqueue
        if @kqueue < 0
          raise IO::Error.from_errno("create kqueue")
        end

        # Create pipe for cancel signal
        pipe_reader, pipe_writer = IO.pipe
        @cancel_signal_reader = pipe_reader.as(IO::FileDescriptor)
        @cancel_signal_writer = pipe_writer.as(IO::FileDescriptor)

        # Set up kqueue events
        events_ptr = @kqueue_events.to_unsafe
        fd = @file.not_nil!.fd
        Ultraviolet.ev_set(events_ptr, fd.to_u64, LibC::EVFILT_READ, LibC::EV_ADD, 0_u32, 0_i64, Pointer(Void).null)

        cancel_fd = @cancel_signal_reader.fd
        Ultraviolet.ev_set(events_ptr + 1, cancel_fd.to_u64, LibC::EVFILT_READ, LibC::EV_ADD, 0_u32, 0_i64, Pointer(Void).null)
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

        events = uninitialized LibC::Kevent[1]

        timeout_ptr = if timeout >= 0.seconds
                        ts = LibC::Timespec.new
                        ts.tv_sec = timeout.seconds.to_i64
                        # Calculate remaining nanoseconds after whole seconds
                        ts.tv_nsec = (timeout - timeout.seconds.seconds).nanoseconds.to_i64
                        pointerof(ts)
                      else
                        Pointer(LibC::Timespec).null
                      end

        loop do
          n = LibC.kevent(@kqueue, @kqueue_events.to_slice, @kqueue_events.size, events.to_slice, 1, timeout_ptr)
          if n < 0 && Errno.value == Errno::EINTR
            next # try again if interrupted
          elsif n < 0
            raise IO::Error.from_errno("kevent")
          elsif n == 0
            return false # timeout
          else
            break
          end
        end

        ident = events[0].ident
        case ident
        when @file.try(&.fd).to_u64
          return true
        when @cancel_signal_reader.fd.to_u64
          # remove signal from pipe
          buf = uninitialized UInt8[1]
          begin
            @cancel_signal_reader.read(buf.to_slice)
          rescue ex
            raise IO::Error.new("reading cancel signal: #{ex.message}")
          end
          raise PollCanceledError.new("poll canceled")
        else
          raise IO::Error.new("unknown error")
        end
      end

      def cancel : Bool
        @mutex.synchronize do
          return false if @canceled
          @canceled = true
        end

        # send cancel signal
        begin
          @cancel_signal_writer.write_bytes('c'.ord.to_u8)
        rescue
          return false
        end
        true
      end

      def close : Nil
        error_msgs = [] of String

        # close kqueue
        if LibC.close(@kqueue) < 0
          error_msgs << "closing kqueue: #{Errno.value}"
        end

        # close pipe
        begin
          @cancel_signal_writer.close
        rescue ex
          error_msgs << "closing cancel signal writer: #{ex.message}"
        end

        begin
          @cancel_signal_reader.close
        rescue ex
          error_msgs << "closing cancel signal reader: #{ex.message}"
        end

        if error_msgs.size > 0
          raise IO::Error.new(error_msgs.join(", "))
        end
      end

      private def canceled? : Bool
        @mutex.synchronize { @canceled }
      end
    end

    # Override new_poll_reader to use KqueueReader on BSD platforms
    # with fallback to select for /dev/tty and generic fallback for non-files.
    def self.new_poll_reader(reader : IO) : PollReader
      # Check if reader is a file descriptor
      if reader.is_a?(IO::FileDescriptor)
        file = reader.as(IO::FileDescriptor)
        # kqueue returns instantly when polling /dev/tty so fallback to select
        # We fallback to select for any TTY since we can't easily check if it's /dev/tty
        if file.tty?
          return SelectReader.new(file)
        end

        # Try to create kqueue reader
        begin
          return KqueueReader.new(reader)
        rescue ex : IO::Error
          # If kqueue creation fails, fall back to select
          return SelectReader.new(file)
        end
      else
        # Not a file descriptor, use fallback reader
        return FallbackReader.new(reader)
      end
    end
  end
{% end %}
