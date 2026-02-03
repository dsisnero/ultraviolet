module Ultraviolet
  class CancelError < Exception
  end

  class CancelReader
    def initialize(@io : IO?)
      @canceled = false
      @lock = Mutex.new
    end

    def cancel : Bool
      @lock.synchronize { @canceled = true }
      true
    end

    def canceled? : Bool
      @lock.synchronize { @canceled }
    end

    def close : Nil
      @io.try &.close
    end

    def read(slice : Bytes) : Int32
      raise CancelError.new("read canceled") if canceled?

      if io = @io
        io.read(slice)
      else
        0
      end
    end
  end

  def self.new_cancel_reader(io : IO?) : CancelReader
    CancelReader.new(io)
  end
end
