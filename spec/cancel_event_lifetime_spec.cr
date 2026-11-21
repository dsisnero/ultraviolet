require "./spec_helper"

# The Windows cancel reader owns a Win32 event that must outlive every reader
# blocked on it: Close() must not free a handle a reader is still waiting on
# (Windows reuses handle numbers), and the last participant frees it exactly
# once. Go keeps that bookkeeping inline in conInputReader; Crystal extracts it
# so the decisions are testable off Windows.
describe Ultraviolet::CancelEventLifetime do
  it "frees the event on close when nobody is waiting" do
    lifetime = Ultraviolet::CancelEventLifetime.new

    lifetime.close.should eq(true)
    lifetime.closed?.should be_true
    lifetime.freed?.should be_true
  end

  it "leaves the event to a waiting reader" do
    lifetime = Ultraviolet::CancelEventLifetime.new
    lifetime.acquire.should eq(true)

    lifetime.close.should eq(false)
    lifetime.closed?.should be_true
    lifetime.freed?.should be_false
  end

  it "frees on the last release after close" do
    lifetime = Ultraviolet::CancelEventLifetime.new
    lifetime.acquire

    lifetime.close.should eq(false)
    lifetime.release.should eq(true)
    lifetime.freed?.should be_true
  end

  it "does not free while another waiter remains" do
    lifetime = Ultraviolet::CancelEventLifetime.new
    lifetime.acquire
    lifetime.acquire

    lifetime.close.should eq(false)
    lifetime.release.should eq(false)
    lifetime.waiters.should eq(1)
    lifetime.freed?.should be_false
    lifetime.release.should eq(true)
  end

  it "frees only once when a late release follows a close that freed" do
    lifetime = Ultraviolet::CancelEventLifetime.new
    lifetime.acquire

    lifetime.close.should eq(false)
    lifetime.release.should eq(true)
    lifetime.release.should eq(false)
    lifetime.freed?.should be_true
  end

  it "treats a second close as a no-op" do
    lifetime = Ultraviolet::CancelEventLifetime.new
    lifetime.close.should eq(true)

    lifetime.close.should be_nil
  end

  it "refuses a waiter once closed" do
    lifetime = Ultraviolet::CancelEventLifetime.new
    lifetime.close

    lifetime.acquire.should eq(false)
    lifetime.waiters.should eq(0)
  end

  it "never frees on a release taken before close" do
    lifetime = Ultraviolet::CancelEventLifetime.new
    lifetime.acquire.should eq(true)

    lifetime.release.should eq(false)
    lifetime.freed?.should be_false
    lifetime.close.should eq(true)
  end
end
