require "./spec_helper"

private def x10_encode(b : Int32, x : Int32, y : Int32) : Bytes
  bx = (b + 32) & 0xff
  xx = (x + 32 + 1) & 0xff
  yx = (y + 32 + 1) & 0xff
  Bytes[0x1b_u8, '['.ord.to_u8, 'M'.ord.to_u8, bx.to_u8, xx.to_u8, yx.to_u8]
end

module Ultraviolet
  private class TestDecoder < EventDecoder
    def parse_termcap_public(data : Bytes) : CapabilityEvent
      parse_termcap(data)
    end

    def parse_primary_dev_attrs_public(params : Ansi::Params) : Event
      parse_primary_dev_attrs(params)
    end

    def parse_secondary_dev_attrs_public(params : Ansi::Params) : Event
      parse_secondary_dev_attrs(params)
    end

    def parse_tertiary_dev_attrs_public(data : Bytes) : Event
      parse_tertiary_dev_attrs(data)
    end

    def parse_utf8_public(buf : Bytes) : {Int32, Event?}
      parse_utf8(buf)
    end

    def parse_control_public(b : UInt8) : Event
      parse_control(b)
    end

    def translate_control_key_state_public(cks : UInt32) : KeyMod
      translate_control_key_state(cks)
    end

    def parse_win32_input_key_event_public(vkc : UInt16, scan : UInt16, rune_value : Int32, key_down : Bool, cks : UInt32, repeat_count : UInt16) : Event
      parse_win32_input_key_event(vkc, scan, rune_value, key_down, cks, repeat_count)
    end

    def parse_x10_mouse_event_public(buf : Bytes) : Event
      parse_x10_mouse_event(buf)
    end

    def parse_sgr_mouse_event_public(cmd : Int32, params : Ansi::Params) : Event
      parse_sgr_mouse_event(cmd, params)
    end
  end

  describe "Decoder function parity" do
    it "matches LegacyKeyEncoding flag mutators" do
      flags = LegacyKeyEncoding.new
      flags.ctrl_at(true).contains?(FLAG_CTRL_AT).should be_true
      flags.ctrl_i(true).contains?(FLAG_CTRL_I).should be_true
      flags.ctrl_m(true).contains?(FLAG_CTRL_M).should be_true
      flags.ctrl_open_bracket(true).contains?(FLAG_CTRL_OPEN_BRACKET).should be_true
      flags.backspace(true).contains?(FLAG_BACKSPACE).should be_true
      flags.find(true).contains?(FLAG_FIND).should be_true
      flags.select(true).contains?(FLAG_SELECT).should be_true
      flags.fkeys(true).contains?(FLAG_FKEYS).should be_true

      all = LegacyKeyEncoding.new(0xffff_ffff_u32)
      all.ctrl_at(false).contains?(FLAG_CTRL_AT).should be_false
      all.ctrl_i(false).contains?(FLAG_CTRL_I).should be_false
      all.ctrl_m(false).contains?(FLAG_CTRL_M).should be_false
      all.ctrl_open_bracket(false).contains?(FLAG_CTRL_OPEN_BRACKET).should be_false
      all.backspace(false).contains?(FLAG_BACKSPACE).should be_false
      all.find(false).contains?(FLAG_FIND).should be_false
      all.select(false).contains?(FLAG_SELECT).should be_false
      all.fkeys(false).contains?(FLAG_FKEYS).should be_false
    end

    it "matches parse_termcap and tertiary device attribute parsing" do
      decoder = TestDecoder.new

      decoder.parse_termcap_public("524742".to_slice).should eq(CapabilityEvent.new("RGB"))
      decoder.parse_termcap_public("436F=323536".to_slice).should eq(CapabilityEvent.new("Co=256"))
      decoder.parse_termcap_public(Bytes.empty).should eq(CapabilityEvent.new(""))
      decoder.parse_termcap_public("GGGG".to_slice).should eq(CapabilityEvent.new(""))
      decoder.parse_termcap_public("52474".to_slice).should eq(CapabilityEvent.new(""))

      decoder.parse_tertiary_dev_attrs_public("4368726d".to_slice).should eq("Chrm")
      decoder.parse_tertiary_dev_attrs_public("XYZ".to_slice).should eq(UnknownDcsEvent.new("\eP!|XYZ\e\\"))
    end

    it "matches primary and secondary device attribute parsing" do
      decoder = TestDecoder.new

      # Test parse_primary_dev_attrs
      params1 = Ansi::Params.new([62, 1, 2, 6, 9])
      event1 = decoder.parse_primary_dev_attrs_public(params1)
      event1.should be_a(PrimaryDeviceAttributesEvent)
      if event1.is_a?(PrimaryDeviceAttributesEvent)
        event1.to_a.should eq([62, 1, 2, 6, 9])
      end

      # Test parse_secondary_dev_attrs
      params2 = Ansi::Params.new([1, 2, 3])
      event2 = decoder.parse_secondary_dev_attrs_public(params2)
      event2.should be_a(SecondaryDeviceAttributesEvent)
      if event2.is_a?(SecondaryDeviceAttributesEvent)
        event2.to_a.should eq([1, 2, 3])
      end
    end

    it "matches parse_utf8 behavior for key and invalid bytes" do
      decoder = TestDecoder.new
      decoder.parse_utf8_public(Bytes.empty).should eq({0, nil})
      decoder.parse_utf8_public(Bytes[0x01]).should eq({1, Key.new(code: 'a'.ord, mod: ModCtrl).as(Event?)})
      decoder.parse_utf8_public(Bytes['a'.ord]).should eq({1, Key.new(code: 'a'.ord, text: "a").as(Event?)})
      decoder.parse_utf8_public(Bytes['A'.ord]).should eq({1, Key.new(code: 'a'.ord, shifted_code: 'A'.ord, text: "A", mod: ModShift).as(Event?)})
      decoder.parse_utf8_public(Bytes[0x7f]).should eq({1, Key.new(code: KeyBackspace).as(Event?)})
      decoder.parse_utf8_public("€".to_slice).should eq({3, Key.new(code: '€'.ord, text: "€").as(Event?)})
      decoder.parse_utf8_public(Bytes[0xff]).should eq({1, UnknownEvent.new("\u00ff").as(Event?)})
    end

    it "matches parse_control behavior with legacy flags" do
      decoder = TestDecoder.new
      decoder.legacy = LegacyKeyEncoding.new(FLAG_CTRL_AT)
      decoder.parse_control_public(Ansi::NUL.to_u8).should eq(Key.new(code: '@'.ord, mod: ModCtrl))

      decoder.legacy = LegacyKeyEncoding.new
      decoder.parse_control_public(Ansi::NUL.to_u8).should eq(Key.new(code: KeySpace, mod: ModCtrl))
      decoder.parse_control_public(Ansi::BS.to_u8).should eq(Key.new(code: 'h'.ord, mod: ModCtrl))
      decoder.parse_control_public(Ansi::HT.to_u8).should eq(Key.new(code: KeyTab))
      decoder.parse_control_public(Ansi::CR.to_u8).should eq(Key.new(code: KeyEnter))
      decoder.parse_control_public(Ansi::ESC.to_u8).should eq(Key.new(code: KeyEscape))
      decoder.parse_control_public(Ansi::DEL.to_u8).should eq(Key.new(code: KeyBackspace))
      decoder.parse_control_public(Ansi::SP.to_u8).should eq(Key.new(code: KeySpace, text: " "))
      decoder.parse_control_public(Ansi::SOH.to_u8).should eq(Key.new(code: 'a'.ord, mod: ModCtrl))
      decoder.parse_control_public(Ansi::SUB.to_u8).should eq(Key.new(code: 'z'.ord, mod: ModCtrl))
      decoder.parse_control_public(Ansi::FS.to_u8).should eq(Key.new(code: '\\'.ord, mod: ModCtrl))
      decoder.parse_control_public(Ansi::US.to_u8).should eq(Key.new(code: '_'.ord, mod: ModCtrl))
      decoder.parse_control_public(0x80_u8).should eq(UnknownEvent.new("\u0080"))
    end

    it "matches translate_control_key_state bit mapping" do
      decoder = TestDecoder.new
      decoder.translate_control_key_state_public(0b0000_0001_u32).should eq(ModCtrl)
      decoder.translate_control_key_state_public(0b0000_0010_u32).should eq(ModCtrl)
      decoder.translate_control_key_state_public(0b0000_0100_u32).should eq(ModAlt)
      decoder.translate_control_key_state_public(0b0000_1000_u32).should eq(ModAlt)
      decoder.translate_control_key_state_public(0b0001_0000_u32).should eq(ModShift)
      decoder.translate_control_key_state_public(0b0010_0000_u32).should eq(ModCapsLock)
      decoder.translate_control_key_state_public(0b0100_0000_u32).should eq(ModNumLock)
      decoder.translate_control_key_state_public(0b1000_0000_u32).should eq(ModScrollLock)
      decoder.translate_control_key_state_public(0b0001_1111_u32).should eq(ModCtrl | ModAlt | ModShift)
    end

    it "matches basic parse_win32_input_key_event cases" do
      decoder = TestDecoder.new

      decoder.parse_win32_input_key_event_public(0x41_u16, 0_u16, 'a'.ord, true, 0_u32, 1_u16).should eq(
        Key.new(code: 'a'.ord, base_code: 'a'.ord, text: "a")
      )
      decoder.parse_win32_input_key_event_public(0x41_u16, 0_u16, 'a'.ord, false, 0_u32, 1_u16).should eq(
        Key.new(code: 'a'.ord, base_code: 'a'.ord, text: "a")
      )
      decoder.parse_win32_input_key_event_public(0x70_u16, 0_u16, 0, true, 0_u32, 1_u16).should eq(
        Key.new(code: KeyF1, base_code: KeyF1)
      )
      decoder.parse_win32_input_key_event_public(0x0D_u16, 0_u16, '\r'.ord, true, 0_u32, 1_u16).should eq(
        Key.new(code: KeyEnter, base_code: KeyEnter)
      )
    end

    describe "parse_x10_mouse_event" do
      it "parses zero position left click" do
        buf = x10_encode(0b0000_0000, 0, 0)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(0, 0, MouseButton::Left)))
      end

      it "parses max position left click" do
        buf = x10_encode(0b0000_0000, 222, 222)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(222, 222, MouseButton::Left)))
      end

      it "parses left motion event" do
        buf = x10_encode(0b0010_0000, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      end

      it "parses middle click" do
        buf = x10_encode(0b0000_0001, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Middle)))
      end

      it "parses right click with ctrl+alt modifiers" do
        b = 0b0001_1010 # ctrl=0b0001_0000, alt=0b0000_1000, right=0b0000_0010
        buf = x10_encode(b, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt | ModCtrl)))
      end

      it "parses wheel up with ctrl" do
        b = 0b0101_0000 # wheel=0b0100_0000, ctrl=0b0001_0000, left=0b0000_0000
        buf = x10_encode(b, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelUp, ModCtrl)))
      end

      it "parses release event" do
        buf = x10_encode(0b0000_0011, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseReleaseEvent.new(Mouse.new(32, 16, MouseButton::None)))
      end

      it "parses back/forward and extended buttons" do
        buf = x10_encode(0b1000_0000, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Backward)))

        buf = x10_encode(0b1000_0001, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Forward)))

        buf = x10_encode(0b1000_0010, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Button10)))

        buf = x10_encode(0b1000_0011, 32, 16)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Button11)))
      end

      it "handles overflow position" do
        buf = x10_encode(0b0010_0000, 250, 223)
        event = TestDecoder.new.parse_x10_mouse_event_public(buf)
        event.should eq(MouseMotionEvent.new(Mouse.new(-6, -33, MouseButton::Left)))
      end
    end

    describe "parse_sgr_mouse_event" do
      # SGR mouse encoding uses CSI < b ; x+1 ; y+1 M (click/motion) or m (release)
      # PrefixShift = 8 encodes '<' into the command byte
      sgrc = ->(r : Char) { r.ord | ('<'.ord.to_i32 << Ansi::ParserTransition::PrefixShift) }
      mkp = ->(b : Int32, x : Int32, y : Int32) {
        Ansi::Params.new([Ansi::Param.new(b), Ansi::Param.new(x + 1), Ansi::Param.new(y + 1)])
      }

      it "parses zero position left click" do
        params = mkp.call(0, 0, 0)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(0, 0, MouseButton::Left)))
      end

      it "parses position 225 left click" do
        params = mkp.call(0, 225, 225)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(225, 225, MouseButton::Left)))
      end

      it "parses left click at position 32,16" do
        params = mkp.call(0, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      end

      it "parses left motion event" do
        params = mkp.call(32, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      end

      it "parses left release event" do
        params = mkp.call(0, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('m'), params)
        event.should eq(MouseReleaseEvent.new(Mouse.new(32, 16, MouseButton::Left)))
      end

      it "parses middle click and motion" do
        params = mkp.call(1, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Middle)))

        params = mkp.call(33, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseMotionEvent.new(Mouse.new(32, 16, MouseButton::Middle)))
      end

      it "parses wheel events" do
        params = mkp.call(64, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelUp)))

        params = mkp.call(65, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown)))

        params = mkp.call(66, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelLeft)))

        params = mkp.call(67, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelRight)))
      end

      it "parses extended buttons (backward/forward)" do
        params = mkp.call(128, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Backward)))

        params = mkp.call(129, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Forward)))
      end

      it "parses modifier combinations" do
        # alt+right: alt=8, right=2 -> 10
        params = mkp.call(10, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt)))

        # ctrl+right: ctrl=16, right=2 -> 18
        params = mkp.call(18, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModCtrl)))

        # ctrl+alt+right: ctrl=16, alt=8, right=2 -> 26
        params = mkp.call(26, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseClickEvent.new(Mouse.new(32, 16, MouseButton::Right, ModAlt | ModCtrl)))

        # ctrl+alt+shift+wheel down: ctrl=16, alt=8, shift=4, wheel=64, down=1 -> 93
        params = mkp.call(93, 32, 16)
        event = TestDecoder.new.parse_sgr_mouse_event_public(sgrc.call('M'), params)
        event.should eq(MouseWheelEvent.new(Mouse.new(32, 16, MouseButton::WheelDown, ModAlt | ModShift | ModCtrl)))
      end
    end

    describe "helper functions (colorToHex, rgbToHSL, isDarkColor)" do
      it "matches colorToHex from Go" do
        tests = [
          {Ultraviolet::Color.new(255_u8, 128_u8, 64_u8), "#ff8040"},
          {Ultraviolet::Color.new(0_u8, 0_u8, 0_u8), "#000000"},
          {Ultraviolet::Color.new(255_u8, 255_u8, 255_u8), "#ffffff"},
        ]
        tests.each do |color, want|
          Ultraviolet.color_to_hex(color).should eq(want), "color=#{color.inspect}"
        end
      end

      it "matches rgbToHSL from Go" do
        tests = [
          {255_u8, 0_u8, 0_u8, 0_f64, 1.0, 0.5},     # Red
          {0_u8, 255_u8, 0_u8, 120_f64, 1.0, 0.5},   # Green
          {0_u8, 0_u8, 255_u8, 240_f64, 1.0, 0.5},   # Blue
          {128_u8, 128_u8, 128_u8, 0_f64, 0.0, 0.5}, # Gray
          {255_u8, 255_u8, 255_u8, 0_f64, 0.0, 1.0}, # White
          {0_u8, 0_u8, 0_u8, 0_f64, 0.0, 0.0},       # Black
        ]
        epsilon = 0.01
        tests.each do |r, g, b, hue, sat, light|
          h, s, l = Ultraviolet.rgb_to_hsl(r, g, b)
          if sat.zero? && s.zero?
            # hue undefined when saturation is 0
          else
            (h - hue).abs.should be <= epsilon, "hue: #{h} vs #{hue}"
          end
          (s - sat).abs.should be <= epsilon, "sat: #{s} vs #{sat}"
          (l - light).abs.should be <= epsilon, "light: #{l} vs #{light}"
        end
      end

      it "matches isDarkColor from Go" do
        tests = [
          {"#ffffff", false}, # White
          {"#000000", true},  # Black
          {"#808080", false}, # Medium gray
          {"#404040", true},  # Dark gray
          {"#c0c0c0", false}, # Light gray
          {"#ff0000", false}, # Red
          {"#800000", true},  # Dark red
        ]
        tests.each do |hex, dark|
          color = Ansi.x_parse_color(hex).not_nil!
          c = Ultraviolet::Color.new(color.r, color.g, color.b)
          Ultraviolet.dark_color?(c).should eq(dark), hex
        end
      end
    end
  end
end
