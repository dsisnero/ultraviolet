module Ultraviolet
  alias KeyMod = Int32

  # Modifier keys.
  ModShift      = 1 << 0
  ModAlt        = 1 << 1
  ModCtrl       = 1 << 2
  ModMeta       = 1 << 3
  ModHyper      = 1 << 4
  ModSuper      = 1 << 5
  ModCapsLock   = 1 << 6
  ModNumLock    = 1 << 7
  ModScrollLock = 1 << 8

  def self.mod_contains?(value : KeyMod, mods : KeyMod) : Bool
    (value & mods) == mods
  end

  KeyExtended = 0x10FFFF + 1

  # Special keys.
  KeyUp     = KeyExtended + 1
  KeyDown   = KeyUp + 1
  KeyRight  = KeyDown + 1
  KeyLeft   = KeyRight + 1
  KeyBegin  = KeyLeft + 1
  KeyFind   = KeyBegin + 1
  KeyInsert = KeyFind + 1
  KeyDelete = KeyInsert + 1
  KeySelect = KeyDelete + 1
  KeyPgUp   = KeySelect + 1
  KeyPgDown = KeyPgUp + 1
  KeyHome   = KeyPgDown + 1
  KeyEnd    = KeyHome + 1

  # Keypad keys.
  KeyKpEnter    = KeyEnd + 1
  KeyKpEqual    = KeyKpEnter + 1
  KeyKpMultiply = KeyKpEqual + 1
  KeyKpPlus     = KeyKpMultiply + 1
  KeyKpComma    = KeyKpPlus + 1
  KeyKpMinus    = KeyKpComma + 1
  KeyKpDecimal  = KeyKpMinus + 1
  KeyKpDivide   = KeyKpDecimal + 1
  KeyKp0        = KeyKpDivide + 1
  KeyKp1        = KeyKp0 + 1
  KeyKp2        = KeyKp1 + 1
  KeyKp3        = KeyKp2 + 1
  KeyKp4        = KeyKp3 + 1
  KeyKp5        = KeyKp4 + 1
  KeyKp6        = KeyKp5 + 1
  KeyKp7        = KeyKp6 + 1
  KeyKp8        = KeyKp7 + 1
  KeyKp9        = KeyKp8 + 1

  # Kitty protocol keypad extras.
  KeyKpSep    = KeyKp9 + 1
  KeyKpUp     = KeyKpSep + 1
  KeyKpDown   = KeyKpUp + 1
  KeyKpLeft   = KeyKpDown + 1
  KeyKpRight  = KeyKpLeft + 1
  KeyKpPgUp   = KeyKpRight + 1
  KeyKpPgDown = KeyKpPgUp + 1
  KeyKpHome   = KeyKpPgDown + 1
  KeyKpEnd    = KeyKpHome + 1
  KeyKpInsert = KeyKpEnd + 1
  KeyKpDelete = KeyKpInsert + 1
  KeyKpBegin  = KeyKpDelete + 1

  # Function keys.
  KeyF1  = KeyKpBegin + 1
  KeyF2  = KeyF1 + 1
  KeyF3  = KeyF2 + 1
  KeyF4  = KeyF3 + 1
  KeyF5  = KeyF4 + 1
  KeyF6  = KeyF5 + 1
  KeyF7  = KeyF6 + 1
  KeyF8  = KeyF7 + 1
  KeyF9  = KeyF8 + 1
  KeyF10 = KeyF9 + 1
  KeyF11 = KeyF10 + 1
  KeyF12 = KeyF11 + 1
  KeyF13 = KeyF12 + 1
  KeyF14 = KeyF13 + 1
  KeyF15 = KeyF14 + 1
  KeyF16 = KeyF15 + 1
  KeyF17 = KeyF16 + 1
  KeyF18 = KeyF17 + 1
  KeyF19 = KeyF18 + 1
  KeyF20 = KeyF19 + 1
  KeyF21 = KeyF20 + 1
  KeyF22 = KeyF21 + 1
  KeyF23 = KeyF22 + 1
  KeyF24 = KeyF23 + 1
  KeyF25 = KeyF24 + 1
  KeyF26 = KeyF25 + 1
  KeyF27 = KeyF26 + 1
  KeyF28 = KeyF27 + 1
  KeyF29 = KeyF28 + 1
  KeyF30 = KeyF29 + 1
  KeyF31 = KeyF30 + 1
  KeyF32 = KeyF31 + 1
  KeyF33 = KeyF32 + 1
  KeyF34 = KeyF33 + 1
  KeyF35 = KeyF34 + 1
  KeyF36 = KeyF35 + 1
  KeyF37 = KeyF36 + 1
  KeyF38 = KeyF37 + 1
  KeyF39 = KeyF38 + 1
  KeyF40 = KeyF39 + 1
  KeyF41 = KeyF40 + 1
  KeyF42 = KeyF41 + 1
  KeyF43 = KeyF42 + 1
  KeyF44 = KeyF43 + 1
  KeyF45 = KeyF44 + 1
  KeyF46 = KeyF45 + 1
  KeyF47 = KeyF46 + 1
  KeyF48 = KeyF47 + 1
  KeyF49 = KeyF48 + 1
  KeyF50 = KeyF49 + 1
  KeyF51 = KeyF50 + 1
  KeyF52 = KeyF51 + 1
  KeyF53 = KeyF52 + 1
  KeyF54 = KeyF53 + 1
  KeyF55 = KeyF54 + 1
  KeyF56 = KeyF55 + 1
  KeyF57 = KeyF56 + 1
  KeyF58 = KeyF57 + 1
  KeyF59 = KeyF58 + 1
  KeyF60 = KeyF59 + 1
  KeyF61 = KeyF60 + 1
  KeyF62 = KeyF61 + 1
  KeyF63 = KeyF62 + 1

  # Kitty protocol extra keys.
  KeyCapsLock    = KeyF63 + 1
  KeyScrollLock  = KeyCapsLock + 1
  KeyNumLock     = KeyScrollLock + 1
  KeyPrintScreen = KeyNumLock + 1
  KeyPause       = KeyPrintScreen + 1
  KeyMenu        = KeyPause + 1

  KeyMediaPlay        = KeyMenu + 1
  KeyMediaPause       = KeyMediaPlay + 1
  KeyMediaPlayPause   = KeyMediaPause + 1
  KeyMediaReverse     = KeyMediaPlayPause + 1
  KeyMediaStop        = KeyMediaReverse + 1
  KeyMediaFastForward = KeyMediaStop + 1
  KeyMediaRewind      = KeyMediaFastForward + 1
  KeyMediaNext        = KeyMediaRewind + 1
  KeyMediaPrev        = KeyMediaNext + 1
  KeyMediaRecord      = KeyMediaPrev + 1

  KeyLowerVol = KeyMediaRecord + 1
  KeyRaiseVol = KeyLowerVol + 1
  KeyMute     = KeyRaiseVol + 1

  KeyLeftShift = KeyMute + 1
  KeyLeftCtrl  = KeyLeftShift + 1
  KeyLeftAlt   = KeyLeftCtrl + 1
  KeyLeftMeta  = KeyLeftAlt + 1
  KeyLeftSuper = KeyLeftMeta + 1
  KeyLeftHyper = KeyLeftSuper + 1

  KeyRightShift = KeyLeftHyper + 1
  KeyRightCtrl  = KeyRightShift + 1
  KeyRightAlt   = KeyRightCtrl + 1
  KeyRightMeta  = KeyRightAlt + 1
  KeyRightSuper = KeyRightMeta + 1
  KeyRightHyper = KeyRightSuper + 1

  # Common keys.
  KeyBackspace = Ansi::BS
  KeyTab       = Ansi::HT
  KeyEnter     = Ansi::CR
  KeyEscape    = Ansi::ESC
  KeySpace     = Ansi::SP

  struct Key
    property text : String
    property mod : KeyMod
    property code : Int32
    property shifted_code : Int32
    property base_code : Int32
    property? is_repeat : Bool

    def initialize(
      @text : String = "",
      @mod : KeyMod = 0,
      @code : Int32 = 0,
      @shifted_code : Int32 = 0,
      @base_code : Int32 = 0,
      @is_repeat : Bool = false,
    )
    end

    def match_string(*values : String) : Bool
      values.any? { |value| Ultraviolet.key_match_string(self, value) }
    end

    def string : String
      return @text if !@text.empty? && @text != " "
      keystroke
    end

    def keystroke : String
      parts = modifier_prefixes
      parts << key_label
      parts.join
    end

    private def modifier_prefixes : Array(String)
      parts = [] of String
      parts << "ctrl+" if mod_active?(ModCtrl, KeyLeftCtrl, KeyRightCtrl)
      parts << "alt+" if mod_active?(ModAlt, KeyLeftAlt, KeyRightAlt)
      parts << "shift+" if mod_active?(ModShift, KeyLeftShift, KeyRightShift)
      parts << "meta+" if mod_active?(ModMeta, KeyLeftMeta, KeyRightMeta)
      parts << "hyper+" if mod_active?(ModHyper, KeyLeftHyper, KeyRightHyper)
      parts << "super+" if mod_active?(ModSuper, KeyLeftSuper, KeyRightSuper)
      parts
    end

    private def mod_active?(mod : KeyMod, left : Int32, right : Int32) : Bool
      Ultraviolet.mod_contains?(@mod, mod) && @code != left && @code != right
    end

    private def key_label : String
      if key_type = KEY_TYPE_STRING[@code]?
        return key_type
      end

      code = @base_code != 0 ? @base_code : @code
      case code
      when KeySpace
        "space"
      when KeyExtended
        @text
      else
        Ultraviolet.safe_char(code).to_s
      end
    end
  end

  KEY_TYPE_STRING = {
    KeyEnter      => "enter",
    KeyTab        => "tab",
    KeyBackspace  => "backspace",
    KeyEscape     => "esc",
    KeySpace      => "space",
    KeyUp         => "up",
    KeyDown       => "down",
    KeyLeft       => "left",
    KeyRight      => "right",
    KeyBegin      => "begin",
    KeyFind       => "find",
    KeyInsert     => "insert",
    KeyDelete     => "delete",
    KeySelect     => "select",
    KeyPgUp       => "pgup",
    KeyPgDown     => "pgdown",
    KeyHome       => "home",
    KeyEnd        => "end",
    KeyKpEnter    => "enter",
    KeyKpEqual    => "equal",
    KeyKpMultiply => "mul",
    KeyKpPlus     => "plus",
    KeyKpComma    => "comma",
    KeyKpMinus    => "minus",
    KeyKpDecimal  => "period",
    KeyKpDivide   => "div",
    KeyKp0        => "0",
    KeyKp1        => "1",
    KeyKp2        => "2",
    KeyKp3        => "3",
    KeyKp4        => "4",
    KeyKp5        => "5",
    KeyKp6        => "6",
    KeyKp7        => "7",
    KeyKp8        => "8",
    KeyKp9        => "9",

    KeyKpSep    => "sep",
    KeyKpUp     => "up",
    KeyKpDown   => "down",
    KeyKpLeft   => "left",
    KeyKpRight  => "right",
    KeyKpPgUp   => "pgup",
    KeyKpPgDown => "pgdown",
    KeyKpHome   => "home",
    KeyKpEnd    => "end",
    KeyKpInsert => "insert",
    KeyKpDelete => "delete",
    KeyKpBegin  => "begin",

    KeyF1  => "f1",
    KeyF2  => "f2",
    KeyF3  => "f3",
    KeyF4  => "f4",
    KeyF5  => "f5",
    KeyF6  => "f6",
    KeyF7  => "f7",
    KeyF8  => "f8",
    KeyF9  => "f9",
    KeyF10 => "f10",
    KeyF11 => "f11",
    KeyF12 => "f12",
    KeyF13 => "f13",
    KeyF14 => "f14",
    KeyF15 => "f15",
    KeyF16 => "f16",
    KeyF17 => "f17",
    KeyF18 => "f18",
    KeyF19 => "f19",
    KeyF20 => "f20",
    KeyF21 => "f21",
    KeyF22 => "f22",
    KeyF23 => "f23",
    KeyF24 => "f24",
    KeyF25 => "f25",
    KeyF26 => "f26",
    KeyF27 => "f27",
    KeyF28 => "f28",
    KeyF29 => "f29",
    KeyF30 => "f30",
    KeyF31 => "f31",
    KeyF32 => "f32",
    KeyF33 => "f33",
    KeyF34 => "f34",
    KeyF35 => "f35",
    KeyF36 => "f36",
    KeyF37 => "f37",
    KeyF38 => "f38",
    KeyF39 => "f39",
    KeyF40 => "f40",
    KeyF41 => "f41",
    KeyF42 => "f42",
    KeyF43 => "f43",
    KeyF44 => "f44",
    KeyF45 => "f45",
    KeyF46 => "f46",
    KeyF47 => "f47",
    KeyF48 => "f48",
    KeyF49 => "f49",
    KeyF50 => "f50",
    KeyF51 => "f51",
    KeyF52 => "f52",
    KeyF53 => "f53",
    KeyF54 => "f54",
    KeyF55 => "f55",
    KeyF56 => "f56",
    KeyF57 => "f57",
    KeyF58 => "f58",
    KeyF59 => "f59",
    KeyF60 => "f60",
    KeyF61 => "f61",
    KeyF62 => "f62",
    KeyF63 => "f63",

    KeyCapsLock    => "capslock",
    KeyScrollLock  => "scrolllock",
    KeyNumLock     => "numlock",
    KeyPrintScreen => "printscreen",
    KeyPause       => "pause",
    KeyMenu        => "menu",

    KeyMediaPlay        => "mediaplay",
    KeyMediaPause       => "mediapause",
    KeyMediaPlayPause   => "mediaplaypause",
    KeyMediaReverse     => "mediareverse",
    KeyMediaStop        => "mediastop",
    KeyMediaFastForward => "mediafastforward",
    KeyMediaRewind      => "mediarewind",
    KeyMediaNext        => "medianext",
    KeyMediaPrev        => "mediaprev",
    KeyMediaRecord      => "mediarecord",

    KeyLowerVol => "volumedown",
    KeyRaiseVol => "volumeup",
    KeyMute     => "mute",

    KeyLeftShift => "leftshift",
    KeyLeftCtrl  => "leftctrl",
    KeyLeftAlt   => "leftalt",
    KeyLeftMeta  => "leftmeta",
    KeyLeftSuper => "leftsuper",
    KeyLeftHyper => "lefthyper",

    KeyRightShift => "rightshift",
    KeyRightCtrl  => "rightctrl",
    KeyRightAlt   => "rightalt",
    KeyRightMeta  => "rightmeta",
    KeyRightSuper => "rightsuper",
    KeyRightHyper => "righthyper",
  }

  STRING_KEY_TYPE = {
    "enter"            => KeyEnter,
    "tab"              => KeyTab,
    "backspace"        => KeyBackspace,
    "escape"           => KeyEscape,
    "esc"              => KeyEscape,
    "space"            => KeySpace,
    "up"               => KeyUp,
    "down"             => KeyDown,
    "left"             => KeyLeft,
    "right"            => KeyRight,
    "begin"            => KeyBegin,
    "find"             => KeyFind,
    "insert"           => KeyInsert,
    "delete"           => KeyDelete,
    "select"           => KeySelect,
    "pgup"             => KeyPgUp,
    "pgdown"           => KeyPgDown,
    "home"             => KeyHome,
    "end"              => KeyEnd,
    "kpenter"          => KeyKpEnter,
    "kpequal"          => KeyKpEqual,
    "kpmul"            => KeyKpMultiply,
    "kpplus"           => KeyKpPlus,
    "kpcomma"          => KeyKpComma,
    "kpminus"          => KeyKpMinus,
    "kpperiod"         => KeyKpDecimal,
    "kpdiv"            => KeyKpDivide,
    "kp0"              => KeyKp0,
    "kp1"              => KeyKp1,
    "kp2"              => KeyKp2,
    "kp3"              => KeyKp3,
    "kp4"              => KeyKp4,
    "kp5"              => KeyKp5,
    "kp6"              => KeyKp6,
    "kp7"              => KeyKp7,
    "kp8"              => KeyKp8,
    "kp9"              => KeyKp9,
    "kpsep"            => KeyKpSep,
    "kpup"             => KeyKpUp,
    "kpdown"           => KeyKpDown,
    "kpleft"           => KeyKpLeft,
    "kpright"          => KeyKpRight,
    "kppgup"           => KeyKpPgUp,
    "kppgdown"         => KeyKpPgDown,
    "kphome"           => KeyKpHome,
    "kpend"            => KeyKpEnd,
    "kpinsert"         => KeyKpInsert,
    "kpdelete"         => KeyKpDelete,
    "kpbegin"          => KeyKpBegin,
    "f1"               => KeyF1,
    "f2"               => KeyF2,
    "f3"               => KeyF3,
    "f4"               => KeyF4,
    "f5"               => KeyF5,
    "f6"               => KeyF6,
    "f7"               => KeyF7,
    "f8"               => KeyF8,
    "f9"               => KeyF9,
    "f10"              => KeyF10,
    "f11"              => KeyF11,
    "f12"              => KeyF12,
    "f13"              => KeyF13,
    "f14"              => KeyF14,
    "f15"              => KeyF15,
    "f16"              => KeyF16,
    "f17"              => KeyF17,
    "f18"              => KeyF18,
    "f19"              => KeyF19,
    "f20"              => KeyF20,
    "f21"              => KeyF21,
    "f22"              => KeyF22,
    "f23"              => KeyF23,
    "f24"              => KeyF24,
    "f25"              => KeyF25,
    "f26"              => KeyF26,
    "f27"              => KeyF27,
    "f28"              => KeyF28,
    "f29"              => KeyF29,
    "f30"              => KeyF30,
    "f31"              => KeyF31,
    "f32"              => KeyF32,
    "f33"              => KeyF33,
    "f34"              => KeyF34,
    "f35"              => KeyF35,
    "f36"              => KeyF36,
    "f37"              => KeyF37,
    "f38"              => KeyF38,
    "f39"              => KeyF39,
    "f40"              => KeyF40,
    "f41"              => KeyF41,
    "f42"              => KeyF42,
    "f43"              => KeyF43,
    "f44"              => KeyF44,
    "f45"              => KeyF45,
    "f46"              => KeyF46,
    "f47"              => KeyF47,
    "f48"              => KeyF48,
    "f49"              => KeyF49,
    "f50"              => KeyF50,
    "f51"              => KeyF51,
    "f52"              => KeyF52,
    "f53"              => KeyF53,
    "f54"              => KeyF54,
    "f55"              => KeyF55,
    "f56"              => KeyF56,
    "f57"              => KeyF57,
    "f58"              => KeyF58,
    "f59"              => KeyF59,
    "f60"              => KeyF60,
    "f61"              => KeyF61,
    "f62"              => KeyF62,
    "f63"              => KeyF63,
    "capslock"         => KeyCapsLock,
    "scrolllock"       => KeyScrollLock,
    "numlock"          => KeyNumLock,
    "printscreen"      => KeyPrintScreen,
    "pause"            => KeyPause,
    "menu"             => KeyMenu,
    "mediaplay"        => KeyMediaPlay,
    "mediapause"       => KeyMediaPause,
    "mediaplaypause"   => KeyMediaPlayPause,
    "mediareverse"     => KeyMediaReverse,
    "mediastop"        => KeyMediaStop,
    "mediafastforward" => KeyMediaFastForward,
    "mediarewind"      => KeyMediaRewind,
    "medianext"        => KeyMediaNext,
    "mediaprev"        => KeyMediaPrev,
    "mediarecord"      => KeyMediaRecord,
    "volumedown"       => KeyLowerVol,
    "volumeup"         => KeyRaiseVol,
    "mute"             => KeyMute,
    "leftshift"        => KeyLeftShift,
    "leftctrl"         => KeyLeftCtrl,
    "leftalt"          => KeyLeftAlt,
    "leftmeta"         => KeyLeftMeta,
    "leftsuper"        => KeyLeftSuper,
    "lefthyper"        => KeyLeftHyper,
    "rightshift"       => KeyRightShift,
    "rightalt"         => KeyRightAlt,
    "rightctrl"        => KeyRightCtrl,
    "rightsuper"       => KeyRightSuper,
    "righthyper"       => KeyRightHyper,
    "rightmeta"        => KeyRightMeta,
  }

  def self.key_match_string(key : Key, value : String) : Bool
    mod, code, text = parse_key_string(value)
    text = apply_printable_text(mod, code, text)
    return true if key.mod == mod && key.code == code
    return false if key.text.empty?
    key.text == text
  end

  def self.safe_char(code : Int32) : Char
    if code < 0 || code > Char::MAX_CODEPOINT
      return Char::REPLACEMENT
    end
    if code >= 0xD800 && code <= 0xDFFF
      return Char::REPLACEMENT
    end
    code.chr
  end

  def self.printable_char?(code : Int32) : Bool
    return false if code < 0 || code > Char::MAX_CODEPOINT
    return false if code >= 0xD800 && code <= 0xDFFF
    code.chr.printable?
  end

  private def self.parse_key_string(value : String) : {KeyMod, Int32, String}
    mod = 0
    code = 0
    text = ""
    value.split('+').each do |part|
      if mod_flag = MOD_KEYWORDS[part]?
        mod |= mod_flag
        next
      end

      if key_type = STRING_KEY_TYPE[part]?
        code = key_type
        next
      end

      if part.each_char.count { true } == 1
        code = part.each_char.first.ord
      else
        code = KeyExtended
        text = part
      end
    end

    {mod, code, text}
  end

  private def self.apply_printable_text(mod : KeyMod, code : Int32, text : String) : String
    return text unless text.empty?
    return text unless (mod & ~(ModShift | ModCapsLock)) == 0
    return text unless printable_char?(code)

    char = Ultraviolet.safe_char(code)
    if (mod & (ModShift | ModCapsLock)) != 0
      char.upcase.to_s
    else
      char.to_s
    end
  end

  MOD_KEYWORDS = {
    "ctrl"       => ModCtrl,
    "alt"        => ModAlt,
    "shift"      => ModShift,
    "meta"       => ModMeta,
    "hyper"      => ModHyper,
    "super"      => ModSuper,
    "capslock"   => ModCapsLock,
    "scrolllock" => ModScrollLock,
    "numlock"    => ModNumLock,
  }
end
