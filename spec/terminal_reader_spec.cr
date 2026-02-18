require "./spec_helper"

module Ultraviolet
  private class TestTerminalReader < TerminalReader
    def scan_events_public(buf : Bytes, expired : Bool)
      scan_events(buf, expired)
    end

    def control_char_public(code : Int32) : Bool
      control_char?(code)
    end

    def encode_grapheme_bufs_public : Bytes
      encode_grapheme_bufs
    end

    def store_grapheme_rune_public(kd : Int32, code : Int32) : Nil
      store_grapheme_rune(kd, code)
    end
  end

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

    it "detects control characters like Go's unicode.IsControl" do
      reader = TestTerminalReader.new(IO::Memory.new, "xterm-256color")
      # ASCII control characters (C0)
      (0x00..0x1F).each do |code|
        reader.control_char_public(code).should be_true
      end
      reader.control_char_public(0x7F).should be_true # DEL
      # C1 control characters (U+0080..U+009F)
      (0x80..0x9F).each do |code|
        reader.control_char_public(code).should be_true
      end
      # Some non-control characters
      reader.control_char_public('a'.ord).should be_false
      reader.control_char_public(' '.ord).should be_false
      reader.control_char_public(0x00A0).should be_false # non-breaking space
      # Surrogates are not control characters
      (0xD800..0xDFFF).each do |code|
        reader.control_char_public(code).should be_false
      end
    end

    it "emits bracketed paste events" do
      reader = TestTerminalReader.new(IO::Memory.new, "xterm-256color")
      bytes = Bytes[
        27, 91, 50, 48, 48, 126,
        97, 32, 98,
        27, 91, 50, 48, 49, 126,
        111,
      ]
      _total, events = reader.scan_events_public(bytes, true)
      events.should eq([
        PasteStartEvent.new,
        PasteEvent.new("a b"),
        PasteEndEvent.new,
        Key.new(code: 'o'.ord, text: "o"),
      ])
    end

    it "handles win32 serialized input with surrogate pairs" do
      reader = TestTerminalReader.new(IO::Memory.new, "xterm-256color")
      # Go test case: "serialized win32 esc"
      # bytes: \x1b[27;0;27;1;0;1_abc\x1b[0;0;55357;1;0;1_\x1b[0;0;56835;1;0;1_
      bytes = Bytes[
        0x1b, 0x5b, 0x32, 0x37, 0x3b, 0x30, 0x3b, 0x32, 0x37, 0x3b, 0x31, 0x3b, 0x30, 0x3b, 0x31, 0x5f,
        0x61, 0x62, 0x63,
        0x1b, 0x5b, 0x30, 0x3b, 0x30, 0x3b, 0x35, 0x35, 0x33, 0x35, 0x37, 0x3b, 0x31, 0x3b, 0x30, 0x3b, 0x31, 0x5f,
        0x1b, 0x5b, 0x30, 0x3b, 0x30, 0x3b, 0x35, 0x36, 0x38, 0x33, 0x35, 0x3b, 0x31, 0x3b, 0x30, 0x3b, 0x31, 0x5f,
        0x20,
      ]
      _total, events = reader.scan_events_public(bytes, true)
      # Expected events per Go test:
      # KeyPressEvent{Code: KeyEscape, BaseCode: KeyEscape},
      # KeyPressEvent{Code: 'a', Text: "a"},
      # KeyPressEvent{Code: 'b', Text: "b"},
      # KeyPressEvent{Code: 'c', Text: "c"},
      # KeyPressEvent{Code: 128515, Text: "😃"},
      # KeyPressEvent{Code: KeySpace, Text: " "},
      events.should eq([
        Key.new(code: KeyEscape, base_code: KeyEscape),
        Key.new(code: 'a'.ord, text: "a"),
        Key.new(code: 'b'.ord, text: "b"),
        Key.new(code: 'c'.ord, text: "c"),
        Key.new(code: 128515, text: "😃"),
        Key.new(code: KeySpace, text: " "),
      ])
    end

    it "handles non-serialized single win32 esc" do
      reader = TestTerminalReader.new(IO::Memory.new, "xterm-256color")
      # Go test case: "non-serialized single win32 esc"
      bytes = Bytes[0x1b] # just ESC
      _total, events = reader.scan_events_public(bytes, true)
      events.should eq([
        Key.new(code: KeyEscape),
      ])
    end
  end
end
