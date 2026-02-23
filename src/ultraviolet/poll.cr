require "c/sys/select"
require "c/unistd"

module Ultraviolet
  # Default FD_SETSIZE value (commonly 1024 on most systems)
  FD_SETSIZE = 1024

  private class BufferedReader < IO
    include IO::Buffered

    def initialize(@io : IO)
    end

    def unbuffered_read(slice : Bytes)
      @io.read(slice)
    end

    def unbuffered_write(slice : Bytes)
      @io.write(slice)
    end

    def unbuffered_flush
      @io.flush
    end

    def unbuffered_close
      @io.close
    end

    def unbuffered_rewind
      @io.rewind
    end
  end

  class PollCanceledError < Exception
  end

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
  def self.new_poll_reader(reader : IO) : PollReader
    if reader.is_a?(IO::FileDescriptor) && reader.fd < FD_SETSIZE
      SelectReader.new(reader)
    else
      FallbackReader.new(reader)
    end
  end

  # new_fallback_reader creates a new fallback poll reader.
  def self.new_fallback_reader(reader : IO) : PollReader
    FallbackReader.new(reader)
  end

  # SelectReader is a poll reader for file descriptors with cancelable reads using select().
  class SelectReader < PollReader
    @reader : IO
    @file : IO::FileDescriptor
    @cancel_signal_reader : IO
    @cancel_signal_writer : IO
    @mutex : Mutex
    @canceled : Bool

    def initialize(io : IO::FileDescriptor)
      @reader = io
      @file = io
      @mutex = Mutex.new
      @canceled = false

      # Create pipe for cancel signal
      pipe_reader, pipe_writer = IO.pipe
      @cancel_signal_reader = pipe_reader
      @cancel_signal_writer = pipe_writer
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

      # Set up IO.select with file and cancel pipe
      readers = [@file, @cancel_signal_reader]

      ready = if timeout < 0.seconds
                IO.select(readers)
              else
                IO.select(readers, timeout: timeout)
              end

      raise PollCanceledError.new("poll canceled") if canceled?
      return false unless ready

      ready_readers = ready[0]

      if ready_readers.includes?(@cancel_signal_reader)
        # Remove signal from pipe
        buf = uninitialized UInt8[1]
        begin
          @cancel_signal_reader.read(buf.to_slice)
        rescue ex
          raise IO::Error.new("reading cancel signal: #{ex.message}")
        end
        raise PollCanceledError.new("poll canceled")
      end

      ready_readers.includes?(@file)
    end

    def cancel : Bool
      @mutex.synchronize do
        return false if @canceled
        @canceled = true
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
      error_msgs = [] of String

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

  # FallbackReader uses buffered IO with a background peek loop for polling.
  class FallbackReader < PollReader
    @reader : BufferedReader
    @data_chan = Channel(Nil).new(1)
    @cancel_chan = Channel(Nil).new
    @lock = Mutex.new
    @canceled = false
    @started = false

    def initialize(reader : IO)
      @reader = BufferedReader.new(reader)
    end

    def read(slice : Bytes) : Int32
      raise PollCanceledError.new("poll canceled") if canceled?
      begin
        n = @reader.read(slice)
      rescue ex
        raise PollCanceledError.new("poll canceled") if canceled?
        raise ex
      end
      if canceled?
        raise PollCanceledError.new("poll canceled")
      end
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
          @data_chan.try_send(nil)
          true
        when _ = @cancel_chan.receive?
          raise PollCanceledError.new("poll canceled")
        end
      else
        select
        when _ = @data_chan.receive?
          @data_chan.try_send(nil)
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
      cancel
    end

    private def canceled? : Bool
      @lock.synchronize { @canceled }
    end

    private def check_buffered : Nil
      loop do
        return if canceled?
        begin
          @reader.peek(1)
        rescue
          return
        end

        @data_chan.try_send(nil)
        sleep 10.milliseconds
      end
    end
  end
end
