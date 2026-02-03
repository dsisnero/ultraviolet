require "./spec_helper"

module DecoderSpecHelper
  def self.decode_all_signatures(data : Bytes, decoder : Ultraviolet::EventDecoder) : Array(String)
    signatures = [] of String
    buf = data
    until buf.empty?
      n, event = decoder.decode(buf)
      break if n == 0
      if event
        if event.is_a?(Array(Int32))
          signatures << event_signature(event)
        elsif event.is_a?(Array)
          event.each { |event_item| signatures << event_signature(event_item) }
        else
          signatures << event_signature(event)
        end
      end
      buf = buf[n..]
    end
    signatures
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def self.event_signature(event) : String
    case event
    when Ultraviolet::Key
      key_signature(event)
    when Ultraviolet::CursorPositionEvent
      "CursorPosition(y=#{event.y} x=#{event.x})"
    when Ultraviolet::ModeReportEvent
      "ModeReport(mode=#{event.mode} value=#{event.value})"
    when Ultraviolet::ModifyOtherKeysEvent
      "ModifyOtherKeys(mode=#{event.mode})"
    when Ultraviolet::KeyboardEnhancementsEvent
      "KeyboardEnhancements(flags=#{event.flags})"
    when Ultraviolet::TerminalVersionEvent
      "TerminalVersion(name=#{event.name.inspect})"
    when Ultraviolet::ForegroundColorEvent
      "ForegroundColor(#{event.string})"
    when Ultraviolet::BackgroundColorEvent
      "BackgroundColor(#{event.string})"
    when Ultraviolet::CursorColorEvent
      "CursorColor(#{event.string})"
    when Ultraviolet::WindowOpEvent
      "WindowOp(op=#{event.op} args=#{event.args.inspect})"
    when Ultraviolet::CapabilityEvent
      "Capability(#{event.content.inspect})"
    when Ultraviolet::ClipboardEvent
      "Clipboard(content=#{event.content.inspect} selection=#{event.selection})"
    when Ultraviolet::PasteEvent
      "Paste(#{event.content.inspect})"
    when Ultraviolet::PasteStartEvent
      "PasteStart"
    when Ultraviolet::PasteEndEvent
      "PasteEnd"
    when Ultraviolet::FocusEvent
      "Focus"
    when Ultraviolet::BlurEvent
      "Blur"
    when Ultraviolet::DarkColorSchemeEvent
      "DarkColorScheme"
    when Ultraviolet::LightColorSchemeEvent
      "LightColorScheme"
    when Ultraviolet::KittyGraphicsEvent
      "KittyGraphics(options=#{event.options.inspect} payload_size=#{event.payload.size})"
    when Ultraviolet::Mouse
      "Mouse(x=#{event.x} y=#{event.y} button=#{event.button} mod=#{event.mod})"
    when Ultraviolet::UnknownEvent
      "Unknown(#{event.value.inspect})"
    when Ultraviolet::UnknownCsiEvent
      "UnknownCsi(#{event.value.inspect})"
    when Ultraviolet::UnknownSs3Event
      "UnknownSs3(#{event.value.inspect})"
    when Ultraviolet::UnknownOscEvent
      "UnknownOsc(#{event.value.inspect})"
    when Ultraviolet::UnknownDcsEvent
      "UnknownDcs(#{event.value.inspect})"
    when Ultraviolet::UnknownSosEvent
      "UnknownSos(#{event.value.inspect})"
    when Ultraviolet::UnknownPmEvent
      "UnknownPm(#{event.value.inspect})"
    when Ultraviolet::UnknownApcEvent
      "UnknownApc(#{event.value.inspect})"
    when Array(Int32)
      "DeviceAttributes=#{event.inspect}"
    when String
      "StringEvent=#{event.inspect}"
    else
      event.to_s
    end
  end

  # ameba:enable Metrics/CyclomaticComplexity

  def self.key_signature(key : Ultraviolet::Key) : String
    "Key(code=#{key.code} mod=#{key.mod} text=#{key.text.inspect} base=#{key.base_code} shifted=#{key.shifted_code} repeat=#{key.is_repeat?})"
  end

  def self.build_base_seq_tests : Array(NamedTuple(seq: Bytes, events: Array(String)))
    sequences = Ultraviolet.build_keys_table(Ultraviolet::LegacyKeyEncoding.new, "dumb", true)
    tests = [] of NamedTuple(seq: Bytes, events: Array(String))
    f3_regex = /\e\[1;(\d+)R/

    sequences.each do |seq, key|
      events = [key_signature(key)]
      if f3_regex.matches?(seq)
        events = [key_signature(key), event_signature(Ultraviolet::CursorPositionEvent.new(0, key.mod))]
      end
      tests << {seq: seq.to_slice, events: events}
    end

    tests << {
      seq:    Bytes['\e'.ord.to_u8, '['.ord.to_u8, '-'.ord.to_u8, '-'.ord.to_u8, '-'.ord.to_u8, '-'.ord.to_u8, 'X'.ord.to_u8],
      events: [event_signature(Ultraviolet::UnknownCsiEvent.new("\e[----X"))],
    }
    tests << {
      seq:    Bytes[' '.ord.to_u8],
      events: [key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeySpace, text: " "))],
    }
    tests << {
      seq:    Bytes['\e'.ord.to_u8, ' '.ord.to_u8],
      events: [key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeySpace, mod: Ultraviolet::ModAlt))],
    }

    tests
  end
