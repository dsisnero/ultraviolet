require "./spec_helper"

module Ultraviolet
  private class BlockingReader < IO
    getter? read_called : Bool
    getter started_chan : Channel(Nil)
    getter unblock_chan : Channel(Nil)

    def initialize
      @read_called = false
      @started_chan = Channel(Nil).new(1)
      @unblock_chan = Channel(Nil).new(1)
      @lock = Mutex.new
    end

    def read(slice : Bytes) : Int32
      @started_chan.send(nil)
      @unblock_chan.receive
      @lock.synchronize { @read_called = true }
      raise IO::Error.new("this error should be ignored")
    end

    def write(slice : Bytes) : Nil
    end

    def flush : Nil
    end
  end

  describe "FallbackReader" do
    it "waits for underlying read during cancellation" do
      reader = BlockingReader.new
      pr = Ultraviolet.new_fallback_reader(reader)

      done = Channel(Nil).new(1)
      spawn do
        begin
          IO.copy(pr, IO::Memory.new)
        rescue ex
          ex.should be_a(PollCanceledError)
        ensure
          done.send(nil)
        end
      end

      reader.started_chan.receive
      pr.cancel
      reader.unblock_chan.send(nil)
      done.receive

      reader.read_called?.should be_true
    end

    it "reads data then errors after cancel" do
      io = IO::Memory.new
      pr = Ultraviolet.new_fallback_reader(io)

      io.write("first".to_slice)
      io.pos = 0

      buf = IO::Memory.new
      IO.copy(pr, buf)
      buf.to_s.should eq("first")

      pr.cancel
      expect_raises(PollCanceledError) do
        IO.copy(pr, IO::Memory.new)
      end
    end

    it "buffers through IO::Buffered" do
      io = IO::Memory.new("hello")
      pr = Ultraviolet.new_fallback_reader(io)

      # The first read pulls everything the wrapped IO has into the buffer.
      pr.read(Bytes.new(3)).should eq(3)
      io.pos.should eq(5)

      # peek and read_byte are served from that buffer, and skip leaves the
      # wrapped IO where it was.
      String.new(pr.peek).should eq("lo")
      pr.read_byte.should eq('l'.ord)
      pr.skip(1)
      io.pos.should eq(5)
    end

    it "rejects writes instead of buffering them" do
      io = IO::Memory.new("hello")
      pr = Ultraviolet.new_fallback_reader(io)

      expect_raises(IO::Error, "read-only") do
        pr.write("nope".to_slice)
      end
      io.to_s.should eq("hello")
    end

    it "closes idempotently" do
      io = IO::Memory.new("hello")
      pr = Ultraviolet.new_fallback_reader(io)

      pr.close
      pr.close
    end
  end
end
