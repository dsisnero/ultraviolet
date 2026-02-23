{% if flag?(:linux) %}
  require "c/sys/epoll"
  require "c/sys/time"

  module Ultraviolet
    # EpollReader implements PollReader using the Linux epoll API.
    class EpollReader < PollReader
      @reader : IO
      @file : IO::FileDescriptor
      @cancel_signal_reader : IO::FileDescriptor
      @cancel_signal_writer : IO::FileDescriptor
      @epoll : Int32
      @mutex : Mutex
      @canceled : Bool

      # Creates a new EpollReader for the given IO.
      def initialize(reader : IO)
        @reader = reader
        @file = reader.as(IO::FileDescriptor)
        @mutex = Mutex.new
        @canceled = false

        # Create epoll
        @epoll = LibC.epoll_create1(0)
        if @epoll < 0
          raise IO::Error.from_errno("create epoll")
        end

        # Create pipe for cancel signal
        pipe_reader, pipe_writer = IO.pipe
        @cancel_signal_reader = pipe_reader.as(IO::FileDescriptor)
        @cancel_signal_writer = pipe_writer.as(IO::FileDescriptor)

        # Add file descriptor to epoll interest list
        event = LibC::EpollEvent.new
        event.events = LibC::EPOLLIN
        event.data.fd = @file.fd
        if LibC.epoll_ctl(@epoll, LibC::EPOLL_CTL_ADD, @file.fd, pointerof(event)) < 0
          LibC.close(@epoll)
          @cancel_signal_reader.close
          @cancel_signal_writer.close
          raise IO::Error.from_errno("add reader to epoll interest list")
        end

        # Add cancel signal pipe to epoll interest list
        cancel_event = LibC::EpollEvent.new
        cancel_event.events = LibC::EPOLLIN
        cancel_event.data.fd = @cancel_signal_reader.fd
        if LibC.epoll_ctl(@epoll, LibC::EPOLL_CTL_ADD, @cancel_signal_reader.fd, pointerof(cancel_event)) < 0
          LibC.close(@epoll)
          @cancel_signal_reader.close
          @cancel_signal_writer.close
          raise IO::Error.from_errno("add cancel signal to epoll interest list")
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

        events = uninitialized LibC::EpollEvent[1]

        timeout_ms = if timeout >= 0.seconds
                       timeout.total_milliseconds.to_i
                     else
                       -1
                     end

        loop do
          n = LibC.epoll_wait(@epoll, events.to_slice, 1, timeout_ms)
          if n < 0 && Errno.value == Errno::EINTR
            next # try again if interrupted
          elsif n < 0
            raise IO::Error.from_errno("epoll wait")
          elsif n == 0
            return false # timeout
          else
            break
          end
        end

        fd = events[0].data.fd
        case fd
        when @file.fd
          return true
        when @cancel_signal_reader.fd
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

        # close epoll
        if LibC.close(@epoll) < 0
          error_msgs << "closing epoll: #{Errno.value}"
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

    # Override new_poll_reader to use EpollReader on Linux platforms
    # with fallback to select for non-file descriptors.
    def self.new_poll_reader(reader : IO) : PollReader
      # Check if reader is a file descriptor
      if reader.is_a?(IO::FileDescriptor)
        begin
          return EpollReader.new(reader)
        rescue ex : IO::Error
          # If epoll creation fails, fall back to select
          return SelectReader.new(reader.as(IO::FileDescriptor))
        end
      else
        # Not a file descriptor, use fallback reader
        return FallbackReader.new(reader)
      end
    end
  end
{% end %}