end

describe "EventDecoder" do
  it "parses sequences" do
    decoder = Ultraviolet::EventDecoder.new
    tests = DecoderSpecHelper.build_base_seq_tests

    tests << {
      seq:    "\e]11;rgb:ffff/0000/ffff\a".to_slice,
      events: [DecoderSpecHelper.event_signature(Ultraviolet::BackgroundColorEvent.new(Ultraviolet::Ansi.x_parse_color("rgb:ff/00/ff")))],
    }

    tests << {
      seq:    "\eP!|4368726d\e\\".to_slice,
      events: [DecoderSpecHelper.event_signature("Chrm")],
    }

    tests << {
      seq:    "\eP1+r524742\e\\".to_slice,
      events: [DecoderSpecHelper.event_signature(Ultraviolet::CapabilityEvent.new("RGB"))],
    }

    tests << {
      seq:    "\e[z\eOz\eO2 \eP?1;2:3+zABC\e\\".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[z")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownSs3Event.new("\eOz")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownEvent.new("\eO2")),
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeySpace, text: " ")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownDcsEvent.new("\eP?1;2:3+zABC\e\\")),
      ],
    }

    tests << {
      seq:    "\e]52\e\\\e]52;c;!\e\\\e]52;c;aGk=\e\\".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::ClipboardEvent.new),
        DecoderSpecHelper.event_signature(Ultraviolet::ClipboardEvent.new("!", 'c')),
        DecoderSpecHelper.event_signature(Ultraviolet::ClipboardEvent.new("hi", 'c')),
      ],
    }

    tests << {
      seq:    "\e[27;3~".to_slice,
      events: [DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[27;3~"))],
    }

    tests << {
      seq:    "\e[@\e[^\e[~".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[@")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[^")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[~")),
      ],
    }

    tests << {
      seq:    "\e[65;0;97;1;0;1_\e[0;0;0_".to_slice,
      events: [
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: 'a'.ord, base_code: 'a'.ord, text: "a")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[0;0;0_")),
      ],
    }

    tests << {
      seq:    "\e[2;1$y\e[$y\e[2$y\e[2;$y".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::ModeReportEvent.new(Ultraviolet::Ansi::KeyboardActionMode, Ultraviolet::Ansi::ModeSet)),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[$y")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[2$y")),
        DecoderSpecHelper.event_signature(Ultraviolet::ModeReportEvent.new(Ultraviolet::Ansi::KeyboardActionMode, Ultraviolet::Ansi::ModeNotRecognized)),
      ],
    }

    tests << {
      seq:    "\e[M !".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[M")),
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: ' '.ord, text: " ")),
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: '!'.ord, text: "!")),
      ],
    }

    tests << {
      seq:    "\e[?$y\e[?1049$y\e[?1049;$y".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[?$y")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[?1049$y")),
        DecoderSpecHelper.event_signature(Ultraviolet::ModeReportEvent.new(Ultraviolet::Ansi::AltScreenSaveCursorMode, Ultraviolet::Ansi::ModeNotRecognized)),
      ],
    }

    tests << {
      seq:    "\e[>4;1m\e[>4m\e[>3m".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::ModifyOtherKeysEvent.new(1)),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[>4m")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[>3m")),
      ],
    }

    tests << {
      seq:    "\e[1;5R\e[1;5;7R".to_slice,
      events: [
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeyF3, mod: Ultraviolet::ModCtrl)),
        DecoderSpecHelper.event_signature(Ultraviolet::CursorPositionEvent.new(0, 4)),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[1;5;7R")),
      ],
    }

    tests << {
      seq:    "\e[?12;34R\e[?14R".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::CursorPositionEvent.new(11, 33)),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[?14R")),
      ],
    }

    tests << {
      seq:    "\e[10;2;3c".to_slice,
      events: [DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[10;2;3c"))],
    }

    tests << {
      seq:    "\e[?16u\e[?u".to_slice,
      events: [
        DecoderSpecHelper.event_signature(Ultraviolet::KeyboardEnhancementsEvent.new(16)),
        DecoderSpecHelper.event_signature(Ultraviolet::KeyboardEnhancementsEvent.new(0)),
      ],
    }

    tests << {
      seq:    "\e[>1;2;3c".to_slice,
      events: [DecoderSpecHelper.event_signature([1, 2, 3])],
    }

    tests << {
      seq:    "\e[?1;2;3c".to_slice,
      events: [DecoderSpecHelper.event_signature([1, 2, 3])],
    }

    tests << {
      seq:    "\e\e[?2004;1$y".to_slice,
      events: [
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeyEscape)),
        DecoderSpecHelper.event_signature(Ultraviolet::ModeReportEvent.new(Ultraviolet::Ansi::BracketedPasteMode, Ultraviolet::Ansi::ModeSet)),
      ],
    }

    tests << {
      seq:    ("\x9bA" + "\x8fA" + "\x90>|Ultraviolet\e\\" + "\x9d11;#123456\x9c" + "\x98hi\x9c" + "\x9fhello\x9c" + "\x9ebye\x9c").to_slice,
      events: [
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeyUp)),
        DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeyUp)),
        DecoderSpecHelper.event_signature(Ultraviolet::TerminalVersionEvent.new("Ultraviolet")),
        DecoderSpecHelper.event_signature(Ultraviolet::BackgroundColorEvent.new(Ultraviolet::Ansi.x_parse_color("#123456"))),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownSosEvent.new("\x98hi\x9c")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownApcEvent.new("\x9fhello\x9c")),
        DecoderSpecHelper.event_signature(Ultraviolet::UnknownPmEvent.new("\x9ebye\x9c")),
      ],
    }

    tests << {
      seq:    Bytes.empty,
      events: [] of String,
    }

    tests << {
      seq:    "\e[".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: '['.ord, mod: Ultraviolet::ModAlt))],
    }

    tests << {
      seq:    "\e]".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: ']'.ord, mod: Ultraviolet::ModAlt))],
    }

    tests << {
      seq:    "\e^".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: '^'.ord, mod: Ultraviolet::ModAlt))],
    }

    tests << {
      seq:    "\e_".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: '_'.ord, mod: Ultraviolet::ModAlt))],
    }

    tests << {
      seq:    "\eP".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: 'p'.ord, mod: Ultraviolet::ModShift | Ultraviolet::ModAlt))],
    }

    tests << {
      seq:    "\eX".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: 'x'.ord, mod: Ultraviolet::ModShift | Ultraviolet::ModAlt))],
    }

    tests << {
      seq:    "\eO".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: 'o'.ord, mod: Ultraviolet::ModShift | Ultraviolet::ModAlt))],
    }

    tests << {
      seq:    "\e".to_slice,
      events: [DecoderSpecHelper.key_signature(Ultraviolet::Key.new(code: Ultraviolet::KeyEscape))],
    }

    tests << {
      seq:    "\e[u".to_slice,
      events: [DecoderSpecHelper.event_signature(Ultraviolet::UnknownCsiEvent.new("\e[u"))],
    }

    tests.each_with_index do |test_case, index|
      decoded = DecoderSpecHelper.decode_all_signatures(test_case[:seq], decoder)
      decoded.should eq(test_case[:events]), "case #{index + 1}"
    end
  end
end
