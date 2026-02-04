require "./spec_helper"

module Ultraviolet
  describe "PollReader" do
    it "creates a poll reader for non-file readers" do
      reader = IO::Memory.new
      pr = Ultraviolet.new_poll_reader(reader)

      pr.cancel.should be_true
    end

    {% unless flag?(:win32) %}
      it "cancels a blocking read" do
        read_end, write_end = IO.pipe
        poll_reader = Ultraviolet.new_poll_reader(read_end)

        msg = "hello"
        write_end.write(msg.to_slice)

        result = Channel(Tuple(Int32, Exception?)).new(1)
        spawn do
          begin
            buf = Bytes.new(1)
            n = poll_reader.read(buf)
            result.send({n, nil})
          rescue ex
            result.send({0, ex})
          end
        end

        poll_reader.cancel.should be_true

        select
        when res = result.receive
          res[0].should eq(0)
          res[1].should be_a(PollCanceledError)
        when timeout(100.milliseconds)
          fail("expected cancellation to unblock reader")
        end

        poll_reader = Ultraviolet.new_poll_reader(read_end)
        buf = Bytes.new(5)
        n = poll_reader.read(buf)
        n.should eq(5)
        String.new(buf[0, n]).should eq(msg)
      ensure
        write_end.try &.close
        read_end.try &.close
      end
    {% end %}
  end
end
