module Ultraviolet
  # How long to sleep when the console handle wakes the reader with nothing to
  # read. Ported from Go's `emptyWakeBackoff`.
  EMPTY_WAKE_BACKOFF = 10.milliseconds

  # Peeks a console for input records, blocking between attempts, and backs off
  # when a wake produced nothing.
  #
  # Go's `TerminalReader.streamData` opens the console handle, waits on it, and
  # only falls back to sleeping when a wake returns no records: Windows
  # Terminal can signal the handle with nothing behind it, and nothing promises
  # the handle is unsignaled afterwards. Backing off once per empty wake costs
  # what the old poll loop did instead of a full core.
  #
  # The loop lives here (generic, no Win32) so that policy is testable on any
  # platform; `terminal_reader_windows.cr` supplies the console peek, the
  # `ConInputReader#wait_for_input` wait, and the real backoff sleep.
  class ConsoleWakeLoop(T)
    def initialize(
      @peek : -> Array(T),
      @wait : -> Nil,
      @backoff : -> Nil,
    )
    end

    # Returns the next non-empty batch of records, or nil when `stopped`
    # becomes true. Like Go, the wake state resets with every batch: a fresh
    # batch has not seen a wake yet.
    def next_batch(stopped : -> Bool) : Array(T)?
      woke = false
      loop do
        return nil if stopped.call

        records = @peek.call
        return nil if stopped.call
        return records unless records.empty?

        if woke
          @backoff.call
          return nil if stopped.call
        end

        @wait.call
        return nil if stopped.call
        woke = true
      end
    end
  end
end
