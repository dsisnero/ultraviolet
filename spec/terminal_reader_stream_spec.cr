require "./spec_helper"

# Defined outside module Ultraviolet to avoid ivar inference conflicts
# with other IO subclasses in the module.
private class LimitedReader < IO
  def initialize(@data : Bytes, @limit : Int32)
    @pos = 0
  end

  def read(slice : Bytes) : Int32
    return 0 if @pos >= @data.size
    n = {@data.size - @pos, @limit}.min
    n = {n, slice.size}.min
    slice[0, n].copy_from(@data[@pos, n])
    @pos += n
    n
  end

  def write(slice : Bytes) : Nil
  end

  def close : Nil
  end

  def closed? : Bool
    @pos >= @data.size
  end
end

private def collect_events(reader : Ultraviolet::TerminalReader) : Array(Ultraviolet::Event)
  eventc = Channel(Ultraviolet::Event).new(64)

  spawn do
    reader.stream_events(eventc)
    eventc.close
  end

  events = [] of Ultraviolet::Event
  begin
    loop do
      events << eventc.receive
    end
  rescue Channel::ClosedError
  end
  events
end

module Ultraviolet
  describe "TerminalReader stream integration" do
    it "reads simple key events" do
      reader = TerminalReader.new(IO::Memory.new("abc".to_slice), "dumb")
      events = collect_events(reader)
      events.should eq([
        Key.new(code: 'a'.ord, text: "a"),
        Key.new(code: 'b'.ord, text: "b"),
        Key.new(code: 'c'.ord, text: "c"),
      ])
    end

    it "handles long input" do
      input = "a" * 100
      reader = TerminalReader.new(IO::Memory.new(input.to_slice), "dumb")
      events = collect_events(reader)
      events.size.should eq(100)
      events.each { |e| e.should eq(Key.new(code: 'a'.ord, text: "a")) }
    end

    it "handles up arrow and shift+tab" do
      input = Bytes.new(6)
      input[0] = 0x1b_u8; input[1] = '['.ord.to_u8; input[2] = 'A'.ord.to_u8
      input[3] = 0x1b_u8; input[4] = '['.ord.to_u8; input[5] = 'Z'.ord.to_u8
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([
        Key.new(code: KeyUp),
        Key.new(code: KeyTab, mod: ModShift),
      ])
    end

    it "handles enter and alt+enter" do
      input = Bytes[0x0d_u8, 0x1b_u8, 0x0d_u8]
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([
        Key.new(code: KeyEnter),
        Key.new(code: KeyEnter, mod: ModAlt),
      ])
    end

    it "handles alt+char alternation" do
      input = "a\x1baa".to_slice
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([
        Key.new(code: 'a'.ord, text: "a"),
        Key.new(code: 'a'.ord, mod: ModAlt),
        Key.new(code: 'a'.ord, text: "a"),
      ])
    end

    it "handles ctrl+a and ctrl+b via C0 control bytes" do
      input = Bytes[1_u8, 2_u8]
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([
        Key.new(code: 'a'.ord, mod: ModCtrl),
        Key.new(code: 'b'.ord, mod: ModCtrl),
      ])
    end

    it "handles insert key" do
      input = "\x1b[2~".to_slice
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([Key.new(code: KeyInsert)])
    end

    it "handles space key" do
      reader = TerminalReader.new(IO::Memory.new(" ".to_slice), "dumb")
      events = collect_events(reader)
      events.should eq([Key.new(code: KeySpace, text: " ")])
    end

    it "handles ctrl+alt+a via ESC SOH" do
      input = Bytes[0x1b_u8, 1_u8]
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([Key.new(code: 'a'.ord, mod: ModCtrl | ModAlt)])
    end

    it "handles a, b, c, d in sequence" do
      reader = TerminalReader.new(IO::Memory.new("abcd".to_slice), "dumb")
      events = collect_events(reader)
      events.should eq([
        Key.new(code: 'a'.ord, text: "a"),
        Key.new(code: 'b'.ord, text: "b"),
        Key.new(code: 'c'.ord, text: "c"),
        Key.new(code: 'd'.ord, text: "d"),
      ])
    end

    it "handles powershell up/down/right/left sequences" do
      input = "\x1bOA\x1bOB\x1bOC\x1bOD".to_slice
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([
        Key.new(code: KeyUp),
        Key.new(code: KeyDown),
        Key.new(code: KeyRight),
        Key.new(code: KeyLeft),
      ])
    end

    it "handles unknown CSI sequence" do
      input = "\x1b[----X".to_slice
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.size.should eq(1)
      events[0].should be_a(UnknownCsiEvent)
    end

    it "handles split reads across small chunks (LimitedReader)" do
      inputs = [
        "abc", "\x1b[A", "\x1b[<0;33", ";17M", "\x1b[I",
        "\x1b", "[", "<", "0", ";", "3", "3", ";", "1", "7", "M",
        "\x1b[O", "\x1b", "]", "2", ";", "a", "b", "c",
        "\x1b", "\x1b[", "<0;3", "3;17M",
        "\x1b[A\x1b[", "<0;33;17M\x1b[", "<0;33;17M\x1b[I",
        "\x1b[12;34;9",
      ]
      all = Bytes.new(inputs.sum(&.bytesize))
      pos = 0
      inputs.each { |s| s.each_byte { |b| all[pos] = b; pos += 1 } }

      r = LimitedReader.new(all, 8)
      reader = TerminalReader.new(r, "dumb")
      events = collect_events(reader)

      events.size.should eq(14)
      events[0].should eq(Key.new(code: 'a'.ord, text: "a"))
      events[1].should eq(Key.new(code: 'b'.ord, text: "b"))
      events[2].should eq(Key.new(code: 'c'.ord, text: "c"))
      events[3].should eq(Key.new(code: KeyUp))
      events[4].should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      events[5].should eq(FocusEvent.new)
      events[6].should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      events[7].should eq(BlurEvent.new)
      events[8].should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      events[9].should eq(Key.new(code: KeyUp))
      events[10].should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      events[11].should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      events[12].should eq(FocusEvent.new)
      (events[13].is_a?(UnknownCsiEvent) || events[13].is_a?(UnknownEvent)).should be_true
    end

    it "handles X10 mouse wheel up via TerminalReader" do
      input = Bytes[0x1b_u8, '['.ord.to_u8, 'M'.ord.to_u8, (32 + 64).to_u8, 65_u8, 49_u8]
      reader = TerminalReader.new(IO::Memory.new(input), "dumb")
      events = collect_events(reader)
      events.should eq([MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelUp))])
    end
  end
end
