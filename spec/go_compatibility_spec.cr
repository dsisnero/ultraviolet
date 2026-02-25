require "./spec_helper"

module Ultraviolet
  private def self.uv_color(str : String) : Color
    if color = Ansi.x_parse_color(str)
      Color.new(color.r, color.g, color.b)
    else
      raise "Failed to parse color: #{str}"
    end
  end

  private class TestTerminalReader < TerminalReader
    def scan_events_public(buf : Bytes, expired : Bool)
      scan_events(buf, expired)
    end
  end

  private class ChunkedReader < IO
    @offset : Int32 = 0

    def initialize(@input : String, @chunk_size : Int32)
    end

    def read(slice : Bytes) : Int32
      remaining = @input.bytesize - @offset
      return 0 if remaining <= 0

      n = Math.min(slice.size, Math.min(@chunk_size, remaining))
      data = @input.to_slice[@offset, n]
      slice[0, n].copy_from(data)
      @offset += n
      n
    end

    def write(slice : Bytes) : Nil
    end

    def flush : Nil
    end

    def close : Nil
    end
  end

  private class ChunkSequenceReader < IO
    @chunk_index : Int32 = 0
    @chunk_offset : Int32 = 0
    @reads : Int32 = 0

    def initialize(@chunks : Array(Bytes), @limit : Int32 = 32, @delay : Time::Span = 0.milliseconds)
    end

    def read(slice : Bytes) : Int32
      return 0 if @chunk_index >= @chunks.size
      if @reads > 0 && @delay > 0.milliseconds
        sleep @delay
      end

      while @chunk_index < @chunks.size
        chunk = @chunks[@chunk_index]
        available = chunk.size - @chunk_offset
        if available <= 0
          @chunk_index += 1
          @chunk_offset = 0
          next
        end

        n = Math.min(slice.size, Math.min(@limit, available))
        slice[0, n].copy_from(chunk[@chunk_offset, n])
        @chunk_offset += n
        @reads += 1
        return n
      end

      0
    end

    def write(slice : Bytes) : Nil
    end

    def flush : Nil
    end

    def close : Nil
    end
  end

  private def self.wrap_byte(value : Int32) : UInt8
    (value & 0xff).to_u8
  end

  private def self.encode_x10_mouse(button : Int32, x : Int32, y : Int32) : Bytes
    Bytes[
      0x1b_u8,
      '['.ord.to_u8,
      'M'.ord.to_u8,
      wrap_byte(32 + button),
      wrap_byte(x + 33),
      wrap_byte(y + 33),
    ]
  end

  private def self.encode_sgr_mouse(button : Int32, x : Int32, y : Int32, release : Bool) : Bytes
    suffix = release ? 'm' : 'M'
    "\x1b[<#{button};#{x + 1};#{y + 1}#{suffix}".to_slice
  end

  private def self.collect_stream_events(reader : TerminalReader) : Array(Event)
    eventc = Channel(Event).new
    spawn do
      reader.stream_events(eventc)
      eventc.close
    end

    events = [] of Event
    while event = eventc.receive?
      events << event
    end
    events
  end

  describe "Go compatibility tests" do
    describe "TestSplitReads" do
      it "splits and decodes stream input like Go limited reader" do
        expected = [
          Key.new(code: 'a'.ord, text: "a"),
          Key.new(code: 'b'.ord, text: "b"),
          Key.new(code: 'c'.ord, text: "c"),
          Key.new(code: KeyUp),
          MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)),
          FocusEvent.new,
          MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)),
          BlurEvent.new,
          MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)),
          Key.new(code: KeyUp),
          MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)),
          MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)),
          FocusEvent.new,
          UnknownEvent.new("\x1b[12;34;9"),
        ] of Event

        inputs = [
          "abc",
          "\x1b[A",
          "\x1b[<0;33",
          ";17M",
          "\x1b[I",
          "\x1b",
          "[",
          "<",
          "0",
          ";",
          "3",
          "3",
          ";",
          "1",
          "7",
          "M",
          "\x1b[O",
          "\x1b",
          "]",
          "2",
          ";",
          "a",
          "b",
          "c",
          "\x1b",
          "\x1b[",
          "<0;3",
          "3;17M",
          "\x1b[A\x1b[",
          "<0;33;17M\x1b[",
          "<0;33;17M\x1b[I",
          "\x1b[12;34;9",
        ]

        reader = TerminalReader.new(ChunkedReader.new(inputs.join, 8), "dumb")
        eventc = Channel(Event).new
        spawn do
          reader.stream_events(eventc)
          eventc.close
        end

        events = [] of Event
        while event = eventc.receive?
          events << event
        end

        events.should eq(expected)
      end
    end

    describe "TestReadLongInput" do
      it "reads 1000 keypress events from a long stream" do
        reader = TerminalReader.new(IO::Memory.new("a" * 1000), "dumb")
        events = collect_stream_events(reader)

        events.size.should eq(1000)
        events.each do |event|
          event.should eq(Key.new(code: 'a'.ord, text: "a"))
        end
      end
    end

    describe "TestParseX10MouseDownEvent" do
      it "parses X10 mouse event cases from Go table" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        cases = [
          {name: "zero position", buf: encode_x10_mouse(0b0000_0000, 0, 0), expected: MouseClickEvent.new(Mouse.new(0, 0, MouseButton::Left)).as(Event)},
          {name: "max position", buf: encode_x10_mouse(0b0000_0000, 222, 222), expected: MouseClickEvent.new(Mouse.new(222, 222, MouseButton::Left)).as(Event)},
          {name: "left", buf: encode_x10_mouse(0b0000_0000, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)).as(Event)},
          {name: "left in motion", buf: encode_x10_mouse(0b0010_0000, 32, 16), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Left)).as(Event)},
          {name: "middle", buf: encode_x10_mouse(0b0000_0001, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Middle)).as(Event)},
          {name: "middle in motion", buf: encode_x10_mouse(0b0010_0001, 32, 16), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Middle)).as(Event)},
          {name: "right", buf: encode_x10_mouse(0b0000_0010, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right)).as(Event)},
          {name: "right in motion", buf: encode_x10_mouse(0b0010_0010, 32, 16), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Right)).as(Event)},
          {name: "motion", buf: encode_x10_mouse(0b0010_0011, 32, 16), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::None)).as(Event)},
          {name: "wheel up", buf: encode_x10_mouse(0b0100_0000, 32, 16), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelUp)).as(Event)},
          {name: "wheel down", buf: encode_x10_mouse(0b0100_0001, 32, 16), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown)).as(Event)},
          {name: "wheel left", buf: encode_x10_mouse(0b0100_0010, 32, 16), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelLeft)).as(Event)},
          {name: "wheel right", buf: encode_x10_mouse(0b0100_0011, 32, 16), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelRight)).as(Event)},
          {name: "release", buf: encode_x10_mouse(0b0000_0011, 32, 16), expected: MouseReleaseEvent.new(Mouse.new(32, 16, MouseButton::None)).as(Event)},
          {name: "backward", buf: encode_x10_mouse(0b1000_0000, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Backward)).as(Event)},
          {name: "forward", buf: encode_x10_mouse(0b1000_0001, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Forward)).as(Event)},
          {name: "button 10", buf: encode_x10_mouse(0b1000_0010, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Button10)).as(Event)},
          {name: "button 11", buf: encode_x10_mouse(0b1000_0011, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Button11)).as(Event)},
          {name: "alt+right", buf: encode_x10_mouse(0b0000_1010, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt)).as(Event)},
          {name: "ctrl+right", buf: encode_x10_mouse(0b0001_0010, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModCtrl)).as(Event)},
          {name: "left in motion", buf: encode_x10_mouse(0b0010_0000, 32, 16), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Left)).as(Event)},
          {name: "alt+right in motion", buf: encode_x10_mouse(0b0010_1010, 32, 16), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt)).as(Event)},
          {name: "ctrl+right in motion", buf: encode_x10_mouse(0b0011_0010, 32, 16), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Right, ModCtrl)).as(Event)},
          {name: "ctrl+alt+right", buf: encode_x10_mouse(0b0001_1010, 32, 16), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt | ModCtrl)).as(Event)},
          {name: "ctrl+wheel up", buf: encode_x10_mouse(0b0101_0000, 32, 16), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelUp, ModCtrl)).as(Event)},
          {name: "alt+wheel down", buf: encode_x10_mouse(0b0100_1001, 32, 16), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown, ModAlt)).as(Event)},
          {name: "ctrl+alt+wheel down", buf: encode_x10_mouse(0b0101_1001, 32, 16), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown, ModAlt | ModCtrl)).as(Event)},
          {name: "overflow position", buf: encode_x10_mouse(0b0010_0000, 250, 223), expected: MouseMotionEvent.new(Mouse.new(-6, -33, MouseButton::Left)).as(Event)},
        ]

        cases.each_with_index do |test_case, idx|
          _total, events = reader.scan_events_public(test_case[:buf], true)
          events.should eq([test_case[:expected]] of Event), "case #{idx + 1}: #{test_case[:name]}"
        end
      end
    end

    describe "TestParseSGRMouseEvent" do
      it "parses SGR mouse event cases from Go table" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        cases = [
          {name: "zero position", buf: encode_sgr_mouse(0, 0, 0, false), expected: MouseClickEvent.new(Mouse.new(0, 0, MouseButton::Left)).as(Event)},
          {name: "225 position", buf: encode_sgr_mouse(0, 225, 225, false), expected: MouseClickEvent.new(Mouse.new(225, 225, MouseButton::Left)).as(Event)},
          {name: "left", buf: encode_sgr_mouse(0, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)).as(Event)},
          {name: "left in motion", buf: encode_sgr_mouse(32, 32, 16, false), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Left)).as(Event)},
          {name: "left release", buf: encode_sgr_mouse(0, 32, 16, true), expected: MouseReleaseEvent.new(Mouse.new(32, 16, MouseButton::Left)).as(Event)},
          {name: "middle", buf: encode_sgr_mouse(1, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Middle)).as(Event)},
          {name: "middle in motion", buf: encode_sgr_mouse(33, 32, 16, false), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Middle)).as(Event)},
          {name: "middle release", buf: encode_sgr_mouse(1, 32, 16, true), expected: MouseReleaseEvent.new(Mouse.new(32, 16, MouseButton::Middle)).as(Event)},
          {name: "right", buf: encode_sgr_mouse(2, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right)).as(Event)},
          {name: "right release", buf: encode_sgr_mouse(2, 32, 16, true), expected: MouseReleaseEvent.new(Mouse.new(32, 16, MouseButton::Right)).as(Event)},
          {name: "motion", buf: encode_sgr_mouse(35, 32, 16, false), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::None)).as(Event)},
          {name: "wheel up", buf: encode_sgr_mouse(64, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelUp)).as(Event)},
          {name: "wheel down", buf: encode_sgr_mouse(65, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown)).as(Event)},
          {name: "wheel left", buf: encode_sgr_mouse(66, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelLeft)).as(Event)},
          {name: "wheel right", buf: encode_sgr_mouse(67, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelRight)).as(Event)},
          {name: "backward", buf: encode_sgr_mouse(128, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Backward)).as(Event)},
          {name: "backward in motion", buf: encode_sgr_mouse(160, 32, 16, false), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Backward)).as(Event)},
          {name: "forward", buf: encode_sgr_mouse(129, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Forward)).as(Event)},
          {name: "forward in motion", buf: encode_sgr_mouse(161, 32, 16, false), expected: MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Forward)).as(Event)},
          {name: "alt+right", buf: encode_sgr_mouse(10, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt)).as(Event)},
          {name: "ctrl+right", buf: encode_sgr_mouse(18, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModCtrl)).as(Event)},
          {name: "ctrl+alt+right", buf: encode_sgr_mouse(26, 32, 16, false), expected: MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt | ModCtrl)).as(Event)},
          {name: "alt+wheel", buf: encode_sgr_mouse(73, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown, ModAlt)).as(Event)},
          {name: "ctrl+wheel", buf: encode_sgr_mouse(81, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown, ModCtrl)).as(Event)},
          {name: "ctrl+alt+wheel", buf: encode_sgr_mouse(89, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown, ModAlt | ModCtrl)).as(Event)},
          {name: "ctrl+alt+shift+wheel", buf: encode_sgr_mouse(93, 32, 16, false), expected: MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown, ModAlt | ModShift | ModCtrl)).as(Event)},
        ]

        cases.each_with_index do |test_case, idx|
          _total, events = reader.scan_events_public(test_case[:buf], true)
          events.should eq([test_case[:expected]] of Event), "case #{idx + 1}: #{test_case[:name]}"
        end
      end
    end

    describe "TestSplitSequences" do
      it "parses OSC 11 split with ST terminator" do
        reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b]11;rgb:1a1a/1b1b/2c2c".to_slice,
          "\x1b\\".to_slice,
        ]), "xterm-256color")
        collect_stream_events(reader).should eq([
          BackgroundColorEvent.new(uv_color("rgb:1a1a/1b1b/2c2c")),
        ])
      end

      it "parses OSC 11 split with BEL terminator" do
        reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b]11;rgb:1a1a/1b1b/2c2c".to_slice,
          "\a".to_slice,
        ]), "xterm-256color")
        collect_stream_events(reader).should eq([
          BackgroundColorEvent.new(uv_color("rgb:1a1a/1b1b/2c2c")),
        ])
      end

      it "parses DCS and APC sequences split across reads" do
        dcs_reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1bP1$r".to_slice,
          "test\x1b\\".to_slice,
        ]), "xterm-256color")
        collect_stream_events(dcs_reader).should eq([
          UnknownDcsEvent.new("\x1bP1$rtest\x1b\\"),
        ])

        apc_reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b_T".to_slice,
          "test\x1b\\".to_slice,
        ]), "xterm-256color")
        collect_stream_events(apc_reader).should eq([
          UnknownApcEvent.new("\x1b_Ttest\x1b\\"),
        ])
      end

      it "parses OSC 10 foreground color split" do
        reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b]10;rgb:ffff/0000/".to_slice,
          "0000\x1b\\".to_slice,
        ]), "xterm-256color")
        collect_stream_events(reader).should eq([
          ForegroundColorEvent.new(uv_color("rgb:ffff/0000/0000")),
        ])
      end

      it "parses OSC 12 cursor color split" do
        reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b]12;rgb:".to_slice,
          "8080/8080/8080\a".to_slice,
        ]), "xterm-256color")
        collect_stream_events(reader).should eq([
          CursorColorEvent.new(uv_color("rgb:8080/8080/8080")),
        ])
      end

      it "parses long DCS split with read limit" do
        prefix = "\x1bP1$r" + ("a" * 258) + "abcdef"
        suffix = "test\x1b\\"
        reader = TerminalReader.new(ChunkSequenceReader.new([
          prefix.to_slice,
          suffix.to_slice,
        ], limit: 256), "xterm-256color")
        collect_stream_events(reader).should eq([
          UnknownDcsEvent.new(prefix + suffix),
        ])
      end

      it "parses OSC across multiple chunks" do
        reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b]11;".to_slice,
          "rgb:1234/".to_slice,
          "5678/9abc\a".to_slice,
        ]), "xterm-256color")
        collect_stream_events(reader).should eq([
          BackgroundColorEvent.new(uv_color("rgb:1234/5678/9abc")),
        ])
      end

      it "handles OSC followed by regular key" do
        reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b]11;rgb:1111/2222/3333".to_slice,
          "\ax".to_slice,
        ]), "xterm-256color")
        collect_stream_events(reader).should eq([
          BackgroundColorEvent.new(uv_color("rgb:1111/2222/3333")),
          Key.new(code: 'x'.ord, text: "x"),
        ])
      end

      it "emits unknown event after esc timeout when sequence stays unterminated" do
        reader = TerminalReader.new(ChunkSequenceReader.new([
          "\x1b]11;rgb:1111/2222/3333".to_slice,
          "abc".to_slice,
          "x".to_slice,
          "x".to_slice,
          "x".to_slice,
          "x".to_slice,
        ], delay: 60.milliseconds), "xterm-256color")
        collect_stream_events(reader).should eq([
          UnknownEvent.new("\x1b]11;rgb:1111/2222/3333"),
          Key.new(code: 'a'.ord, text: "a"),
          Key.new(code: 'b'.ord, text: "b"),
          Key.new(code: 'c'.ord, text: "c"),
          Key.new(code: 'x'.ord, text: "x"),
          Key.new(code: 'x'.ord, text: "x"),
          Key.new(code: 'x'.ord, text: "x"),
          Key.new(code: 'x'.ord, text: "x"),
        ])
      end

      it "parses many broken-down down-arrow sequences across chunk boundaries" do
        chunks = [
          "\x1b[B",
          "\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B",
          "\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[",
          "B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b",
          "[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B\x1b[B",
        ]
        all_input = chunks.join
        expected_count = all_input.scan(/\x1b\[B/).size
        expected = Array(Event).new(expected_count) { Key.new(code: KeyDown).as(Event) }
        reader = TerminalReader.new(ChunkSequenceReader.new(chunks.map(&.to_slice)), "xterm-256color")
        collect_stream_events(reader).should eq(expected)
      end
    end

    describe "TestReadInput" do
      it "non-serialized single win32 esc" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b], true)
        events.should eq([
          Key.new(code: KeyEscape),
        ])
      end

      it "serialized win32 esc" do
        input = "\x1b[27;0;27;1;0;1_abc\x1b[0;0;55357;1;0;1_\x1b[0;0;56835;1;0;1_ ".to_slice
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          Key.new(code: KeyEscape, base_code: KeyEscape),
          Key.new(code: 'a'.ord, text: "a"),
          Key.new(code: 'b'.ord, text: "b"),
          Key.new(code: 'c'.ord, text: "c"),
          Key.new(code: 128515, text: "😃"),
          Key.new(code: KeySpace, text: " "),
        ])
      end

      it "ignored osc" do
        input = "\x1b]11;#123456\x18\x1b]11;#123456\x1a\x1b]11;#123456\x1b".to_slice
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([] of Event)
      end

      it "ignored apc" do
        input = "\x9f\x9c\x1b_hello\x1b\x1b_hello\x18\x1b_abc\x1b\\\x1ba".to_slice
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          UnknownApcEvent.new("\x9f\x9c"),
          UnknownApcEvent.new("\x1b_abc\x1b\\"),
          Key.new(code: 'a'.ord, mod: ModAlt),
        ])
      end

      it "alt+] alt+'" do
        input = "\x1b]\x1b'".to_slice
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          Key.new(code: ']'.ord, mod: ModAlt),
          Key.new(code: '\''.ord, mod: ModAlt),
        ])
      end

      it "alt+^ alt+&" do
        input = "\x1b^\x1b&".to_slice
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          Key.new(code: '^'.ord, mod: ModAlt),
          Key.new(code: '&'.ord, mod: ModAlt),
        ])
      end

      it "a" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes['a'.ord], true)
        events.should eq([
          Key.new(code: 'a'.ord, text: "a"),
        ])
      end

      it "space" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[' '.ord], true)
        events.should eq([
          Key.new(code: KeySpace, text: " "),
        ])
      end

      it "a alt+a" do
        input = Bytes['a'.ord, 0x1b, 'a'.ord]
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          Key.new(code: 'a'.ord, text: "a"),
          Key.new(code: 'a'.ord, mod: ModAlt),
        ])
      end

      it "a alt+a a" do
        input = Bytes['a'.ord, 0x1b, 'a'.ord, 'a'.ord]
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          Key.new(code: 'a'.ord, text: "a"),
          Key.new(code: 'a'.ord, mod: ModAlt),
          Key.new(code: 'a'.ord, text: "a"),
        ])
      end

      it "ctrl+a" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x01], true)
        events.should eq([
          Key.new(code: 'a'.ord, mod: ModCtrl),
        ])
      end

      it "ctrl+a ctrl+b" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x01, 0x02], true)
        events.should eq([
          Key.new(code: 'a'.ord, mod: ModCtrl),
          Key.new(code: 'b'.ord, mod: ModCtrl),
        ])
      end

      it "alt+a" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b, 'a'.ord], true)
        events.should eq([
          Key.new(code: 'a'.ord, mod: ModAlt),
        ])
      end

      it "a b c d" do
        input = Bytes['a'.ord, 'b'.ord, 'c'.ord, 'd'.ord]
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          Key.new(code: 'a'.ord, text: "a"),
          Key.new(code: 'b'.ord, text: "b"),
          Key.new(code: 'c'.ord, text: "c"),
          Key.new(code: 'd'.ord, text: "d"),
        ])
      end

      it "up" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1b[A".to_slice, true)
        events.should eq([
          Key.new(code: KeyUp),
        ])
      end

      it "wheel up" do
        input = Bytes[0x1b, '['.ord, 'M'.ord, 0x60, 0x41, 0x31]
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelUp)),
        ])
      end

      it "left motion release" do
        input = Bytes[
          0x1b, '['.ord, 'M'.ord, 0x40, 0x41, 0x31,
          0x1b, '['.ord, 'M'.ord, 0x23, 0x61, 0x41,
        ]
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Left)),
          MouseReleaseEvent.new(Mouse.new(64, 32, MouseButton::None)),
        ])
      end

      it "shift+tab" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1b[Z".to_slice, true)
        events.should eq([
          Key.new(code: KeyTab, mod: ModShift),
        ])
      end

      it "enter" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes['\r'.ord], true)
        events.should eq([
          Key.new(code: KeyEnter),
        ])
      end

      it "alt+enter" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b, '\r'.ord], true)
        events.should eq([
          Key.new(code: KeyEnter, mod: ModAlt),
        ])
      end

      it "insert" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1b[2~".to_slice, true)
        events.should eq([
          Key.new(code: KeyInsert),
        ])
      end

      it "ctrl+alt+a" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b, 0x01], true)
        events.should eq([
          Key.new(code: 'a'.ord, mod: ModCtrl | ModAlt),
        ])
      end

      it "CSI?----X?" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1b[-----X".to_slice, true)
        events.should eq([
          UnknownCsiEvent.new("\x1b[-----X"),
        ])
      end

      it "up" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1bOA".to_slice, true)
        events.should eq([
          Key.new(code: KeyUp),
        ])
      end

      it "down" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1bOB".to_slice, true)
        events.should eq([
          Key.new(code: KeyDown),
        ])
      end

      it "right" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1bOC".to_slice, true)
        events.should eq([
          Key.new(code: KeyRight),
        ])
      end

      it "left" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public("\x1bOD".to_slice, true)
        events.should eq([
          Key.new(code: KeyLeft),
        ])
      end

      it "alt+enter" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b, 0x0d], true)
        events.should eq([
          Key.new(code: KeyEnter, mod: ModAlt),
        ])
      end

      it "alt+backspace" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b, 0x7f], true)
        events.should eq([
          Key.new(code: KeyBackspace, mod: ModAlt),
        ])
      end

      it "ctrl+space" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x00], true)
        events.should eq([
          Key.new(code: KeySpace, mod: ModCtrl),
        ])
      end

      it "ctrl+alt+space" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b, 0x00], true)
        events.should eq([
          Key.new(code: KeySpace, mod: ModCtrl | ModAlt),
        ])
      end

      it "esc" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b], true)
        events.should eq([
          Key.new(code: KeyEscape),
        ])
      end

      it "alt+esc" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0x1b, 0x1b], true)
        events.should eq([
          Key.new(code: KeyEscape, mod: ModAlt),
        ])
      end

      it "a b o" do
        input = "\x1b[200~a b\x1b[201~o".to_slice
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          PasteStartEvent.new,
          PasteEvent.new("a b"),
          PasteEndEvent.new,
          Key.new(code: 'o'.ord, text: "o"),
        ])
      end

      it "a\x03\nb" do
        input = "\x1b[200~a\x03\nb\x1b[201~".to_slice
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          PasteStartEvent.new,
          PasteEvent.new("a\x03\nb"),
          PasteEndEvent.new,
        ])
      end

      it "?0xfe?" do
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(Bytes[0xfe], true)
        events.should eq([
          UnknownEvent.new(0xfe.chr.to_s),
        ])
      end

      it "a ?0xfe?   b" do
        input = Bytes['a'.ord, 0xfe, ' '.ord, 'b'.ord]
        reader = TestTerminalReader.new(IO::Memory.new, "dumb")
        _total, events = reader.scan_events_public(input, true)
        events.should eq([
          Key.new(code: 'a'.ord, text: "a"),
          UnknownEvent.new(0xfe.chr.to_s),
          Key.new(code: KeySpace, text: " "),
          Key.new(code: 'b'.ord, text: "b"),
        ])
      end
    end
  end
end
