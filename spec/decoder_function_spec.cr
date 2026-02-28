require "./spec_helper"

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
  end
end
