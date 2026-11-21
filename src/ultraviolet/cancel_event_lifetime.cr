module Ultraviolet
  # Ownership accounting for a Win32 cancel event.
  #
  # A `ConInputReader` on Windows creates a manual-reset event so a blocked
  # reader can be woken by `Cancel`/`Close`. Windows reuses handle numbers
  # quickly, so the event must not be freed while a reader still waits on it:
  # `Close` hands the handle to the last waiting reader instead, and whoever
  # ends up last frees it exactly once.
  #
  # This mirrors the `eventMu`/`waiters`/`closed`/`eventFreed` bookkeeping that
  # Go keeps inline in `conInputReader` (`cancelreader_windows.go`), extracted
  # so the lifetime decisions are testable where Win32 is unavailable.
  #
  # Reference type on purpose: the state is shared and must not be copied.
  class CancelEventLifetime
    @mutex = Mutex.new
    @waiters = 0
    @closed = false
    @freed = false

    # Registers a waiter. Returns false when the lifetime is already closed, in
    # which case the caller must not wait on the event.
    def acquire : Bool
      @mutex.synchronize do
        return false if @closed
        @waiters += 1
        true
      end
    end

    # Unregisters a waiter. Returns true when this was the last waiter of a
    # closed lifetime, so the caller must close the event handle.
    def release : Bool
      @mutex.synchronize do
        @waiters -= 1 if @waiters > 0
        free_now = @closed && @waiters == 0 && !@freed
        @freed = true if free_now
        free_now
      end
    end

    # Closes the lifetime. Returns nil when it was already closed (idempotent
    # no-op), true when the caller must close the event handle now, and false
    # when a remaining waiter will close it on its way out.
    def close : Bool?
      @mutex.synchronize do
        return nil if @closed
        @closed = true
        free_now = @waiters == 0
        @freed = true if free_now
        free_now
      end
    end

    def closed? : Bool
      @mutex.synchronize { @closed }
    end

    def freed? : Bool
      @mutex.synchronize { @freed }
    end

    def waiters : Int32
      @mutex.synchronize { @waiters }
    end
  end
end
