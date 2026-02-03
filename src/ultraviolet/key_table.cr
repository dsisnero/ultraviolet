module Ultraviolet
  # Legacy key encoding flags.
  FLAG_CTRL_AT           = 1 << 0
  FLAG_CTRL_I            = 1 << 1
  FLAG_CTRL_M            = 1 << 2
  FLAG_CTRL_OPEN_BRACKET = 1 << 3
  FLAG_BACKSPACE         = 1 << 4
  FLAG_FIND              = 1 << 5
  FLAG_SELECT            = 1 << 6
  FLAG_FKEYS             = 1 << 7

  struct LegacyKeyEncoding
    property value : UInt32

    def initialize(@value : UInt32 = 0)
    end

    def ctrl_at(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_CTRL_AT, v)
    end

    def ctrl_i(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_CTRL_I, v)
    end

    def ctrl_m(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_CTRL_M, v)
    end

    def ctrl_open_bracket(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_CTRL_OPEN_BRACKET, v)
    end

    def backspace(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_BACKSPACE, v)
    end

    def find(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_FIND, v)
    end

    def select(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_SELECT, v)
    end

    def fkeys(v : Bool) : LegacyKeyEncoding
      update_flag(FLAG_FKEYS, v)
    end

    def contains?(flag : UInt32) : Bool
      (@value & flag) == flag
    end

    private def update_flag(flag : UInt32, enabled : Bool) : LegacyKeyEncoding
      if enabled
        @value |= flag
      else
        @value &= ~flag
      end
      self
    end
  end

  def self.build_keys_table(flags : LegacyKeyEncoding, term : String, use_terminfo : Bool) : Hash(String, Key)
    nul = Key.new(code: KeySpace, mod: ModCtrl)
    nul = Key.new(code: '@'.ord, mod: ModCtrl) if flags.contains?(FLAG_CTRL_AT)

    tab = Key.new(code: KeyTab)
    tab = Key.new(code: 'i'.ord, mod: ModCtrl) if flags.contains?(FLAG_CTRL_I)

    enter = Key.new(code: KeyEnter)
    enter = Key.new(code: 'm'.ord, mod: ModCtrl) if flags.contains?(FLAG_CTRL_M)

    esc = Key.new(code: KeyEscape)
    esc = Key.new(code: '['.ord, mod: ModCtrl) if flags.contains?(FLAG_CTRL_OPEN_BRACKET)

    del = Key.new(code: KeyBackspace)
    del = Key.new(code: KeyDelete) if flags.contains?(FLAG_BACKSPACE)

    find = Key.new(code: KeyHome)
    find = Key.new(code: KeyFind) if flags.contains?(FLAG_FIND)

    sel = Key.new(code: KeyEnd)
    sel = Key.new(code: KeySelect) if flags.contains?(FLAG_SELECT)

    table = {
      Ansi::NUL.chr => nul,
      Ansi::SOH.chr => Key.new(code: 'a'.ord, mod: ModCtrl),
      Ansi::STX.chr => Key.new(code: 'b'.ord, mod: ModCtrl),
      Ansi::ETX.chr => Key.new(code: 'c'.ord, mod: ModCtrl),
      Ansi::EOT.chr => Key.new(code: 'd'.ord, mod: ModCtrl),
      Ansi::ENQ.chr => Key.new(code: 'e'.ord, mod: ModCtrl),
      Ansi::ACK.chr => Key.new(code: 'f'.ord, mod: ModCtrl),
      Ansi::BEL.chr => Key.new(code: 'g'.ord, mod: ModCtrl),
      Ansi::BS.chr  => Key.new(code: 'h'.ord, mod: ModCtrl),
      Ansi::HT.chr  => tab,
      Ansi::LF.chr  => Key.new(code: 'j'.ord, mod: ModCtrl),
      Ansi::VT.chr  => Key.new(code: 'k'.ord, mod: ModCtrl),
      Ansi::FF.chr  => Key.new(code: 'l'.ord, mod: ModCtrl),
      Ansi::CR.chr  => enter,
      Ansi::SO.chr  => Key.new(code: 'n'.ord, mod: ModCtrl),
      Ansi::SI.chr  => Key.new(code: 'o'.ord, mod: ModCtrl),
      Ansi::DLE.chr => Key.new(code: 'p'.ord, mod: ModCtrl),
      Ansi::DC1.chr => Key.new(code: 'q'.ord, mod: ModCtrl),
      Ansi::DC2.chr => Key.new(code: 'r'.ord, mod: ModCtrl),
      Ansi::DC3.chr => Key.new(code: 's'.ord, mod: ModCtrl),
      Ansi::DC4.chr => Key.new(code: 't'.ord, mod: ModCtrl),
      Ansi::NAK.chr => Key.new(code: 'u'.ord, mod: ModCtrl),
      Ansi::SYN.chr => Key.new(code: 'v'.ord, mod: ModCtrl),
      Ansi::ETB.chr => Key.new(code: 'w'.ord, mod: ModCtrl),
      Ansi::CAN.chr => Key.new(code: 'x'.ord, mod: ModCtrl),
      Ansi::EM.chr  => Key.new(code: 'y'.ord, mod: ModCtrl),
      Ansi::SUB.chr => Key.new(code: 'z'.ord, mod: ModCtrl),
      Ansi::ESC.chr => esc,
      Ansi::FS.chr  => Key.new(code: '\\'.ord, mod: ModCtrl),
      Ansi::GS.chr  => Key.new(code: ']'.ord, mod: ModCtrl),
      Ansi::RS.chr  => Key.new(code: '^'.ord, mod: ModCtrl),
      Ansi::US.chr  => Key.new(code: '_'.ord, mod: ModCtrl),

      Ansi::SP.chr  => Key.new(code: KeySpace, text: " "),
      Ansi::DEL.chr => del,

      "\e[Z" => Key.new(code: KeyTab, mod: ModShift),

      "\e[1~" => find,
      "\e[2~" => Key.new(code: KeyInsert),
      "\e[3~" => Key.new(code: KeyDelete),
      "\e[4~" => sel,
      "\e[5~" => Key.new(code: KeyPgUp),
      "\e[6~" => Key.new(code: KeyPgDown),
      "\e[7~" => Key.new(code: KeyHome),
      "\e[8~" => Key.new(code: KeyEnd),

      "\e[A" => Key.new(code: KeyUp),
      "\e[B" => Key.new(code: KeyDown),
      "\e[C" => Key.new(code: KeyRight),
      "\e[D" => Key.new(code: KeyLeft),
      "\e[E" => Key.new(code: KeyBegin),
      "\e[F" => Key.new(code: KeyEnd),
      "\e[H" => Key.new(code: KeyHome),
      "\e[P" => Key.new(code: KeyF1),
      "\e[Q" => Key.new(code: KeyF2),
      "\e[R" => Key.new(code: KeyF3),
      "\e[S" => Key.new(code: KeyF4),

      "\eOA" => Key.new(code: KeyUp),
      "\eOB" => Key.new(code: KeyDown),
      "\eOC" => Key.new(code: KeyRight),
      "\eOD" => Key.new(code: KeyLeft),
      "\eOE" => Key.new(code: KeyBegin),
      "\eOF" => Key.new(code: KeyEnd),
      "\eOH" => Key.new(code: KeyHome),
      "\eOP" => Key.new(code: KeyF1),
      "\eOQ" => Key.new(code: KeyF2),
      "\eOR" => Key.new(code: KeyF3),
      "\eOS" => Key.new(code: KeyF4),

      "\eOM" => Key.new(code: KeyKpEnter),
      "\eOX" => Key.new(code: KeyKpEqual),
      "\eOj" => Key.new(code: KeyKpMultiply),
      "\eOk" => Key.new(code: KeyKpPlus),
      "\eOl" => Key.new(code: KeyKpComma),
      "\eOm" => Key.new(code: KeyKpMinus),
      "\eOn" => Key.new(code: KeyKpDecimal),
      "\eOo" => Key.new(code: KeyKpDivide),
      "\eOp" => Key.new(code: KeyKp0),
      "\eOq" => Key.new(code: KeyKp1),
      "\eOr" => Key.new(code: KeyKp2),
      "\eOs" => Key.new(code: KeyKp3),
      "\eOt" => Key.new(code: KeyKp4),
      "\eOu" => Key.new(code: KeyKp5),
      "\eOv" => Key.new(code: KeyKp6),
      "\eOw" => Key.new(code: KeyKp7),
      "\eOx" => Key.new(code: KeyKp8),
      "\eOy" => Key.new(code: KeyKp9),

      "\e[11~" => Key.new(code: KeyF1),
      "\e[12~" => Key.new(code: KeyF2),
      "\e[13~" => Key.new(code: KeyF3),
      "\e[14~" => Key.new(code: KeyF4),
      "\e[15~" => Key.new(code: KeyF5),
      "\e[17~" => Key.new(code: KeyF6),
      "\e[18~" => Key.new(code: KeyF7),
      "\e[19~" => Key.new(code: KeyF8),
      "\e[20~" => Key.new(code: KeyF9),
      "\e[21~" => Key.new(code: KeyF10),
      "\e[23~" => Key.new(code: KeyF11),
      "\e[24~" => Key.new(code: KeyF12),
      "\e[25~" => Key.new(code: KeyF13),
      "\e[26~" => Key.new(code: KeyF14),
      "\e[28~" => Key.new(code: KeyF15),
      "\e[29~" => Key.new(code: KeyF16),
      "\e[31~" => Key.new(code: KeyF17),
      "\e[32~" => Key.new(code: KeyF18),
      "\e[33~" => Key.new(code: KeyF19),
      "\e[34~" => Key.new(code: KeyF20),
    }

    csi_tilde_keys = {
      "1"  => find,
      "2"  => Key.new(code: KeyInsert),
      "3"  => Key.new(code: KeyDelete),
      "4"  => sel,
      "5"  => Key.new(code: KeyPgUp),
      "6"  => Key.new(code: KeyPgDown),
      "7"  => Key.new(code: KeyHome),
      "8"  => Key.new(code: KeyEnd),
      "11" => Key.new(code: KeyF1),
      "12" => Key.new(code: KeyF2),
      "13" => Key.new(code: KeyF3),
      "14" => Key.new(code: KeyF4),
      "15" => Key.new(code: KeyF5),
      "17" => Key.new(code: KeyF6),
      "18" => Key.new(code: KeyF7),
      "19" => Key.new(code: KeyF8),
      "20" => Key.new(code: KeyF9),
      "21" => Key.new(code: KeyF10),
      "23" => Key.new(code: KeyF11),
      "24" => Key.new(code: KeyF12),
      "25" => Key.new(code: KeyF13),
      "26" => Key.new(code: KeyF14),
      "28" => Key.new(code: KeyF15),
      "29" => Key.new(code: KeyF16),
      "31" => Key.new(code: KeyF17),
      "32" => Key.new(code: KeyF18),
      "33" => Key.new(code: KeyF19),
      "34" => Key.new(code: KeyF20),
    }

    # URxvt key sequences
    table["\e[a"] = Key.new(code: KeyUp, mod: ModShift)
    table["\e[b"] = Key.new(code: KeyDown, mod: ModShift)
    table["\e[c"] = Key.new(code: KeyRight, mod: ModShift)
    table["\e[d"] = Key.new(code: KeyLeft, mod: ModShift)
    table["\eOa"] = Key.new(code: KeyUp, mod: ModCtrl)
    table["\eOb"] = Key.new(code: KeyDown, mod: ModCtrl)
    table["\eOc"] = Key.new(code: KeyRight, mod: ModCtrl)
    table["\eOd"] = Key.new(code: KeyLeft, mod: ModCtrl)

    csi_tilde_keys.each do |key, value|
      base = value
      base.mod = ModShift
      table["\e[#{key}$"] = base
      base = value
      base.mod = ModCtrl
      table["\e[#{key}^"] = base
      base = value
      base.mod = ModShift | ModCtrl
      table["\e[#{key}@"] = base
    end

    table["\e[23$"] = Key.new(code: KeyF11, mod: ModShift)
    table["\e[24$"] = Key.new(code: KeyF12, mod: ModShift)
    table["\e[25$"] = Key.new(code: KeyF13, mod: ModShift)
    table["\e[26$"] = Key.new(code: KeyF14, mod: ModShift)
    table["\e[28$"] = Key.new(code: KeyF15, mod: ModShift)
    table["\e[29$"] = Key.new(code: KeyF16, mod: ModShift)
    table["\e[31$"] = Key.new(code: KeyF17, mod: ModShift)
    table["\e[32$"] = Key.new(code: KeyF18, mod: ModShift)
    table["\e[33$"] = Key.new(code: KeyF19, mod: ModShift)
    table["\e[34$"] = Key.new(code: KeyF20, mod: ModShift)
    table["\e[11^"] = Key.new(code: KeyF1, mod: ModCtrl)
    table["\e[12^"] = Key.new(code: KeyF2, mod: ModCtrl)
    table["\e[13^"] = Key.new(code: KeyF3, mod: ModCtrl)
    table["\e[14^"] = Key.new(code: KeyF4, mod: ModCtrl)
    table["\e[15^"] = Key.new(code: KeyF5, mod: ModCtrl)
    table["\e[17^"] = Key.new(code: KeyF6, mod: ModCtrl)
    table["\e[18^"] = Key.new(code: KeyF7, mod: ModCtrl)
    table["\e[19^"] = Key.new(code: KeyF8, mod: ModCtrl)
    table["\e[20^"] = Key.new(code: KeyF9, mod: ModCtrl)
    table["\e[21^"] = Key.new(code: KeyF10, mod: ModCtrl)
    table["\e[23^"] = Key.new(code: KeyF11, mod: ModCtrl)
    table["\e[24^"] = Key.new(code: KeyF12, mod: ModCtrl)
    table["\e[25^"] = Key.new(code: KeyF13, mod: ModCtrl)
    table["\e[26^"] = Key.new(code: KeyF14, mod: ModCtrl)
    table["\e[28^"] = Key.new(code: KeyF15, mod: ModCtrl)
    table["\e[29^"] = Key.new(code: KeyF16, mod: ModCtrl)
    table["\e[31^"] = Key.new(code: KeyF17, mod: ModCtrl)
    table["\e[32^"] = Key.new(code: KeyF18, mod: ModCtrl)
    table["\e[33^"] = Key.new(code: KeyF19, mod: ModCtrl)
    table["\e[34^"] = Key.new(code: KeyF20, mod: ModCtrl)
    table["\e[23@"] = Key.new(code: KeyF11, mod: ModShift | ModCtrl)
    table["\e[24@"] = Key.new(code: KeyF12, mod: ModShift | ModCtrl)
    table["\e[25@"] = Key.new(code: KeyF13, mod: ModShift | ModCtrl)
    table["\e[26@"] = Key.new(code: KeyF14, mod: ModShift | ModCtrl)
    table["\e[28@"] = Key.new(code: KeyF15, mod: ModShift | ModCtrl)
    table["\e[29@"] = Key.new(code: KeyF16, mod: ModShift | ModCtrl)
    table["\e[31@"] = Key.new(code: KeyF17, mod: ModShift | ModCtrl)
    table["\e[32@"] = Key.new(code: KeyF18, mod: ModShift | ModCtrl)
    table["\e[33@"] = Key.new(code: KeyF19, mod: ModShift | ModCtrl)
    table["\e[34@"] = Key.new(code: KeyF20, mod: ModShift | ModCtrl)

    alt_map = {} of String => Key
    table.each do |seq, key|
      alt_key = key
      alt_key.mod |= ModAlt
      alt_key.text = ""
      alt_map["\e#{seq}"] = alt_key
    end
    alt_map.each do |seq, key|
      table[seq] = key
    end

    modifiers = [
      ModShift,
      ModAlt,
      ModShift | ModAlt,
      ModCtrl,
      ModShift | ModCtrl,
      ModAlt | ModCtrl,
      ModShift | ModAlt | ModCtrl,
      ModMeta,
      ModMeta | ModShift,
      ModMeta | ModAlt,
      ModMeta | ModShift | ModAlt,
      ModMeta | ModCtrl,
      ModMeta | ModShift | ModCtrl,
      ModMeta | ModAlt | ModCtrl,
      ModMeta | ModShift | ModAlt | ModCtrl,
    ]

    ss3_func_keys = {
      "M" => Key.new(code: KeyKpEnter),
      "X" => Key.new(code: KeyKpEqual),
      "j" => Key.new(code: KeyKpMultiply),
      "k" => Key.new(code: KeyKpPlus),
      "l" => Key.new(code: KeyKpComma),
      "m" => Key.new(code: KeyKpMinus),
      "n" => Key.new(code: KeyKpDecimal),
      "o" => Key.new(code: KeyKpDivide),
      "p" => Key.new(code: KeyKp0),
      "q" => Key.new(code: KeyKp1),
      "r" => Key.new(code: KeyKp2),
      "s" => Key.new(code: KeyKp3),
      "t" => Key.new(code: KeyKp4),
      "u" => Key.new(code: KeyKp5),
      "v" => Key.new(code: KeyKp6),
      "w" => Key.new(code: KeyKp7),
      "x" => Key.new(code: KeyKp8),
      "y" => Key.new(code: KeyKp9),
    }

    csi_func_keys = {
      "A" => Key.new(code: KeyUp),
      "B" => Key.new(code: KeyDown),
      "C" => Key.new(code: KeyRight),
      "D" => Key.new(code: KeyLeft),
      "E" => Key.new(code: KeyBegin),
      "F" => Key.new(code: KeyEnd),
      "H" => Key.new(code: KeyHome),
      "P" => Key.new(code: KeyF1),
      "Q" => Key.new(code: KeyF2),
      "R" => Key.new(code: KeyF3),
      "S" => Key.new(code: KeyF4),
    }

    modify_other_keys = {
      Ansi::BS  => Key.new(code: KeyBackspace),
      Ansi::HT  => Key.new(code: KeyTab),
      Ansi::CR  => Key.new(code: KeyEnter),
      Ansi::ESC => Key.new(code: KeyEscape),
      Ansi::DEL => Key.new(code: KeyBackspace),
    }

    modifiers.each do |mod|
      xterm_mod = (mod + 1).to_s
      csi_func_keys.each do |key, value|
        seq = "\e[1;#{xterm_mod}#{key}"
        mapped = value
        mapped.mod = mod
        table[seq] = mapped
      end
      ss3_func_keys.each do |key, value|
        seq = "\eO#{xterm_mod}#{key}"
        mapped = value
        mapped.mod = mod
        table[seq] = mapped
      end
      csi_tilde_keys.each do |key, value|
        seq = "\e[#{key};#{xterm_mod}~"
        mapped = value
        mapped.mod = mod
        table[seq] = mapped
      end
      modify_other_keys.each do |code, value|
        seq = "\e[27;#{xterm_mod};#{code}~"
        mapped = value
        mapped.mod = mod
        table[seq] = mapped
      end
    end

    if use_terminfo
      build_terminfo_keys(flags, term).each do |seq, key|
        table[seq] = key
      end
    end

    table
  end

  def self.build_terminfo_keys(_flags : LegacyKeyEncoding, _term : String) : Hash(String, Key)
    # TODO: implement terminfo support for Crystal.
    {} of String => Key
  end
end
