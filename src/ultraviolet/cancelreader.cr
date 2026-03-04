{% unless flag?(:win32) %}
  require "c/fcntl"
  require "c/unistd"
{% end %}

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

    def initialize(@io : IO?)
      @io_fd = io.as?(IO::FileDescriptor)
      @flags_changed = false
      @original_flags = 0
      {% unless flag?(:win32) %}
        if io_fd = @io_fd
          current_flags = LibC.fcntl(io_fd.fd, LibC::F_GETFL, 0)
          if current_flags >= 0
            @original_flags = current_flags
            if LibC.fcntl(io_fd.fd, LibC::F_SETFL, current_flags | LibC::O_NONBLOCK) == 0
              @flags_changed = true
            end
          end
        end
      {% end %}
    end

    def wrapped_fd : IO::FileDescriptor?
      @io.as?(IO::FileDescriptor)
    end

    def cancel : Bool
      set_canceled
      if io = @io
        begin
          io.close unless io.same?(STDIN)
        rescue
        end
      end
      true
    end

    def close : Nil
      {% unless flag?(:win32) %}
        if @flags_changed
          if io_fd = @io_fd
            LibC.fcntl(io_fd.fd, LibC::F_SETFL, @original_flags)
          end
        end
      {% end %}
      begin
        @io.try &.close
      rescue
      end
    end

    def read(slice : Bytes) : Int32
      raise CancelError.new("read canceled") if canceled?
      io = @io
      return 0 unless io

      loop do
        raise CancelError.new("read canceled") if canceled?
        if io_fd = @io_fd
          read_bytes = LibC.read(io_fd.fd, slice.to_unsafe, slice.size)
          if read_bytes > 0
            return read_bytes.to_i32
          elsif read_bytes == 0
            return 0
          else
            errno = Errno.value
            if errno == Errno::EAGAIN || errno == Errno::EWOULDBLOCK || errno == Errno::EINTR
              sleep 5.milliseconds
              next
            end
            raise IO::Error.from_errno("read")
          end
        else
          begin
            return io.read(slice)
          rescue ex : IO::Error
            errno = Errno.value
            if errno == Errno::EAGAIN || errno == Errno::EWOULDBLOCK
              sleep 5.milliseconds
              next
            end
            raise ex
          end
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
