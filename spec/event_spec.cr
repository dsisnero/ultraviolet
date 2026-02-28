require "./spec_helper"

describe "Event types" do
  it "renders unknown event strings" do
    tests = [
      {Ultraviolet::UnknownEvent.new("test"), %("test")},
      {Ultraviolet::UnknownCsiEvent.new("csi"), %("csi")},
      {Ultraviolet::UnknownSs3Event.new("ss3"), %("ss3")},
      {Ultraviolet::UnknownOscEvent.new("osc"), %("osc")},
      {Ultraviolet::UnknownDcsEvent.new("dcs"), %("dcs")},
      {Ultraviolet::UnknownSosEvent.new("sos"), %("sos")},
      {Ultraviolet::UnknownPmEvent.new("pm"), %("pm")},
      {Ultraviolet::UnknownApcEvent.new("apc"), %("apc")},
    ]

    tests.each do |event, expected|
      event.string.should eq(expected)
    end
  end

  it "renders multi-event strings" do
    events = [
      Ultraviolet::Key.new(code: 'a'.ord, base_code: 'a'.ord),
      Ultraviolet::Key.new(code: 'b'.ord, base_code: 'b'.ord),
      Ultraviolet::Key.new(code: 'c'.ord, base_code: 'c'.ord),
    ] of Ultraviolet::EventSingle

    Ultraviolet.multi_event_string(events).should eq("a\nb\nc\n")
  end

  it "provides size bounds" do
    size = Ultraviolet::Size.new(80, 24)
    size.bounds.min.x.should eq(0)
    size.bounds.min.y.should eq(0)
    size.bounds.max.x.should eq(80)
    size.bounds.max.y.should eq(24)

    window = Ultraviolet::WindowSizeEvent.new(100, 50)
    window.bounds.max.x.should eq(100)
    window.bounds.max.y.should eq(50)

    pixels = Ultraviolet::PixelSizeEvent.new(1920, 1080)
    pixels.bounds.max.x.should eq(1920)
    pixels.bounds.max.y.should eq(1080)

    cell = Ultraviolet::CellSizeEvent.new(10, 20)
    cell.bounds.max.x.should eq(10)
    cell.bounds.max.y.should eq(20)
  end

  it "supports key event helpers" do
    key = Ultraviolet::Key.new(code: 'a'.ord, base_code: 'a'.ord, mod: Ultraviolet::ModCtrl)
    key.match_string("ctrl+a").should be_true
    key.match_string("ctrl+b").should be_false
    key.match_string("ctrl+b", "ctrl+a", "ctrl+c").should be_true
    key.match_string("ctrl+b", "ctrl+c").should be_false
    key.string.should eq("ctrl+a")
    key.keystroke.should eq("ctrl+a")
    key.key.should eq(key)

    key2 = Ultraviolet::Key.new(code: 'b'.ord, base_code: 'b'.ord, mod: Ultraviolet::ModAlt)
    key2.match_string("alt+b").should be_true
    key2.match_string("alt+a").should be_false
    key2.string.should eq("alt+b")
    key2.keystroke.should eq("alt+b")
    key2.key.should eq(key2)
  end

  it "supports mouse event helpers" do
    mouse = Ultraviolet::Mouse.new(10, 20, Ultraviolet::MouseButton::Left)
    modded_mouse = Ultraviolet::Mouse.new(30, 40, Ultraviolet::MouseButton::Right, Ultraviolet::ModShift)

    click = Ultraviolet::MouseClickEvent.new(mouse)
    click.string.should eq("left")
    click.mouse.should eq(mouse)
    click.x.should eq(10)
    click.y.should eq(20)
    click.button.should eq(Ultraviolet::MouseButton::Left)

    release = Ultraviolet::MouseReleaseEvent.new(mouse)
    release.string.should eq("left")
    release.mouse.should eq(mouse)
    release.x.should eq(10)
    release.y.should eq(20)
    release.button.should eq(Ultraviolet::MouseButton::Left)

    wheel = Ultraviolet::MouseWheelEvent.new(Ultraviolet::Mouse.new(10, 20, Ultraviolet::MouseButton::WheelUp))
    wheel.string.should eq("wheelup")
    wheel.mouse.button.should eq(Ultraviolet::MouseButton::WheelUp)
    wheel.x.should eq(10)
    wheel.y.should eq(20)
    wheel.button.should eq(Ultraviolet::MouseButton::WheelUp)

    motion = Ultraviolet::MouseMotionEvent.new(mouse)
    motion.string.should eq("left+motion")
    motion.x.should eq(10)
    motion.y.should eq(20)
    motion.button.should eq(Ultraviolet::MouseButton::Left)

    motion2 = Ultraviolet::MouseMotionEvent.new(Ultraviolet::Mouse.new(10, 20, Ultraviolet::MouseButton::None))
    motion2.string.should eq("motion")
    motion2.button.should eq(Ultraviolet::MouseButton::None)

    modded = Ultraviolet::MouseClickEvent.new(modded_mouse)
    modded.mod.should eq(Ultraviolet::ModShift)
  end

  it "matches TestMouseEvent_String from Go" do
    tests = [
      {name: "unknown", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton.new(0xff))), expected: "unknown"},
      {name: "left", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left)), expected: "left"},
      {name: "right", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Right)), expected: "right"},
      {name: "middle", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Middle)), expected: "middle"},
      {name: "release", event: Ultraviolet::MouseReleaseEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::None)), expected: ""},
      {name: "wheelup", event: Ultraviolet::MouseWheelEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::WheelUp)), expected: "wheelup"},
      {name: "wheeldown", event: Ultraviolet::MouseWheelEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::WheelDown)), expected: "wheeldown"},
      {name: "wheelleft", event: Ultraviolet::MouseWheelEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::WheelLeft)), expected: "wheelleft"},
      {name: "wheelright", event: Ultraviolet::MouseWheelEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::WheelRight)), expected: "wheelright"},
      {name: "motion", event: Ultraviolet::MouseMotionEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::None)), expected: "motion"},
      {name: "shift+left release", event: Ultraviolet::MouseReleaseEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left, mod: Ultraviolet::ModShift)), expected: "shift+left"},
      {name: "shift+left", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left, mod: Ultraviolet::ModShift)), expected: "shift+left"},
      {name: "ctrl+shift+left", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left, mod: Ultraviolet::ModCtrl | Ultraviolet::ModShift)), expected: "ctrl+shift+left"},
      {name: "alt+left", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left, mod: Ultraviolet::ModAlt)), expected: "alt+left"},
      {name: "ctrl+left", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left, mod: Ultraviolet::ModCtrl)), expected: "ctrl+left"},
      {name: "ctrl+alt+left", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left, mod: Ultraviolet::ModAlt | Ultraviolet::ModCtrl)), expected: "ctrl+alt+left"},
      {name: "ctrl+alt+shift+left", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton::Left, mod: Ultraviolet::ModAlt | Ultraviolet::ModCtrl | Ultraviolet::ModShift)), expected: "ctrl+alt+shift+left"},
      {name: "ignore coordinates", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(x: 100, y: 200, button: Ultraviolet::MouseButton::Left)), expected: "left"},
      {name: "broken type", event: Ultraviolet::MouseClickEvent.new(Ultraviolet::Mouse.new(button: Ultraviolet::MouseButton.new(120))), expected: "unknown"},
    ]

    tests.each do |test_case|
      test_case[:event].string.should eq(test_case[:expected]), test_case[:name]
    end
  end

  it "supports kitty enhancements flags" do
    event = Ultraviolet::KeyboardEnhancementsEvent.new(0b111)
    event.contains?(0b001).should be_true
    event.contains?(0b011).should be_true
    event.contains?(0b111).should be_true
    event.contains?(0b1000).should be_false
    event.contains?(0b1011).should be_false
    event.supports_event_types?.should be_true
    event.supports_event_types.should be_true
  end

  it "supports color event helpers" do
    red = Ultraviolet::Color.new(255_u8, 0_u8, 0_u8)
    black = Ultraviolet::Color.new(0_u8, 0_u8, 0_u8)
    white = Ultraviolet::Color.new(255_u8, 255_u8, 255_u8)

    fg = Ultraviolet::ForegroundColorEvent.new(red)
    fg.string.should eq("#ff0000")
    fg.dark?.should be_false
    Ultraviolet::ForegroundColorEvent.new(black).dark?.should be_true

    bg = Ultraviolet::BackgroundColorEvent.new(white)
    bg.string.should eq("#ffffff")
    bg.dark?.should be_false
    Ultraviolet::BackgroundColorEvent.new(black).dark?.should be_true

    cursor = Ultraviolet::CursorColorEvent.new(red)
    cursor.string.should eq("#ff0000")
    cursor.dark?.should be_false
    Ultraviolet::CursorColorEvent.new(black).dark?.should be_true
  end

  it "matches color_to_hex behavior" do
    tests = [
      {Ultraviolet::Color.new(255_u8, 128_u8, 64_u8), "#ff8040"},
      {Ultraviolet::Color.new(0_u8, 0_u8, 0_u8), "#000000"},
      {Ultraviolet::Color.new(255_u8, 255_u8, 255_u8), "#ffffff"},
    ]

    tests.each do |color, expected|
      Ultraviolet.color_to_hex(color).should eq(expected)
    end
  end

  it "matches rgb_to_hsl behavior" do
    tests = [
      {255_u8, 0_u8, 0_u8, 0.0, 1.0, 0.5},
      {0_u8, 255_u8, 0_u8, 120.0, 1.0, 0.5},
      {0_u8, 0_u8, 255_u8, 240.0, 1.0, 0.5},
      {128_u8, 128_u8, 128_u8, 0.0, 0.0, 0.5},
      {255_u8, 255_u8, 255_u8, 0.0, 0.0, 1.0},
      {0_u8, 0_u8, 0_u8, 0.0, 0.0, 0.0},
    ]

    tests.each do |red, green, blue, hue, saturation, lightness|
      rh, rs, rl = Ultraviolet.rgb_to_hsl(red, green, blue)
      epsilon = 0.01
      next if saturation == 0.0 && rs == 0.0
      (rh - hue).abs.should be <= epsilon
      (rs - saturation).abs.should be <= epsilon
      (rl - lightness).abs.should be <= epsilon
    end
  end

  it "matches dark color checks" do
    tests = [
      {"#ffffff", false},
      {"#000000", true},
      {"#808080", false},
      {"#404040", true},
      {"#c0c0c0", false},
      {"#ff0000", false},
      {"#800000", true},
    ]

    tests.each do |hex, dark|
      color = Ansi.x_parse_color(hex)
      if color
        Ultraviolet.dark_color?(Ultraviolet::Color.new(color.r, color.g, color.b)).should eq(dark)
      else
        fail "Failed to parse color #{hex}"
      end
    end
  end

  it "supports clipboard events" do
    event = Ultraviolet::ClipboardEvent.new("test content", Ultraviolet::SystemClipboard)
    event.string.should eq("test content")
  end

  it "instantiates core event types" do
    Ultraviolet::CursorPositionEvent.new(20, 10)
    Ultraviolet::FocusEvent.new
    Ultraviolet::BlurEvent.new
    Ultraviolet::DarkColorSchemeEvent.new
    Ultraviolet::LightColorSchemeEvent.new
    Ultraviolet::PasteEvent.new("pasted text")
    Ultraviolet::PasteStartEvent.new
    Ultraviolet::PasteEndEvent.new
    Ultraviolet::TerminalVersionEvent.new("1.0.0")
    Ultraviolet::ModifyOtherKeysEvent.new(1)
    Ultraviolet::KittyGraphicsEvent.new
    Ultraviolet::PrimaryDeviceAttributesEvent.new(3) { |i| i + 1 }
    Ultraviolet::SecondaryDeviceAttributesEvent.new(3) { |i| i + 1 }
    "test".as(Ultraviolet::TertiaryDeviceAttributesEvent).should eq("test")
    Ultraviolet::ModeReportEvent.new(1000, Ansi::ModeSet.value)
    Ultraviolet::WindowOpEvent.new(1, [100, 200])
    Ultraviolet::CapabilityEvent.new("RGB")
    "ignored".as(Ultraviolet::IgnoredEvent).should eq("ignored")
  end
end
