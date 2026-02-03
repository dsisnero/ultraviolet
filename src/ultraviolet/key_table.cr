require "terminfo"

module Ultraviolet
  # Legacy key encoding flags.
  FLAG_CTRL_AT           = 1_u32 << 0
  FLAG_CTRL_I            = 1_u32 << 1
  FLAG_CTRL_M            = 1_u32 << 2
  FLAG_CTRL_OPEN_BRACKET = 1_u32 << 3
  FLAG_BACKSPACE         = 1_u32 << 4
  FLAG_FIND              = 1_u32 << 5
  FLAG_SELECT            = 1_u32 << 6
  FLAG_FKEYS             = 1_u32 << 7

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
      Ansi::NUL.chr.to_s => nul,
      Ansi::SOH.chr.to_s => Key.new(code: 'a'.ord, mod: ModCtrl),
      Ansi::STX.chr.to_s => Key.new(code: 'b'.ord, mod: ModCtrl),
      Ansi::ETX.chr.to_s => Key.new(code: 'c'.ord, mod: ModCtrl),
      Ansi::EOT.chr.to_s => Key.new(code: 'd'.ord, mod: ModCtrl),
      Ansi::ENQ.chr.to_s => Key.new(code: 'e'.ord, mod: ModCtrl),
      Ansi::ACK.chr.to_s => Key.new(code: 'f'.ord, mod: ModCtrl),
      Ansi::BEL.chr.to_s => Key.new(code: 'g'.ord, mod: ModCtrl),
      Ansi::BS.chr.to_s  => Key.new(code: 'h'.ord, mod: ModCtrl),
      Ansi::HT.chr.to_s  => tab,
      Ansi::LF.chr.to_s  => Key.new(code: 'j'.ord, mod: ModCtrl),
      Ansi::VT.chr.to_s  => Key.new(code: 'k'.ord, mod: ModCtrl),
      Ansi::FF.chr.to_s  => Key.new(code: 'l'.ord, mod: ModCtrl),
      Ansi::CR.chr.to_s  => enter,
      Ansi::SO.chr.to_s  => Key.new(code: 'n'.ord, mod: ModCtrl),
      Ansi::SI.chr.to_s  => Key.new(code: 'o'.ord, mod: ModCtrl),
      Ansi::DLE.chr.to_s => Key.new(code: 'p'.ord, mod: ModCtrl),
      Ansi::DC1.chr.to_s => Key.new(code: 'q'.ord, mod: ModCtrl),
      Ansi::DC2.chr.to_s => Key.new(code: 'r'.ord, mod: ModCtrl),
      Ansi::DC3.chr.to_s => Key.new(code: 's'.ord, mod: ModCtrl),
      Ansi::DC4.chr.to_s => Key.new(code: 't'.ord, mod: ModCtrl),
      Ansi::NAK.chr.to_s => Key.new(code: 'u'.ord, mod: ModCtrl),
      Ansi::SYN.chr.to_s => Key.new(code: 'v'.ord, mod: ModCtrl),
      Ansi::ETB.chr.to_s => Key.new(code: 'w'.ord, mod: ModCtrl),
      Ansi::CAN.chr.to_s => Key.new(code: 'x'.ord, mod: ModCtrl),
      Ansi::EM.chr.to_s  => Key.new(code: 'y'.ord, mod: ModCtrl),
      Ansi::SUB.chr.to_s => Key.new(code: 'z'.ord, mod: ModCtrl),
      Ansi::ESC.chr.to_s => esc,
      Ansi::FS.chr.to_s  => Key.new(code: '\\'.ord, mod: ModCtrl),
      Ansi::GS.chr.to_s  => Key.new(code: ']'.ord, mod: ModCtrl),
      Ansi::RS.chr.to_s  => Key.new(code: '^'.ord, mod: ModCtrl),
      Ansi::US.chr.to_s  => Key.new(code: '_'.ord, mod: ModCtrl),

      Ansi::SP.chr.to_s  => Key.new(code: KeySpace, text: " "),
      Ansi::DEL.chr.to_s => del,

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

  def self.build_terminfo_keys(flags : LegacyKeyEncoding, term : String) : Hash(String, Key)
    table = {} of String => Key
    return table if term.empty? || term == "dumb"

    ti = begin
      Terminfo::Data.new term: term, extended: false
    rescue
      nil
    end
    return table unless ti

    ti_table = default_terminfo_keys(flags)
    add_terminfo_caps(table, ti_table, ti.strings)
    add_terminfo_caps(table, ti_table, ti.extended_strings)
    table
  end

  private def self.add_terminfo_caps(table : Hash(String, Key), ti_table : Hash(String, Key), caps : Hash(String, String))
    caps.each do |name, seq|
      next unless name.starts_with?("k")
      next if seq.empty?
      if key = ti_table[name]?
        table[seq] = key
      end
    end
  end

  def self.default_terminfo_keys(flags : LegacyKeyEncoding) : Hash(String, Key)
    keys = {
      "kcuu1" => Key.new(code: KeyUp),
      "kUP"   => Key.new(code: KeyUp, mod: ModShift),
      "kUP3"  => Key.new(code: KeyUp, mod: ModAlt),
      "kUP4"  => Key.new(code: KeyUp, mod: ModShift | ModAlt),
      "kUP5"  => Key.new(code: KeyUp, mod: ModCtrl),
      "kUP6"  => Key.new(code: KeyUp, mod: ModShift | ModCtrl),
      "kUP7"  => Key.new(code: KeyUp, mod: ModAlt | ModCtrl),
      "kUP8"  => Key.new(code: KeyUp, mod: ModShift | ModAlt | ModCtrl),
      "kcud1" => Key.new(code: KeyDown),
      "kDN"   => Key.new(code: KeyDown, mod: ModShift),
      "kDN3"  => Key.new(code: KeyDown, mod: ModAlt),
      "kDN4"  => Key.new(code: KeyDown, mod: ModShift | ModAlt),
      "kDN5"  => Key.new(code: KeyDown, mod: ModCtrl),
      "kDN6"  => Key.new(code: KeyDown, mod: ModShift | ModCtrl),
      "kDN7"  => Key.new(code: KeyDown, mod: ModAlt | ModCtrl),
      "kDN8"  => Key.new(code: KeyDown, mod: ModShift | ModAlt | ModCtrl),
      "kcub1" => Key.new(code: KeyLeft),
      "kLFT"  => Key.new(code: KeyLeft, mod: ModShift),
      "kLFT3" => Key.new(code: KeyLeft, mod: ModAlt),
      "kLFT4" => Key.new(code: KeyLeft, mod: ModShift | ModAlt),
      "kLFT5" => Key.new(code: KeyLeft, mod: ModCtrl),
      "kLFT6" => Key.new(code: KeyLeft, mod: ModShift | ModCtrl),
      "kLFT7" => Key.new(code: KeyLeft, mod: ModAlt | ModCtrl),
      "kLFT8" => Key.new(code: KeyLeft, mod: ModShift | ModAlt | ModCtrl),
      "kcuf1" => Key.new(code: KeyRight),
      "kRIT"  => Key.new(code: KeyRight, mod: ModShift),
      "kRIT3" => Key.new(code: KeyRight, mod: ModAlt),
      "kRIT4" => Key.new(code: KeyRight, mod: ModShift | ModAlt),
      "kRIT5" => Key.new(code: KeyRight, mod: ModCtrl),
      "kRIT6" => Key.new(code: KeyRight, mod: ModShift | ModCtrl),
      "kRIT7" => Key.new(code: KeyRight, mod: ModAlt | ModCtrl),
      "kRIT8" => Key.new(code: KeyRight, mod: ModShift | ModAlt | ModCtrl),
      "kich1" => Key.new(code: KeyInsert),
      "kIC"   => Key.new(code: KeyInsert, mod: ModShift),
      "kIC3"  => Key.new(code: KeyInsert, mod: ModAlt),
      "kIC4"  => Key.new(code: KeyInsert, mod: ModShift | ModAlt),
      "kIC5"  => Key.new(code: KeyInsert, mod: ModCtrl),
      "kIC6"  => Key.new(code: KeyInsert, mod: ModShift | ModCtrl),
      "kIC7"  => Key.new(code: KeyInsert, mod: ModAlt | ModCtrl),
      "kIC8"  => Key.new(code: KeyInsert, mod: ModShift | ModAlt | ModCtrl),
      "kdch1" => Key.new(code: KeyDelete),
      "kDC"   => Key.new(code: KeyDelete, mod: ModShift),
      "kDC3"  => Key.new(code: KeyDelete, mod: ModAlt),
      "kDC4"  => Key.new(code: KeyDelete, mod: ModShift | ModAlt),
      "kDC5"  => Key.new(code: KeyDelete, mod: ModCtrl),
      "kDC6"  => Key.new(code: KeyDelete, mod: ModShift | ModCtrl),
      "kDC7"  => Key.new(code: KeyDelete, mod: ModAlt | ModCtrl),
      "kDC8"  => Key.new(code: KeyDelete, mod: ModShift | ModAlt | ModCtrl),
      "khome" => Key.new(code: KeyHome),
      "kHOM"  => Key.new(code: KeyHome, mod: ModShift),
      "kHOM3" => Key.new(code: KeyHome, mod: ModAlt),
      "kHOM4" => Key.new(code: KeyHome, mod: ModShift | ModAlt),
      "kHOM5" => Key.new(code: KeyHome, mod: ModCtrl),
      "kHOM6" => Key.new(code: KeyHome, mod: ModShift | ModCtrl),
      "kHOM7" => Key.new(code: KeyHome, mod: ModAlt | ModCtrl),
      "kHOM8" => Key.new(code: KeyHome, mod: ModShift | ModAlt | ModCtrl),
      "kend"  => Key.new(code: KeyEnd),
      "kEND"  => Key.new(code: KeyEnd, mod: ModShift),
      "kEND3" => Key.new(code: KeyEnd, mod: ModAlt),
      "kEND4" => Key.new(code: KeyEnd, mod: ModShift | ModAlt),
      "kEND5" => Key.new(code: KeyEnd, mod: ModCtrl),
      "kEND6" => Key.new(code: KeyEnd, mod: ModShift | ModCtrl),
      "kEND7" => Key.new(code: KeyEnd, mod: ModAlt | ModCtrl),
      "kEND8" => Key.new(code: KeyEnd, mod: ModShift | ModAlt | ModCtrl),
      "kpp"   => Key.new(code: KeyPgUp),
      "kprv"  => Key.new(code: KeyPgUp),
      "kPRV"  => Key.new(code: KeyPgUp, mod: ModShift),
      "kPRV3" => Key.new(code: KeyPgUp, mod: ModAlt),
      "kPRV4" => Key.new(code: KeyPgUp, mod: ModShift | ModAlt),
      "kPRV5" => Key.new(code: KeyPgUp, mod: ModCtrl),
      "kPRV6" => Key.new(code: KeyPgUp, mod: ModShift | ModCtrl),
      "kPRV7" => Key.new(code: KeyPgUp, mod: ModAlt | ModCtrl),
      "kPRV8" => Key.new(code: KeyPgUp, mod: ModShift | ModAlt | ModCtrl),
      "knp"   => Key.new(code: KeyPgDown),
      "knxt"  => Key.new(code: KeyPgDown),
      "kNXT"  => Key.new(code: KeyPgDown, mod: ModShift),
      "kNXT3" => Key.new(code: KeyPgDown, mod: ModAlt),
      "kNXT4" => Key.new(code: KeyPgDown, mod: ModShift | ModAlt),
      "kNXT5" => Key.new(code: KeyPgDown, mod: ModCtrl),
      "kNXT6" => Key.new(code: KeyPgDown, mod: ModShift | ModCtrl),
      "kNXT7" => Key.new(code: KeyPgDown, mod: ModAlt | ModCtrl),
      "kNXT8" => Key.new(code: KeyPgDown, mod: ModShift | ModAlt | ModCtrl),
      "kbs"   => Key.new(code: KeyBackspace),
      "kcbt"  => Key.new(code: KeyTab, mod: ModShift),
      "kf1"   => Key.new(code: KeyF1),
      "kf2"   => Key.new(code: KeyF2),
      "kf3"   => Key.new(code: KeyF3),
      "kf4"   => Key.new(code: KeyF4),
      "kf5"   => Key.new(code: KeyF5),
      "kf6"   => Key.new(code: KeyF6),
      "kf7"   => Key.new(code: KeyF7),
      "kf8"   => Key.new(code: KeyF8),
      "kf9"   => Key.new(code: KeyF9),
      "kf10"  => Key.new(code: KeyF10),
      "kf11"  => Key.new(code: KeyF11),
      "kf12"  => Key.new(code: KeyF12),
      "kf13"  => Key.new(code: KeyF1, mod: ModShift),
      "kf14"  => Key.new(code: KeyF2, mod: ModShift),
      "kf15"  => Key.new(code: KeyF3, mod: ModShift),
      "kf16"  => Key.new(code: KeyF4, mod: ModShift),
      "kf17"  => Key.new(code: KeyF5, mod: ModShift),
      "kf18"  => Key.new(code: KeyF6, mod: ModShift),
      "kf19"  => Key.new(code: KeyF7, mod: ModShift),
      "kf20"  => Key.new(code: KeyF8, mod: ModShift),
      "kf21"  => Key.new(code: KeyF9, mod: ModShift),
      "kf22"  => Key.new(code: KeyF10, mod: ModShift),
      "kf23"  => Key.new(code: KeyF11, mod: ModShift),
      "kf24"  => Key.new(code: KeyF12, mod: ModShift),
      "kf25"  => Key.new(code: KeyF1, mod: ModCtrl),
      "kf26"  => Key.new(code: KeyF2, mod: ModCtrl),
      "kf27"  => Key.new(code: KeyF3, mod: ModCtrl),
      "kf28"  => Key.new(code: KeyF4, mod: ModCtrl),
      "kf29"  => Key.new(code: KeyF5, mod: ModCtrl),
      "kf30"  => Key.new(code: KeyF6, mod: ModCtrl),
      "kf31"  => Key.new(code: KeyF7, mod: ModCtrl),
      "kf32"  => Key.new(code: KeyF8, mod: ModCtrl),
      "kf33"  => Key.new(code: KeyF9, mod: ModCtrl),
      "kf34"  => Key.new(code: KeyF10, mod: ModCtrl),
      "kf35"  => Key.new(code: KeyF11, mod: ModCtrl),
      "kf36"  => Key.new(code: KeyF12, mod: ModCtrl),
      "kf37"  => Key.new(code: KeyF1, mod: ModShift | ModCtrl),
      "kf38"  => Key.new(code: KeyF2, mod: ModShift | ModCtrl),
      "kf39"  => Key.new(code: KeyF3, mod: ModShift | ModCtrl),
      "kf40"  => Key.new(code: KeyF4, mod: ModShift | ModCtrl),
      "kf41"  => Key.new(code: KeyF5, mod: ModShift | ModCtrl),
      "kf42"  => Key.new(code: KeyF6, mod: ModShift | ModCtrl),
      "kf43"  => Key.new(code: KeyF7, mod: ModShift | ModCtrl),
      "kf44"  => Key.new(code: KeyF8, mod: ModShift | ModCtrl),
      "kf45"  => Key.new(code: KeyF9, mod: ModShift | ModCtrl),
      "kf46"  => Key.new(code: KeyF10, mod: ModShift | ModCtrl),
      "kf47"  => Key.new(code: KeyF11, mod: ModShift | ModCtrl),
      "kf48"  => Key.new(code: KeyF12, mod: ModShift | ModCtrl),
      "kf49"  => Key.new(code: KeyF1, mod: ModAlt),
      "kf50"  => Key.new(code: KeyF2, mod: ModAlt),
      "kf51"  => Key.new(code: KeyF3, mod: ModAlt),
      "kf52"  => Key.new(code: KeyF4, mod: ModAlt),
      "kf53"  => Key.new(code: KeyF5, mod: ModAlt),
      "kf54"  => Key.new(code: KeyF6, mod: ModAlt),
      "kf55"  => Key.new(code: KeyF7, mod: ModAlt),
      "kf56"  => Key.new(code: KeyF8, mod: ModAlt),
      "kf57"  => Key.new(code: KeyF9, mod: ModAlt),
      "kf58"  => Key.new(code: KeyF10, mod: ModAlt),
      "kf59"  => Key.new(code: KeyF11, mod: ModAlt),
      "kf60"  => Key.new(code: KeyF12, mod: ModAlt),
      "kf61"  => Key.new(code: KeyF1, mod: ModShift | ModAlt),
      "kf62"  => Key.new(code: KeyF2, mod: ModShift | ModAlt),
      "kf63"  => Key.new(code: KeyF3, mod: ModShift | ModAlt),
    }

    if flags.contains?(FLAG_FKEYS)
      keys["kf13"] = Key.new(code: KeyF13)
      keys["kf14"] = Key.new(code: KeyF14)
      keys["kf15"] = Key.new(code: KeyF15)
      keys["kf16"] = Key.new(code: KeyF16)
      keys["kf17"] = Key.new(code: KeyF17)
      keys["kf18"] = Key.new(code: KeyF18)
      keys["kf19"] = Key.new(code: KeyF19)
      keys["kf20"] = Key.new(code: KeyF20)
      keys["kf21"] = Key.new(code: KeyF21)
      keys["kf22"] = Key.new(code: KeyF22)
      keys["kf23"] = Key.new(code: KeyF23)
      keys["kf24"] = Key.new(code: KeyF24)
      keys["kf25"] = Key.new(code: KeyF25)
      keys["kf26"] = Key.new(code: KeyF26)
      keys["kf27"] = Key.new(code: KeyF27)
      keys["kf28"] = Key.new(code: KeyF28)
      keys["kf29"] = Key.new(code: KeyF29)
      keys["kf30"] = Key.new(code: KeyF30)
      keys["kf31"] = Key.new(code: KeyF31)
      keys["kf32"] = Key.new(code: KeyF32)
      keys["kf33"] = Key.new(code: KeyF33)
      keys["kf34"] = Key.new(code: KeyF34)
      keys["kf35"] = Key.new(code: KeyF35)
      keys["kf36"] = Key.new(code: KeyF36)
      keys["kf37"] = Key.new(code: KeyF37)
      keys["kf38"] = Key.new(code: KeyF38)
      keys["kf39"] = Key.new(code: KeyF39)
      keys["kf40"] = Key.new(code: KeyF40)
      keys["kf41"] = Key.new(code: KeyF41)
      keys["kf42"] = Key.new(code: KeyF42)
      keys["kf43"] = Key.new(code: KeyF43)
      keys["kf44"] = Key.new(code: KeyF44)
      keys["kf45"] = Key.new(code: KeyF45)
      keys["kf46"] = Key.new(code: KeyF46)
      keys["kf47"] = Key.new(code: KeyF47)
      keys["kf48"] = Key.new(code: KeyF48)
      keys["kf49"] = Key.new(code: KeyF49)
      keys["kf50"] = Key.new(code: KeyF50)
      keys["kf51"] = Key.new(code: KeyF51)
      keys["kf52"] = Key.new(code: KeyF52)
      keys["kf53"] = Key.new(code: KeyF53)
      keys["kf54"] = Key.new(code: KeyF54)
      keys["kf55"] = Key.new(code: KeyF55)
      keys["kf56"] = Key.new(code: KeyF56)
      keys["kf57"] = Key.new(code: KeyF57)
      keys["kf58"] = Key.new(code: KeyF58)
      keys["kf59"] = Key.new(code: KeyF59)
      keys["kf60"] = Key.new(code: KeyF60)
      keys["kf61"] = Key.new(code: KeyF61)
      keys["kf62"] = Key.new(code: KeyF62)
      keys["kf63"] = Key.new(code: KeyF63)
    end

    alias_map = {
      "key_up"        => "kcuu1",
      "key_down"      => "kcud1",
      "key_left"      => "kcub1",
      "key_right"     => "kcuf1",
      "key_home"      => "khome",
      "key_end"       => "kend",
      "key_npage"     => "knp",
      "key_ppage"     => "kpp",
      "key_ic"        => "kich1",
      "key_dc"        => "kdch1",
      "key_backspace" => "kbs",
      "key_btab"      => "kcbt",
    }

    alias_map.each do |alias_name, short_name|
      if key = keys[short_name]?
        keys[alias_name] = key
      end
    end

    1.upto(63) do |idx|
      short_name = "kf#{idx}"
      if key = keys[short_name]?
        keys["key_f#{idx}"] = key
      end
    end

    keys
  end
end
