require "./spec_helper"

# Go's TerminalReader.streamData polls the console, blocks on the console
# handle between attempts, and backs off when a wake produced no records (so a
# handle that stays signaled cannot spin a core). Crystal extracts that inner
# loop so the anti-spin policy is testable off Windows; the Win32 calls stay in
# terminal_reader_windows.cr.
describe Ultraviolet::ConsoleWakeLoop do
  it "backs off for the ported Go interval" do
    Ultraviolet::EMPTY_WAKE_BACKOFF.should eq(10.milliseconds)
  end

  it "returns the first batch without waiting" do
    peeked = 0
    waits = 0
    backoffs = 0

    loop = Ultraviolet::ConsoleWakeLoop(Int32).new(
      peek: -> { peeked += 1; [1] },
      wait: -> { waits += 1; nil },
      backoff: -> { backoffs += 1; nil },
    )

    loop.next_batch(-> { false }).should eq([1])
    peeked.should eq(1)
    waits.should eq(0)
    backoffs.should eq(0)
  end

  it "waits on the console when a peek comes back empty" do
    peeks = [[] of Int32, [1]]
    waits = 0
    backoffs = 0

    loop = Ultraviolet::ConsoleWakeLoop(Int32).new(
      peek: -> { peeks.shift || [] of Int32 },
      wait: -> { waits += 1; nil },
      backoff: -> { backoffs += 1; nil },
    )

    loop.next_batch(-> { false }).should eq([1])
    waits.should eq(1)
    backoffs.should eq(0)
  end

  it "backs off only after a wake that produced nothing" do
    peeks = [[] of Int32, [] of Int32, [7]]
    waits = 0
    backoffs = 0

    loop = Ultraviolet::ConsoleWakeLoop(Int32).new(
      peek: -> { peeks.shift || [] of Int32 },
      wait: -> { waits += 1; nil },
      backoff: -> { backoffs += 1; nil },
    )

    loop.next_batch(-> { false }).should eq([7])
    waits.should eq(2)
    backoffs.should eq(1)
  end

  it "does not carry the wake state into the next batch" do
    peeks = [[] of Int32, [1], [] of Int32, [2]]
    waits = 0
    backoffs = 0

    loop = Ultraviolet::ConsoleWakeLoop(Int32).new(
      peek: -> { peeks.shift || [] of Int32 },
      wait: -> { waits += 1; nil },
      backoff: -> { backoffs += 1; nil },
    )

    loop.next_batch(-> { false }).should eq([1])
    loop.next_batch(-> { false }).should eq([2])
    waits.should eq(2)
    backoffs.should eq(0)
  end

  it "returns nil without peeking when already stopped" do
    peeked = 0

    loop = Ultraviolet::ConsoleWakeLoop(Int32).new(
      peek: -> { peeked += 1; [] of Int32 },
      wait: -> { nil },
      backoff: -> { nil },
    )

    loop.next_batch(-> { true }).should be_nil
    peeked.should eq(0)
  end

  it "returns nil when stopped while waiting" do
    stopped = false
    waits = 0

    loop = Ultraviolet::ConsoleWakeLoop(Int32).new(
      peek: -> { [] of Int32 },
      wait: -> { waits += 1; stopped = true; nil },
      backoff: -> { nil },
    )

    loop.next_batch(-> { stopped }).should be_nil
    waits.should eq(1)
  end

  it "returns nil when stopped while backing off" do
    stopped = false
    peeks = 0
    backoffs = 0

    loop = Ultraviolet::ConsoleWakeLoop(Int32).new(
      peek: -> { peeks += 1; [] of Int32 },
      wait: -> { nil },
      backoff: -> { backoffs += 1; stopped = true; nil },
    )

    loop.next_batch(-> { stopped }).should be_nil
    backoffs.should eq(1)
    peeks.should eq(2)
  end
end
