{% unless flag?(:win32) %}
  require "c/sys/select"
  require "c/unistd"

  lib LibC
    fun dup(fd : Int32) : Int32
  end
{% end %}

module Ultraviolet
  # Default FD_SETSIZE value (commonly 1024 on most systems)
  FD_SETSIZE = 1024

  class PollCanceledError < Exception
  end

  # PollReader reads go through Crystal's IO event loop, never a raw wait.
  #
  # Under Crystal's cooperative scheduler a blocking syscall inside a fiber
  # stalls the scheduler thread: a raw select()/epoll_wait()/read() in `read`
  # makes `cancel` impossible to observe (measured: a fiber parked in a raw
  # select() freezes the main fiber). Reads therefore use a nonblocking dup of
  # the input; Crystal's event loop suspends the fiber on EAGAIN, and
  # cancel/close wake it by closing that dup.
  #
  # `poll` runs the platform wait (select/epoll_wait/kevent/
  # WaitForMultipleObjects) on a Thread, because those calls block the whole
  # scheduler thread. The calling fiber suspends on a channel instead, so a
  # poll with a long timeout no longer freezes the rest of the program.
  abstract class PollReader < IO
    abstract def read(slice : Bytes) : Int32
    abstract def cancel : Bool
    abstract def close : Nil

    # poll reports whether data is ready, waiting up to *timeout* (a negative
    # timeout waits indefinitely) and raising [PollCanceledError] if the reader
    # is canceled.
    def poll(timeout : Time::Span) : Bool
      result = Channel(Bool | Exception).new(1)
      waiter = Thread.new do
        result.send(poll_now(timeout))
      rescue ex
        result.send(ex)
      end

      outcome = result.receive
      waiter.join
      raise outcome if outcome.is_a?(Exception)
      outcome
    end

    # poll_now performs the platform wait on the calling OS thread. It stalls
    # the scheduler for as long as it waits, so call [poll] unless the caller
    # is already on a thread it may block.
    protected def poll_now(timeout : Time::Span) : Bool
      raise NotImplementedError.new("#{self.class}#poll_now")
    end

    def write(slice : Bytes) : Nil
      raise IO::Error.new("poll reader is read-only")
    end

    def flush : Nil
    end
  end

  # new_poll_reader creates a poll reader for the given IO.
  def self.new_poll_reader(reader : IO) : PollReader
    {% if flag?(:win32) %}
      # No select() binding on Windows; the fallback reader is channel-based.
      FallbackReader.new(reader)
    {% else %}
      if reader.is_a?(IO::FileDescriptor) && reader.fd < FD_SETSIZE
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
    # SelectReader is a poll reader for file descriptors with cancelable reads using select().
    class SelectReader < PollReader
      @reader : IO
      @file : IO::FileDescriptor
      @read_io : IO::FileDescriptor
      @cancel_signal_reader : IO
      @cancel_signal_writer : IO
      @mutex : Mutex
      @canceled : Bool
      @closed : Bool

      def initialize(io : IO::FileDescriptor)
        @reader = io
        @file = io
        @mutex = Mutex.new
        @canceled = false
        @closed = false

        # Reads go through a nonblocking dup: Crystal's event loop suspends the
        # reading fiber instead of blocking the thread, and cancel/close can
        # wake it by closing the dup without touching the caller's descriptor.
        fd = LibC.dup(@file.fd)
        raise IO::Error.from_errno("dup") if fd < 0
        @read_io = IO::FileDescriptor.new(fd)
        IO::FileDescriptor.set_blocking(fd, false)

        # Create pipe for cancel signal
        pipe_reader, pipe_writer = IO.pipe
        @cancel_signal_reader = pipe_reader
        @cancel_signal_writer = pipe_writer
      end

      def read(slice : Bytes) : Int32
        raise PollCanceledError.new("poll canceled") if canceled?

        # Reads go through the nonblocking dup, so the fiber suspends in
        # Crystal's event loop instead of blocking the scheduler thread, and
        # cancel/close wakes it by closing the dup.
        begin
          @read_io.read(slice)
        rescue ex
          raise PollCanceledError.new("poll canceled") if canceled?
          raise ex
        end
      end

      protected def poll_now(timeout : Time::Span) : Bool
        raise PollCanceledError.new("poll canceled") if canceled?

        rfds = uninitialized LibC::FdSet
        fd_zero(pointerof(rfds))
        fd_set(@file.fd, pointerof(rfds))
        fd_set(@cancel_signal_reader.as(IO::FileDescriptor).fd, pointerof(rfds))

        max_fd = Math.max(@file.fd, @cancel_signal_reader.as(IO::FileDescriptor).fd) + 1
        tv = LibC::Timeval.new

        tv_ptr = if timeout < 0.seconds
                   Pointer(LibC::Timeval).null
                 else
                   tv.tv_sec = timeout.seconds.to_i64
                   tv.tv_usec = ((timeout - timeout.seconds.seconds).total_microseconds).to_i32
                   pointerof(tv)
                 end

        ready = loop do
          n = LibC.select(max_fd, pointerof(rfds), Pointer(LibC::FdSet).null, Pointer(LibC::FdSet).null, tv_ptr)
          if n < 0 && Errno.value == Errno::EINTR
            next
          end
          break n
        end

        raise PollCanceledError.new("poll canceled") if canceled?
        return false if ready == 0
        if ready < 0
          raise IO::Error.from_errno("select")
        end

        if fd_isset(@cancel_signal_reader.as(IO::FileDescriptor).fd, pointerof(rfds))
          # Remove signal from pipe
          buf = uninitialized UInt8[1]
          begin
            @cancel_signal_reader.read(buf.to_slice)
          rescue ex
            raise IO::Error.new("reading cancel signal: #{ex.message}")
          end
          raise PollCanceledError.new("poll canceled")
        end

        fd_isset(@file.fd, pointerof(rfds))
      end

      def cancel : Bool
        @mutex.synchronize do
          return false if @canceled
          @canceled = true
        end

        # Wake a fiber blocked in read() by closing its dup; the cancel pipe
        # wakes a caller blocked in poll().
        begin
          @read_io.close
        rescue
          return false
        end

        # Send cancel signal
        begin
          @cancel_signal_writer.write_bytes('c'.ord.to_u8)
        rescue
          return false
        end
        true
      end

      def close : Nil
        # Stdlib decorators (IO::Delimited, IO::Sized, IO::Stapled) make close
        # idempotent; without this the second close reports EBADF from the
        # already-closed descriptors.
        return if @closed
        @closed = true

        error_msgs = [] of String

        begin
          @read_io.close
        rescue ex
          error_msgs << "closing read handle: #{ex.message}"
        end

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

      private def fd_zero(set : LibC::FdSet*) : Nil
        # The StaticArray lives by value inside the struct: mutate a copy and
        # assign it back, otherwise the write lands in a temporary.
        words = set.value.fds_bits
        words.fill(0)
        set.value.fds_bits = words
      end

      private def fd_set(fd : Int32, set : LibC::FdSet*) : Nil
        bits_per_word = 8 * sizeof(typeof(set.value.fds_bits[0]))
        idx = fd // bits_per_word
        bit = fd % bits_per_word
        words = set.value.fds_bits
        words[idx] |= (typeof(words[0]).new(1) << bit)
        set.value.fds_bits = words
      end

      private def fd_isset(fd : Int32, set : LibC::FdSet*) : Bool
        bits_per_word = 8 * sizeof(typeof(set.value.fds_bits[0]))
        idx = fd // bits_per_word
        bit = fd % bits_per_word
        (set.value.fds_bits[idx] & (typeof(set.value.fds_bits[0]).new(1) << bit)) != 0
      end
    end

    # FallbackReader uses buffered IO with a background peek loop for polling.
  {% end %}

  # FallbackReader is a poll reader for readers that cannot be polled directly:
  # anything that is not a file descriptor, plus descriptors at or above
  # FD_SETSIZE.
  #
  # Buffering comes from IO::Buffered, the stdlib mixin Go's bufio.Reader
  # supplies for its own fallbackReader, so peek/skip/read_byte behave like the
  # other IO decorators instead of a hand-rolled buffer.
  class FallbackReader < PollReader
    include IO::Buffered

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

    def unbuffered_write(slice : Bytes) : Nil
      raise IO::Error.new("poll reader is read-only")
    end

    def unbuffered_flush : Nil
    end

    def unbuffered_close : Nil
      @reader.close
    end

    def unbuffered_rewind : Nil
      @reader.rewind
    end

    # Poll readers are read-only. Say so directly instead of letting
    # IO::Buffered accept writes it can never flush.
    def write(slice : Bytes) : Nil
      raise IO::Error.new("poll reader is read-only")
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
