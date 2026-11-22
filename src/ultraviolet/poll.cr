{% unless flag?(:win32) %}
  require "c/unistd"

  lib LibC
    # The one binding the poll readers still need: the stdlib has no `dup`, and
    # the readers must not close the caller's descriptor when they cancel.
    fun dup(fd : Int32) : Int32
  end
{% end %}

module Ultraviolet
  class PollCanceledError < Exception
  end

  # Read-only IO for poll readers.
  #
  # Include this *after* `IO::Buffered`: the mixin defines `write`, and a module
  # included later sits closer in the lookup chain than one included earlier, so
  # this has to come second to win. A poll reader never writes, and buffering a
  # write that can never be flushed would hide the mistake.
  module ReadOnlyPollReader
    def write(slice : Bytes) : Nil
      raise IO::Error.new("poll reader is read-only")
    end

    def unbuffered_write(slice : Bytes) : Nil
      raise IO::Error.new("poll reader is read-only")
    end

    def unbuffered_flush : Nil
    end
  end

  # PollReader is a cancelable reader over an input stream.
  #
  # Under Crystal's cooperative scheduler a blocking syscall inside a fiber
  # stalls the scheduler thread: a raw select()/epoll_wait()/read() makes
  # `cancel` impossible to observe (measured: a fiber parked in a raw select()
  # freezes the main fiber). Poll readers therefore go through Crystal's event
  # loop, which suspends the fiber instead of the thread, and cancel/close wake
  # a parked fiber by closing its read handle.
  abstract class PollReader < IO
    abstract def read(slice : Bytes) : Int32
    abstract def poll(timeout : Time::Span) : Bool
    abstract def cancel : Bool
    abstract def close : Nil

    def write(slice : Bytes) : Nil
      raise IO::Error.new("poll reader is read-only")
    end

    def flush : Nil
    end
  end

  # new_poll_reader creates a poll reader for the given IO.
  #
  # Platforms with their own poll reader override this (poll_linux.cr,
  # poll_bsd.cr, poll_windows.cr).
  def self.new_poll_reader(reader : IO) : PollReader
    {% if flag?(:win32) %}
      # No file-descriptor polling on Windows; the fallback reader is channel
      # based.
      FallbackReader.new(reader)
    {% else %}
      if reader.is_a?(IO::FileDescriptor)
        SelectReader.new(reader)
      else
        FallbackReader.new(reader)
      end
    {% end %}
  end

  # new_fallback_reader creates a new fallback poll reader.
  def self.new_fallback_reader(reader : IO) : PollReader
    FallbackReader.new(reader)
  end

  {% unless flag?(:win32) %}
    # FdPollReader is a poll reader over a file descriptor.
    #
    # Crystal's event loop already multiplexes descriptors (epoll on Linux,
    # kqueue on BSD), so this reader asks the event loop to wait instead of
    # driving a second multiplexer. Readiness is a `peek` against a temporary
    # read timeout: `IO::Buffered#peek` fills through `unbuffered_read`, so a
    # ready descriptor leaves its bytes buffered for the next `read`, and a
    # quiet one raises `IO::TimeoutError`.
    #
    # That replaces Go's fd_set/kevent/epoll plumbing, the cancel pipe (two
    # descriptors plus a select() wake-up), and the epoll/kqueue handle.
    # `cancel` and `close` close the dup instead, which wakes any fiber parked
    # on it. The only syscalls left here are `dup` and the event loop's own.
    #
    # `poll` and `read` share one buffer, so use them from one fiber at a time.
    class FdPollReader < PollReader
      include IO::Buffered
      include ReadOnlyPollReader

      @read_io : IO::FileDescriptor
      @mutex : Mutex
      @canceled : Bool
      @closed : Bool

      def initialize(io : IO::FileDescriptor)
        @mutex = Mutex.new
        @canceled = false
        @closed = false

        # Reads go through a nonblocking dup: the event loop suspends the
        # reading fiber instead of blocking the thread, and cancel/close wake it
        # by closing the dup without touching the caller's descriptor.
        fd = LibC.dup(io.fd)
        raise IO::Error.from_errno("dup") if fd < 0
        @read_io = IO::FileDescriptor.new(fd)
        IO::FileDescriptor.set_blocking(fd, false)
      end

      def unbuffered_read(slice : Bytes) : Int32
        @read_io.read(slice)
      end

      def unbuffered_close : Nil
        @read_io.close
      end

      def unbuffered_rewind : Nil
        @read_io.rewind
      end

      def read(slice : Bytes) : Int32
        raise PollCanceledError.new("poll canceled") if canceled?

        begin
          n = super
        rescue ex
          raise PollCanceledError.new("poll canceled") if canceled?
          raise ex
        end
        raise PollCanceledError.new("poll canceled") if canceled?
        n
      end

      def poll(timeout : Time::Span) : Bool
        raise PollCanceledError.new("poll canceled") if canceled?

        # A negative timeout waits indefinitely, which is a nil read timeout.
        # Clearing it afterwards keeps a poll's deadline out of later reads.
        @read_io.read_timeout = timeout < 0.seconds ? nil : timeout
        begin
          # End of input makes peek return empty instead of raising. select()
          # and epoll report EOF as readable too, and the next read returns 0.
          peek
          true
        rescue IO::TimeoutError
          false
        rescue ex
          raise PollCanceledError.new("poll canceled") if canceled?
          raise ex
        ensure
          @read_io.read_timeout = nil
        end
      end

      def cancel : Bool
        @mutex.synchronize do
          return false if @canceled
          @canceled = true
        end

        # Closing the dup is what wakes a fiber parked in read/peek.
        begin
          @read_io.close
        rescue
          return false
        end
        true
      end

      def close : Nil
        return if @closed
        @closed = true

        begin
          @read_io.close
        rescue
        end
      end

      private def canceled? : Bool
        @mutex.synchronize { @canceled }
      end
    end

    # SelectReader is the poll reader for file descriptors. Go drives select()
    # here; Crystal's event loop already waits on the descriptor, so this reader
    # shares FdPollReader.
    class SelectReader < FdPollReader
    end
  {% end %}

  # FallbackReader is a poll reader for readers that cannot be polled directly:
  # anything that is not a file descriptor.
  #
  # Buffering comes from IO::Buffered, the stdlib mixin Go's bufio.Reader
  # supplies for its own fallbackReader, so peek/skip/read_byte behave like the
  # other IO decorators instead of a hand-rolled buffer.
  class FallbackReader < PollReader
    include IO::Buffered
    include ReadOnlyPollReader

    @reader : IO
    @data_chan = Channel(Nil).new(1)
    @cancel_chan = Channel(Nil).new
    @lock = Mutex.new
    @canceled = false
    @started = false
    @closed = false

    def initialize(@reader : IO)
    end

    def unbuffered_read(slice : Bytes) : Int32
      @reader.read(slice)
    end

    def unbuffered_close : Nil
      @reader.close
    end

    def unbuffered_rewind : Nil
      @reader.rewind
    end

    def read(slice : Bytes) : Int32
      raise PollCanceledError.new("poll canceled") if canceled?
      begin
        n = super
      rescue ex
        raise PollCanceledError.new("poll canceled") if canceled?
        raise ex
      end
      raise PollCanceledError.new("poll canceled") if canceled?
      n
    end

    def poll(timeout : Time::Span) : Bool
      @lock.synchronize do
        raise PollCanceledError.new("poll canceled") if @canceled
        unless @started
          @started = true
          spawn { check_buffered }
        end
      end

      if timeout < 0.seconds
        select
        when _ = @data_chan.receive?
          signal_data_available
          true
        when _ = @cancel_chan.receive?
          raise PollCanceledError.new("poll canceled")
        end
      else
        select
        when _ = @data_chan.receive?
          signal_data_available
          true
        when _ = @cancel_chan.receive?
          raise PollCanceledError.new("poll canceled")
        when timeout(timeout)
          false
        end
      end
    end

    def cancel : Bool
      @lock.synchronize do
        return false if @canceled
        @canceled = true
      end
      @cancel_chan.close unless @cancel_chan.closed?
      true
    end

    def close : Nil
      return if @closed
      @closed = true
      cancel
    end

    private def canceled? : Bool
      @lock.synchronize { @canceled }
    end

    private def check_buffered : Nil
      loop do
        return if canceled?
        begin
          data = peek
          return if data.empty?
        rescue
          return
        end

        signal_data_available
        sleep 10.milliseconds
      end
    end

    private def signal_data_available : Nil
      select
      when @data_chan.send(nil)
      when timeout(0.seconds)
      end
    end
  end
end
