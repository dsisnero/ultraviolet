module Ultraviolet
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
    if reader.is_a?(IO::FileDescriptor)
      SelectReader.new(reader)
    else
      FallbackReader.new(reader)
    end
  end

  # new_fallback_reader creates a new fallback poll reader.
  def self.new_fallback_reader(reader : IO) : PollReader
    FallbackReader.new(reader)
  end

  # SelectReader is a poll reader for file descriptors with cancelable reads.
  class SelectReader < PollReader
    @reader : CancelReader
    @io : IO::FileDescriptor
    @lock = Mutex.new
    @canceled = false

    def initialize(io : IO::FileDescriptor)
      @io = io
      @reader = CancelReader.new(io)
    end

    def read(slice : Bytes) : Int32
      raise PollCanceledError.new("poll canceled") if canceled?
      begin
        @reader.read(slice)
      rescue ex : CancelError
        raise PollCanceledError.new("poll canceled")
      rescue ex
        raise PollCanceledError.new("poll canceled") if canceled?
        raise ex
      end
    end

    def poll(timeout : Time::Span) : Bool
      raise PollCanceledError.new("poll canceled") if canceled?

      if timeout < 0.seconds
        ready = IO.select([@io])
      else
        ready = IO.select([@io], timeout: timeout)
      end
      raise PollCanceledError.new("poll canceled") if canceled?
      return false unless ready

      !ready[0].empty?
    end

    def cancel : Bool
      @lock.synchronize do
        return false if @canceled
        @canceled = true
      end
      @reader.cancel
      true
    end

    def close : Nil
      @reader.close
    end

    private def canceled? : Bool
      @lock.synchronize { @canceled }
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
          return true
        when _ = @cancel_chan.receive?
          raise PollCanceledError.new("poll canceled")
        end
      else
        select
        when _ = @data_chan.receive?
          @data_chan.try_send(nil)
          return true
        when _ = @cancel_chan.receive?
          raise PollCanceledError.new("poll canceled")
        when timeout(timeout)
          return false
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
