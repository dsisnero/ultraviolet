require "./spec_helper"

# `WaitForMultipleObjects` returns a status code that the Windows reader used to
# ignore: a dead console handle (WAIT_FAILED) looked exactly like a normal wake,
# so the read loop spun forever instead of failing the way Go's streamData does.
# The mapping lives outside the win32 files so it is testable everywhere.
describe Ultraviolet::ConsoleWait do
  it "knows the Win32 wait constants" do
    Ultraviolet::ConsoleWait::WAIT_OBJECT_0.should eq(0x00000000_u32)
    Ultraviolet::ConsoleWait::WAIT_ABANDONED.should eq(0x00000080_u32)
    Ultraviolet::ConsoleWait::WAIT_TIMEOUT.should eq(0x00000102_u32)
    Ultraviolet::ConsoleWait::WAIT_FAILED.should eq(0xFFFFFFFF_u32)
  end

  it "reports each signaled object as ready" do
    Ultraviolet::ConsoleWait.classify(0x00000000_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::Ready)
    Ultraviolet::ConsoleWait.classify(0x00000001_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::Ready)
  end

  it "reports the failed wait" do
    Ultraviolet::ConsoleWait.classify(0xFFFFFFFF_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::Failed)
  end

  it "reports a timeout even though the reader waits with INFINITE" do
    Ultraviolet::ConsoleWait.classify(0x00000102_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::TimedOut)
  end

  it "reports abandoned objects" do
    Ultraviolet::ConsoleWait.classify(0x00000080_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::Abandoned)
    Ultraviolet::ConsoleWait.classify(0x00000081_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::Abandoned)
  end

  it "rejects an object index outside the waited set" do
    Ultraviolet::ConsoleWait.classify(0x00000002_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::Failed)
  end

  it "rejects wait statuses this reader never expects" do
    # WAIT_IO_COMPLETION only appears for alertable waits.
    Ultraviolet::ConsoleWait.classify(0x000000C0_u32, 2).should eq(Ultraviolet::ConsoleWait::Status::Failed)
  end

  it "exposes the error statuses the reader must fail on" do
    Ultraviolet::ConsoleWait::Status::Ready.error?.should be_false
    Ultraviolet::ConsoleWait::Status::TimedOut.error?.should be_true
    Ultraviolet::ConsoleWait::Status::Abandoned.error?.should be_true
    Ultraviolet::ConsoleWait::Status::Failed.error?.should be_true
  end
end
