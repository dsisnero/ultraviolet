require "./spec_helper"

module KeySpecHelper
  def self.new_key(code : Int32, mod : Int32 = 0, text : String = "", base_code : Int32 = 0) : Ultraviolet::Key
    Ultraviolet::Key.new(code: code, mod: mod, text: text, base_code: base_code)
  end
end

describe "Key" do
  it "matches strings list" do
    tests = [
      {name: "matches first string", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl), inputs: ["ctrl+a", "ctrl+b", "ctrl+c"], want: true},
      {name: "matches middle string", key: KeySpecHelper.new_key('b'.ord, Ultraviolet::ModCtrl), inputs: ["ctrl+a", "ctrl+b", "ctrl+c"], want: true},
      {name: "matches last string", key: KeySpecHelper.new_key('c'.ord, Ultraviolet::ModCtrl), inputs: ["ctrl+a", "ctrl+b", "ctrl+c"], want: true},
      {name: "no match", key: KeySpecHelper.new_key('d'.ord, Ultraviolet::ModCtrl), inputs: ["ctrl+a", "ctrl+b", "ctrl+c"], want: false},
      {name: "empty inputs", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl), inputs: [] of String, want: false},
    ]

    tests.each do |test_case|
      inputs = test_case[:inputs]
      got = inputs.any? { |input| test_case[:key].match_string(input) }
      got.should eq(test_case[:want]), test_case[:name]
    end
  end

  it "matches key strings" do
    cases = [
      {name: "ctrl+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl), input: "ctrl+a", want: true},
      {name: "ctrl+alt+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl | Ultraviolet::ModAlt), input: "ctrl+alt+a", want: true},
      {name: "ctrl+alt+shift+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl | Ultraviolet::ModAlt | Ultraviolet::ModShift), input: "ctrl+alt+shift+a", want: true},
      {name: "H", key: KeySpecHelper.new_key('H'.ord, 0, "H"), input: "H", want: true},
      {name: "shift+h", key: KeySpecHelper.new_key('h'.ord, Ultraviolet::ModShift, "H"), input: "H", want: true},
      {name: "?", key: KeySpecHelper.new_key('/'.ord, Ultraviolet::ModShift, "?"), input: "?", want: true},
      {name: "shift+/", key: KeySpecHelper.new_key('/'.ord, Ultraviolet::ModShift, "?"), input: "shift+/", want: true},
      {name: "capslock+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCapsLock, "A"), input: "A", want: true},
      {name: "ctrl+capslock+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl | Ultraviolet::ModCapsLock), input: "ctrl+a", want: false},
      {name: "space", key: KeySpecHelper.new_key(Ultraviolet::KeySpace, 0, " "), input: "space", want: true},
      {name: "whitespace", key: KeySpecHelper.new_key(Ultraviolet::KeySpace, 0, " "), input: " ", want: true},
      {name: "ctrl+space", key: KeySpecHelper.new_key(Ultraviolet::KeySpace, Ultraviolet::ModCtrl), input: "ctrl+space", want: true},
      {name: "shift+whitespace", key: KeySpecHelper.new_key(Ultraviolet::KeySpace, Ultraviolet::ModShift, " "), input: " ", want: true},
      {name: "shift+space", key: KeySpecHelper.new_key(Ultraviolet::KeySpace, Ultraviolet::ModShift, " "), input: "shift+space", want: true},
      {name: "meta modifier", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModMeta), input: "meta+a", want: true},
      {name: "hyper modifier", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModHyper), input: "hyper+a", want: true},
      {name: "super modifier", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModSuper), input: "super+a", want: true},
      {name: "scrolllock modifier", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModScrollLock), input: "scrolllock+a", want: true},
      {name: "numlock modifier", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModNumLock), input: "numlock+a", want: true},
      {name: "multi-rune key", key: KeySpecHelper.new_key(Ultraviolet::KeyExtended, 0, "hello"), input: "hello", want: true},
      {name: "enter key", key: KeySpecHelper.new_key(Ultraviolet::KeyEnter), input: "enter", want: true},
      {name: "tab key", key: KeySpecHelper.new_key(Ultraviolet::KeyTab), input: "tab", want: true},
      {name: "escape key", key: KeySpecHelper.new_key(Ultraviolet::KeyEscape), input: "esc", want: true},
      {name: "f1 key", key: KeySpecHelper.new_key(Ultraviolet::KeyF1), input: "f1", want: true},
      {name: "backspace key", key: KeySpecHelper.new_key(Ultraviolet::KeyBackspace), input: "backspace", want: true},
      {name: "delete key", key: KeySpecHelper.new_key(Ultraviolet::KeyDelete), input: "delete", want: true},
      {name: "home key", key: KeySpecHelper.new_key(Ultraviolet::KeyHome), input: "home", want: true},
      {name: "end key", key: KeySpecHelper.new_key(Ultraviolet::KeyEnd), input: "end", want: true},
      {name: "pgup key", key: KeySpecHelper.new_key(Ultraviolet::KeyPgUp), input: "pgup", want: true},
      {name: "pgdown key", key: KeySpecHelper.new_key(Ultraviolet::KeyPgDown), input: "pgdown", want: true},
      {name: "up arrow", key: KeySpecHelper.new_key(Ultraviolet::KeyUp), input: "up", want: true},
      {name: "down arrow", key: KeySpecHelper.new_key(Ultraviolet::KeyDown), input: "down", want: true},
      {name: "left arrow", key: KeySpecHelper.new_key(Ultraviolet::KeyLeft), input: "left", want: true},
      {name: "right arrow", key: KeySpecHelper.new_key(Ultraviolet::KeyRight), input: "right", want: true},
      {name: "insert key", key: KeySpecHelper.new_key(Ultraviolet::KeyInsert), input: "insert", want: true},
      {name: "single printable character", key: KeySpecHelper.new_key('1'.ord, 0, "1"), input: "1", want: true},
      {name: "uppercase letter without shift", key: KeySpecHelper.new_key('A'.ord, 0, "A"), input: "A", want: true},
      {name: "no match different key", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl), input: "ctrl+b", want: false},
      {name: "no match different modifier", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl), input: "alt+a", want: false},
      {name: "unknown key name", key: KeySpecHelper.new_key('x'.ord), input: "unknownkey", want: false},
      {name: "multi-rune string that doesn't match", key: KeySpecHelper.new_key('a'.ord), input: "hello", want: false},
      {name: "printable character with ctrl modifier", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl), input: "a", want: false},
      {name: "lowercase letter with shift", key: KeySpecHelper.new_key('h'.ord, Ultraviolet::ModShift), input: "shift+h", want: true},
      {name: "uppercase letter with capslock", key: KeySpecHelper.new_key('h'.ord, Ultraviolet::ModCapsLock), input: "capslock+h", want: true},
    ]

    cases.each_with_index do |test_case, index|
      got = test_case[:key].match_string(test_case[:input])
      got.should eq(test_case[:want]), "#{index}: #{test_case[:name]}"
    end
  end

  it "formats keystrokes" do
    tests = [
      {name: "simple key", key: KeySpecHelper.new_key('a'.ord), want: "a"},
      {name: "ctrl+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl), want: "ctrl+a"},
      {name: "alt+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModAlt), want: "alt+a"},
      {name: "shift+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModShift), want: "shift+a"},
      {name: "meta+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModMeta), want: "meta+a"},
      {name: "hyper+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModHyper), want: "hyper+a"},
      {name: "super+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModSuper), want: "super+a"},
      {name: "ctrl+alt+shift+a", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl | Ultraviolet::ModAlt | Ultraviolet::ModShift), want: "ctrl+alt+shift+a"},
      {name: "all modifiers", key: KeySpecHelper.new_key('a'.ord, Ultraviolet::ModCtrl | Ultraviolet::ModAlt | Ultraviolet::ModShift | Ultraviolet::ModMeta | Ultraviolet::ModHyper | Ultraviolet::ModSuper), want: "ctrl+alt+shift+meta+hyper+super+a"},
      {name: "space key", key: KeySpecHelper.new_key(Ultraviolet::KeySpace), want: "space"},
      {name: "extended key with text", key: KeySpecHelper.new_key(Ultraviolet::KeyExtended, 0, "hello"), want: "hello"},
      {name: "enter key", key: KeySpecHelper.new_key(Ultraviolet::KeyEnter), want: "enter"},
      {name: "tab key", key: KeySpecHelper.new_key(Ultraviolet::KeyTab), want: "tab"},
      {name: "escape key", key: KeySpecHelper.new_key(Ultraviolet::KeyEscape), want: "esc"},
      {name: "f1 key", key: KeySpecHelper.new_key(Ultraviolet::KeyF1), want: "f1"},
      {name: "backspace key", key: KeySpecHelper.new_key(Ultraviolet::KeyBackspace), want: "backspace"},
      {name: "left ctrl key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyLeftCtrl, Ultraviolet::ModCtrl), want: "leftctrl"},
      {name: "right ctrl key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyRightCtrl, Ultraviolet::ModCtrl), want: "rightctrl"},
      {name: "left alt key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyLeftAlt, Ultraviolet::ModAlt), want: "leftalt"},
      {name: "right alt key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyRightAlt, Ultraviolet::ModAlt), want: "rightalt"},
      {name: "left shift key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyLeftShift, Ultraviolet::ModShift), want: "leftshift"},
      {name: "right shift key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyRightShift, Ultraviolet::ModShift), want: "rightshift"},
      {name: "left meta key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyLeftMeta, Ultraviolet::ModMeta), want: "leftmeta"},
      {name: "right meta key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyRightMeta, Ultraviolet::ModMeta), want: "rightmeta"},
      {name: "left hyper key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyLeftHyper, Ultraviolet::ModHyper), want: "lefthyper"},
      {name: "right hyper key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyRightHyper, Ultraviolet::ModHyper), want: "righthyper"},
      {name: "left super key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyLeftSuper, Ultraviolet::ModSuper), want: "leftsuper"},
      {name: "right super key alone", key: KeySpecHelper.new_key(Ultraviolet::KeyRightSuper, Ultraviolet::ModSuper), want: "rightsuper"},
      {name: "key with base code", key: KeySpecHelper.new_key('A'.ord, 0, "", 'a'.ord), want: "a"},
      {name: "unknown key with base code", key: KeySpecHelper.new_key(99999, 0, "", 'x'.ord), want: "x"},
      {name: "printable rune", key: KeySpecHelper.new_key('€'.ord), want: "€"},
      {name: "unknown key without base code", key: KeySpecHelper.new_key(99999), want: "𘚟"},
    ]

    tests.each do |test_case|
      test_case[:key].keystroke.should eq(test_case[:want]), test_case[:name]
    end
  end

  it "handles keystroke edge cases" do
    key = KeySpecHelper.new_key(999999, 0, "", Ultraviolet::KeySpace)
    key.keystroke.should eq("space")
  end

  it "formats key string" do
    tests = [
      {name: "space character", key: KeySpecHelper.new_key(Ultraviolet::KeySpace, 0, " "), want: "space"},
      {name: "empty text", key: KeySpecHelper.new_key('a'.ord, 0, ""), want: "a"},
      {name: "text with multiple characters", key: KeySpecHelper.new_key(Ultraviolet::KeyExtended, 0, "hello"), want: "hello"},
    ]

    tests.each do |test_case|
      test_case[:key].string.should eq(test_case[:want]), test_case[:name]
    end
  end

  it "formats key press event string like Go TestKeyString" do
    # Test alt+space
    key = Ultraviolet::Key.new(code: Ultraviolet::KeySpace, mod: Ultraviolet::ModAlt)
    key.string.should eq("alt+space")

    # Test runes
    key = Ultraviolet::Key.new(code: 'a'.ord, text: "a")
    key.string.should eq("a")

    # Test invalid key code (should return replacement character)
    key = Ultraviolet::Key.new(code: 99999)
    key.string.should eq("𘚟")
  end

  it "handles focus and blur events like Go tests" do
    decoder = Ultraviolet::EventDecoder.new

    # Test focus event - matches Go TestFocus
    consumed, event = decoder.decode("\x1b[I".to_slice)
    event.should be_a(Ultraviolet::FocusEvent)

    # Test blur event - matches Go TestBlur
    consumed, event = decoder.decode("\x1b[O".to_slice)
    event.should be_a(Ultraviolet::BlurEvent)
  end
end
