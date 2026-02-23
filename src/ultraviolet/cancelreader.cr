module Ultraviolet
  class CancelError < Exception
  end

  module CancelMixin
    @canceled = false
    @lock = Mutex.new

    def set_canceled : Nil
      @lock.synchronize { @canceled = true }
    end

    def canceled? : Bool
      @lock.synchronize { @canceled }
    end
  end

  class CancelReader < IO
    include CancelMixin

    DEFAULT_TIMEOUT = 50.milliseconds

    def initialize(@io : IO?, @timeout : Time::Span = DEFAULT_TIMEOUT)
      @timeout_supported = false
      @original_timeout = nil.as(Time::Span?)
      if io = @io
        @io_fd = io.as?(IO::FileDescriptor)
        if io_fd = @io_fd
          @timeout_supported = true
          @original_timeout = io_fd.read_timeout
          io_fd.read_timeout = @timeout
        end
      else
        @io_fd = nil
      end
    end

    def cancel : Bool
      set_canceled
      unless @timeout_supported
        if io = @io
          begin
            io.close unless io.same?(STDIN)
          rescue
          end
        end
      end
      true
    end

    def close : Nil
      if @timeout_supported
        if io_fd = @io_fd
          io_fd.read_timeout = @original_timeout
        end
      end
      @io.try &.close
    end

    def read(slice : Bytes) : Int32
      loop do
        raise CancelError.new("read canceled") if canceled?
        io = @io
        return 0 unless io
        begin
          return io.read(slice)
        rescue IO::TimeoutError
          next
        end
      end
    end

    def write(slice : Bytes) : Nil
      @io.try &.write(slice)
    end

    def flush : Nil
      @io.try &.flush
    end
  end

  def self.new_cancel_reader(io : IO?) : CancelReader
    CancelReader.new(io)
  end
end
