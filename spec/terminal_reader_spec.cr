require "./spec_helper"

module Ultraviolet
  private class CancelingIO < IO
    def read(slice : Bytes) : Int32
      raise CancelError.new("read canceled")
    end

    def write(slice : Bytes) : Nil
    end

    def flush : Nil
    end

    def close : Nil
    end
  end

  describe TerminalReader do
    it "treats CancelError as a graceful stop" do
      reader = TerminalReader.new(CancelingIO.new, "xterm-256color")
      eventc = Channel(Event).new

      reader.stream_events(eventc)
    end
  end
end
