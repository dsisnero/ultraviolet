module Ultraviolet
  # Classification of a `WaitForMultipleObjects` result.
  #
  # Go's `conInputReader.waitForInput` returns the wait error, so a dead console
  # handle aborts `streamData`. Crystal's `wait_for_input` used to ignore the
  # status entirely, which turned `WAIT_FAILED` into a silent no-op wake. The
  # mapping lives here, outside the `flag?(:win32)` files, so it is testable on
  # every platform.
  module ConsoleWait
    enum Status
      Ready
      Abandoned
      TimedOut
      Failed

      # True for every status the reader must treat as a failure.
      def error? : Bool
        !ready?
      end
    end

    WAIT_OBJECT_0  = 0x00000000_u32
    WAIT_ABANDONED = 0x00000080_u32
    WAIT_TIMEOUT   = 0x00000102_u32
    WAIT_FAILED    = 0xFFFFFFFF_u32

    # The reader only ever waits with INFINITE, so a timeout or an abandoned
    # object means the handle state cannot be trusted.
    def self.classify(result : UInt32, wait_count : Int32) : Status
      return Status::Failed if result == WAIT_FAILED
      return Status::TimedOut if result == WAIT_TIMEOUT
      return Status::Ready if result < wait_count.to_u32

      abandoned_end = WAIT_ABANDONED + wait_count.to_u32
      return Status::Abandoned if result >= WAIT_ABANDONED && result < abandoned_end

      Status::Failed
    end
  end
end
