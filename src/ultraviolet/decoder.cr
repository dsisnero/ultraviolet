require "base64"
require "textseg"

module Ultraviolet
  class EventDecoder
    property legacy : LegacyKeyEncoding
    property? use_terminfo : Bool

    @@kitty_key_map : Hash(Int32, Key)? = nil

    @last_cks : UInt32 = 0

    private UNHANDLED_EVENT = UnknownEvent.new("")

    private struct CsiResult
      getter consumed : Int32
      getter event : Event
      getter? handled : Bool

      def initialize(@consumed : Int32, @event : Event, @handled : Bool)
      end

      def self.handled(consumed : Int32, event : Event) : CsiResult
        new(consumed, event, true)
      end

      def self.unhandled : CsiResult
        new(0, UNHANDLED_EVENT, false)
      end
    end

    private def handled_csi(consumed : Int32, event : Event) : CsiResult
      CsiResult.handled(consumed, event)
    end

    def initialize(@legacy : LegacyKeyEncoding = LegacyKeyEncoding.new, @use_terminfo : Bool = false)
    end

    private def param_value(param : Ansi::Param, default : Int32) : Int32
      p = param & Ansi::ParserTransition::ParamMask
      p == Ansi::ParserTransition::MissingParam ? default : p
    end

    private def param_has_more?(param : Ansi::Param) : Bool
      (param & Ansi::ParserTransition::HasMoreFlag) != 0
    end

    private def uv_color(color : Ansi::Color) : Ultraviolet::Color
      Ultraviolet::Color.new(color.r, color.g, color.b)
    end

    private def round(x : Float64) : Float64
      (x * 1000).round / 1000.0
    end

    def decode(buf : Bytes) : {Int32, Event?}
      return {0, nil} if buf.empty?

      b = buf[0]
      case b
      when Ansi::ESC
        decode_escape(buf)
      when Ansi::SS3
        parse_ss3(buf)
      when Ansi::DCS
        parse_dcs(buf)
      when Ansi::CSI
        parse_csi(buf)
      when Ansi::OSC
        parse_osc(buf)
      when Ansi::APC
        parse_apc(buf)
      when Ansi::PM
        parse_st_terminated(Ansi::PM, '^'.ord, nil).call(buf)
      when Ansi::SOS
        parse_st_terminated(Ansi::SOS, 'X'.ord, nil).call(buf)
      else
        decode_other(buf)
      end
    end

    private def decode_escape(buf : Bytes) : {Int32, Event?}
      return {1, Key.new(code: KeyEscape)} if buf.size == 1

      case buf[1]
      when 'O'.ord
        parse_ss3(buf)
      when 'P'.ord
        parse_dcs(buf)
      when '['.ord
        parse_csi(buf)
      when ']'.ord
        parse_osc(buf)
      when '_'.ord
        parse_apc(buf)
      when '^'.ord
        parse_st_terminated(Ansi::PM, '^'.ord, nil).call(buf)
      when 'X'.ord
        parse_st_terminated(Ansi::SOS, 'X'.ord, nil).call(buf)
      else
        n, event = decode(buf[1..])
        if event.is_a?(Key)
          key = event.as(Key)
          key.text = ""
          key.mod |= ModAlt
          return {n + 1, key}
        end
        {1, Key.new(code: KeyEscape)}
      end
    end

    private def decode_other(buf : Bytes) : {Int32, Event?}
      b = buf[0]
      if b <= Ansi::US || b == Ansi::DEL || b == Ansi::SP
        return {1, parse_control(b)}
      end
      if b >= Ansi::PAD && b <= Ansi::APC
        code = b.to_i - 0x40
        return {1, Key.new(code: code, mod: ModCtrl | ModAlt)}
      end
      parse_utf8(buf)
    end

    private def parse_csi(buf : Bytes) : {Int32, Event}
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, Key.new(code: buf[1].to_i, mod: ModAlt)}
      end

      cmd, params, i, intermed, ok = parse_csi_header(buf)
      unless ok
        if intermed == '$'.ord && i > 0 && buf[i - 1] == '$'.ord
          extended = Bytes.new(i)
          extended.copy_from(buf[0, i - 1])
          extended[i - 1] = '~'.ord.to_u8
          n, event = parse_csi(extended)
          if event.is_a?(Key)
            key = event.as(Key)
            key.mod |= ModShift
            return {n, key}
          end
        end
        return {i, UnknownEvent.new(String.new(buf[0, i]))}
      end

      pa = Ansi::Params.new(params)
      result = handle_csi_command(cmd, params, pa, buf, i)
      return {result.consumed, result.event} if result.handled?

      {i, UnknownCsiEvent.new(String.new(buf[0, i]))}
    end

    private def parse_csi_header(buf : Bytes) : {Int32, Array(Ansi::Param), Int32, UInt8, Bool}
      i = 0
      cmd, i = parse_csi_prefix(buf, i)
      params, i = parse_csi_params(buf, i)
      intermed, i = parse_csi_intermed(buf, i)
      cmd |= (intermed.to_i << Ansi::ParserTransition::IntermedShift)
      cmd, i, ok = parse_csi_final(buf, cmd, i)

      {cmd, params, i, intermed, ok}
    end

    private def parse_csi_prefix(buf : Bytes, i : Int32) : {Int32, Int32}
      cmd = 0
      if buf[i] == Ansi::CSI || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == '['.ord
        i += 1
      end
      if i < buf.size && buf[i] >= '<'.ord && buf[i] <= '?'.ord
        cmd |= (buf[i].to_i << Ansi::ParserTransition::PrefixShift)
      end
      {cmd, i}
    end

    private def parse_csi_params(buf : Bytes, i : Int32) : {Array(Ansi::Param), Int32}
      params, i, _ = parse_params(buf, i, Ansi::ParserTransition::MaxParamsSize)
      {params, i}
    end

    private def parse_params(buf : Bytes, i : Int32, max : Int32) : {Array(Ansi::Param), Int32, Int32}
      params = [] of Ansi::Param
      param_bytes = 0
      current = Ansi::ParserTransition::MissingParam
      while i < buf.size && params.size < max && csi_param_byte?(buf[i])
        param_bytes += 1
        current = update_param_from_byte(current, params, buf[i])
        i += 1
      end

      if param_bytes > 0 && params.size < max
        params << current
      end

      {params, i, param_bytes}
    end

    private def csi_param_byte?(byte : UInt8) : Bool
      byte >= 0x30 && byte <= 0x3f
    end

    private def csi_digit?(byte : UInt8) : Bool
      byte >= '0'.ord && byte <= '9'.ord
    end

    private def update_param_from_byte(current : Ansi::Param, params : Array(Ansi::Param), byte : UInt8) : Ansi::Param
      if csi_digit?(byte)
        if current == Ansi::ParserTransition::MissingParam
          current = 0
        end
        current = (current & Ansi::ParserTransition::ParamMask) * 10 + (byte - '0'.ord)
      end
      if byte == ':'.ord
        current |= Ansi::ParserTransition::HasMoreFlag
      end
      if byte == ';'.ord || byte == ':'.ord
        params << current
        return Ansi::ParserTransition::MissingParam
      end
      current
    end

    private def parse_csi_intermed(buf : Bytes, i : Int32) : {UInt8, Int32}
      intermed = 0_u8
      while i < buf.size && buf[i] >= 0x20 && buf[i] <= 0x2f
        intermed = buf[i]
        i += 1
      end
      {intermed, i}
    end

    private def parse_csi_final(buf : Bytes, cmd : Int32, i : Int32) : {Int32, Int32, Bool}
      return {cmd, i, false} if i >= buf.size || buf[i] < 0x40 || buf[i] > 0x7e
      cmd |= buf[i].to_i
      i += 1
      {cmd, i, true}
    end

    private def handle_csi_command(cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      result = handle_csi_prefixed(cmd, params, pa, buf, i)
      return result if result.handled?

      result = handle_csi_unprefixed(cmd, params, pa, buf, i)
      return result if result.handled?

      if csi_simple_key_cmd?(cmd)
        return handle_csi_simple_keys(cmd, params, pa, buf, i)
      end

      CsiResult.unhandled
    end

    private def handle_csi_prefixed(cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      case cmd
      when ('y'.ord | ('?'.ord << Ansi::ParserTransition::PrefixShift) | ('$'.ord << Ansi::ParserTransition::IntermedShift))
        handle_csi_mode_report('y'.ord, params, pa, buf, i)
      when ('c'.ord | ('?'.ord << Ansi::ParserTransition::PrefixShift))
        handled_csi(i, parse_primary_dev_attrs(pa))
      when ('c'.ord | ('>'.ord << Ansi::ParserTransition::PrefixShift))
        handled_csi(i, parse_secondary_dev_attrs(pa))
      when ('u'.ord | ('?'.ord << Ansi::ParserTransition::PrefixShift))
        handle_csi_keyboard_enhancements('u'.ord, pa, i)
      when ('R'.ord | ('?'.ord << Ansi::ParserTransition::PrefixShift))
        handle_csi_cursor_report('R'.ord, pa, buf, i)
      when ('m'.ord | ('<'.ord << Ansi::ParserTransition::PrefixShift)), ('M'.ord | ('<'.ord << Ansi::ParserTransition::PrefixShift))
        handle_csi_mouse_sgr(cmd & 0xff, params, pa, i)
      when ('m'.ord | ('>'.ord << Ansi::ParserTransition::PrefixShift))
        handle_csi_modify_other_keys('m'.ord, pa, buf, i)
      when ('n'.ord | ('?'.ord << Ansi::ParserTransition::PrefixShift))
        handle_csi_color_scheme('n'.ord, pa, i)
      else
        CsiResult.unhandled
      end
    end

    private def handle_csi_unprefixed(cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      case cmd
      when 'I'.ord
        handled_csi(i, FocusEvent.new)
      when 'O'.ord
        handled_csi(i, BlurEvent.new)
      when 'R'.ord
        handle_csi_cursor_or_f3('R'.ord, params, pa, buf, i)
      when 'M'.ord
        handle_csi_x10_mouse('M'.ord, buf, i)
      when ('y'.ord | ('$'.ord << Ansi::ParserTransition::IntermedShift))
        handle_csi_mode_report('y'.ord, params, pa, buf, i)
      when 'u'.ord
        handle_csi_kitty_keyboard('u'.ord, params, pa, buf, i)
      when '_'.ord
        handle_csi_win32_input('_'.ord, params, pa, buf, i)
      when '@'.ord, '^'.ord, '~'.ord
        handle_csi_tilde_keys(cmd & 0xff, params, pa, buf, i)
      when 't'.ord
        handle_csi_window_ops('t'.ord, params, pa, buf, i)
      else
        CsiResult.unhandled
      end
    end

    protected def handle_csi_mode_report(cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      mode, _, ok = pa.param(0, -1)
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) unless ok && mode != -1
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) if params.size < 2
      value, _, _ = pa.param(1, Ansi::ModeNotRecognized.value.to_i)
      handled_csi(i, ModeReportEvent.new(mode, value))
    end

    protected def handle_csi_keyboard_enhancements(_cmd : Int32, pa : Ansi::Params, i : Int32) : CsiResult
      flags, _, _ = pa.param(0, 0)
      handled_csi(i, KeyboardEnhancementsEvent.new(flags))
    end

    protected def handle_csi_cursor_report(_cmd : Int32, pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      row, _, _ = pa.param(0, 1)
      col, _, ok = pa.param(1, 1)
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) unless ok
      handled_csi(i, CursorPositionEvent.new(row - 1, col - 1))
    end

    protected def handle_csi_mouse_sgr(cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, i : Int32) : CsiResult
      return CsiResult.unhandled unless params.size == 3
      handled_csi(i, parse_sgr_mouse_event(cmd, pa))
    end

    protected def handle_csi_modify_other_keys(_cmd : Int32, pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      mok, _, ok = pa.param(0, 0)
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) unless ok && mok == 4
      val, _, ok = pa.param(1, -1)
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) unless ok && val != -1
      handled_csi(i, ModifyOtherKeysEvent.new(val))
    end

    protected def handle_csi_color_scheme(_cmd : Int32, pa : Ansi::Params, i : Int32) : CsiResult
      report, _, _ = pa.param(0, -1)
      dark_light, _, _ = pa.param(1, -1)
      return handled_csi(i, DarkColorSchemeEvent.new) if report == 997 && dark_light == 1
      return handled_csi(i, LightColorSchemeEvent.new) if report == 997 && dark_light == 2
      CsiResult.unhandled
    end

    protected def handle_csi_cursor_or_f3(_cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      return handled_csi(i, Key.new(code: KeyF3)) if params.empty?

      row, _, row_ok = pa.param(0, 1)
      col, _, col_ok = pa.param(1, 1)
      if params.size == 2 && row_ok && col_ok
        m = CursorPositionEvent.new(row - 1, col - 1)
        if row == 1 && (col - 1) <= (ModMeta | ModShift | ModAlt | ModCtrl)
          events = [] of EventSingle
          events << Key.new(code: KeyF3, mod: col - 1)
          events << m
          return handled_csi(i, events)
        end
        return handled_csi(i, m)
      end

      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) if params.size != 0
      CsiResult.unhandled
    end

    private def csi_simple_key_cmd?(cmd : Int32) : Bool
      key = cmd & 0xff
      {'a'.ord, 'b'.ord, 'c'.ord, 'd'.ord, 'A'.ord, 'B'.ord, 'C'.ord, 'D'.ord, 'E'.ord, 'F'.ord, 'H'.ord, 'P'.ord, 'Q'.ord, 'S'.ord, 'Z'.ord}.includes?(key)
    end

    private def handle_csi_simple_keys(cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      key = simple_csi_key(cmd)
      id, _, _ = pa.param(0, 1)
      mod, _, _ = pa.param(1, 1)
      if (params.size > 2 && !param_has_more?(pa[1])) || id != 1
        return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i])))
      end
      if params.size > 1 && id == 1 && mod != -1
        key.mod |= (mod - 1)
      end

      handled_csi(i, parse_kitty_keyboard_ext(pa, key))
    end

    private def simple_csi_key(cmd : Int32) : Key
      case cmd & 0xff
      when 'a'.ord, 'b'.ord, 'c'.ord, 'd'.ord
        Key.new(code: KeyUp + (cmd & 0xff) - 'a'.ord, mod: ModShift)
      when 'A'.ord, 'B'.ord, 'C'.ord, 'D'.ord
        Key.new(code: KeyUp + (cmd & 0xff) - 'A'.ord)
      when 'E'.ord
        Key.new(code: KeyBegin)
      when 'F'.ord
        Key.new(code: KeyEnd)
      when 'H'.ord
        Key.new(code: KeyHome)
      when 'P'.ord, 'Q'.ord, 'R'.ord, 'S'.ord
        Key.new(code: KeyF1 + (cmd & 0xff) - 'P'.ord)
      else
        Key.new(code: KeyTab, mod: ModShift)
      end
    end

    protected def handle_csi_x10_mouse(_cmd : Int32, buf : Bytes, i : Int32) : CsiResult
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) if i + 3 > buf.size
      data = Bytes.new(i + 3)
      data.copy_from(buf[0, i])
      data[i, 3].copy_from(buf[i, 3])
      handled_csi(i + 3, parse_x10_mouse_event(data))
    end

    protected def handle_csi_kitty_keyboard(_cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) if params.empty?
      handled_csi(i, parse_kitty_keyboard(pa))
    end

    protected def handle_csi_win32_input(_cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) if params.size != 6

      vk, _, _ = pa.param(0, 0)
      sc, _, _ = pa.param(1, 0)
      uc, _, _ = pa.param(2, 0)
      kd, _, _ = pa.param(3, 0)
      cs, _, _ = pa.param(4, 0)
      rc, _, _ = pa.param(5, 0)
      event = parse_win32_input_key_event(vk.to_u16, sc.to_u16, uc, kd == 1, cs.to_u32, {1, rc}.max.to_u16)
      handled_csi(i, event)
    end

    protected def handle_csi_tilde_keys(cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) if params.empty?

      param, _, _ = pa.param(0, 0)
      if (cmd & 0xff) == '~'.ord && tilde_special_param?(param)
        result = handle_csi_special_tilde(cmd, param, params, pa, buf, i)
        return result if result.handled?
      end

      if key = csi_tilde_key(param)
        mod, _, _ = pa.param(1, -1)
        if params.size > 1 && mod != -1
          key.mod |= (mod - 1)
        end
        key = apply_csi_tilde_mod(cmd, key, pa)
        return handled_csi(i, key)
      end

      CsiResult.unhandled
    end

    private def tilde_special_param?(param : Int32) : Bool
      param == 27 || param == 200 || param == 201
    end

    private def handle_csi_special_tilde(_cmd : Int32, param : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      case param
      when 27
        return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) if params.size != 3
        return handled_csi(i, parse_xterm_modify_other_keys(pa))
      when 200
        return handled_csi(i, PasteStartEvent.new)
      when 201
        return handled_csi(i, PasteEndEvent.new)
      end
      CsiResult.unhandled
    end

    private TILDE_LEGACY_CODES = {
      2 => KeyInsert,
      3 => KeyDelete,
      5 => KeyPgUp,
      6 => KeyPgDown,
      7 => KeyHome,
      8 => KeyEnd,
    }

    private def csi_tilde_key(param : Int32) : Key?
      tilde_legacy_key(param)
    end

    private def tilde_legacy_key(param : Int32) : Key?
      if param == 1
        return Key.new(code: KeyFind) if @legacy.contains?(FLAG_FIND)
        return Key.new(code: KeyHome)
      end
      if param == 4
        return Key.new(code: KeySelect) if @legacy.contains?(FLAG_SELECT)
        return Key.new(code: KeyEnd)
      end
      if code = TILDE_LEGACY_CODES[param]?
        return Key.new(code: code)
      end
      tilde_function_key(param)
    end

    private def tilde_function_key(param : Int32) : Key?
      return Key.new(code: KeyF1 + param - 11) if (11..15).includes?(param)
      return Key.new(code: KeyF6 + param - 17) if (17..21).includes?(param)
      return Key.new(code: KeyF11 + param - 23) if (23..26).includes?(param)
      return Key.new(code: KeyF15 + param - 28) if (28..29).includes?(param)
      return Key.new(code: KeyF17 + param - 31) if (31..34).includes?(param)
      nil
    end

    private def apply_csi_tilde_mod(cmd : Int32, key : Key, pa : Ansi::Params) : Key
      case cmd & 0xff
      when '~'.ord
        return parse_kitty_keyboard_ext(pa, key)
      when '^'.ord
        key.mod |= ModCtrl
      when '@'.ord
        key.mod |= ModCtrl | ModShift
      end
      key
    end

    protected def handle_csi_window_ops(_cmd : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      param, _, ok = pa.param(0, 0)
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) unless ok

      result = handle_csi_window_op_sizes(param, params, pa, buf, i)
      return result if result.handled?

      winop = WindowOpEvent.new(param)
      j = 1
      while j < params.size
        val, _, ok = pa.param(j, 0)
        winop.args << val if ok
        j += 1
      end
      handled_csi(i, winop)
    end

    private def handle_csi_window_op_sizes(param : Int32, params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      case param
      when 4
        return window_op_size(params, pa, buf, i) { |width, height| PixelSizeEvent.new(width, height) }
      when 6
        return window_op_size(params, pa, buf, i) { |width, height| CellSizeEvent.new(width, height) }
      when 8
        return window_op_size(params, pa, buf, i) { |width, height| WindowSizeEvent.new(width, height) }
      when 48
        return window_op_size_48(params, pa, buf, i)
      end
      CsiResult.unhandled
    end

    private def window_op_size(params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32, & : Int32, Int32 -> Event) : CsiResult
      return CsiResult.unhandled unless params.size == 3
      height, _, h_ok = pa.param(1, 0)
      width, _, w_ok = pa.param(2, 0)
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) unless h_ok && w_ok
      handled_csi(i, yield width, height)
    end

    private def window_op_size_48(params : Array(Ansi::Param), pa : Ansi::Params, buf : Bytes, i : Int32) : CsiResult
      return CsiResult.unhandled unless params.size == 5
      cell_height, _, ch_ok = pa.param(1, 0)
      cell_width, _, cw_ok = pa.param(2, 0)
      pixel_height, _, ph_ok = pa.param(3, 0)
      pixel_width, _, pw_ok = pa.param(4, 0)
      return handled_csi(i, UnknownCsiEvent.new(String.new(buf[0, i]))) unless ch_ok && cw_ok && ph_ok && pw_ok
      events = [] of EventSingle
      events << WindowSizeEvent.new(cell_width, cell_height)
      events << PixelSizeEvent.new(pixel_width, pixel_height)
      handled_csi(i, events)
    end

    private def parse_ss3_intro(buf : Bytes) : Int32
      i = 0
      if buf[i] == Ansi::SS3 || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == 'O'.ord
        i += 1
      end
      i
    end

    private def parse_ss3_modifier(buf : Bytes, i : Int32) : {Int32, Int32}
      mod = 0
      while i < buf.size && buf[i] >= '0'.ord && buf[i] <= '9'.ord
        mod *= 10
        mod += buf[i] - '0'.ord
        i += 1
      end
      {mod, i}
    end

    private def ss3_key_for(gl : UInt8) : Key?
      if key = ss3_arrow_ctrl_key(gl)
        return key
      end
      if key = ss3_arrow_key(gl)
        return key
      end
      if key = ss3_special_key(gl)
        return key
      end
      if key = ss3_function_key(gl)
        return key
      end
      ss3_keypad_key(gl)
    end

    private def ss3_arrow_ctrl_key(gl : UInt8) : Key?
      return nil unless gl >= 'a'.ord && gl <= 'd'.ord
      Key.new(code: KeyUp + gl - 'a'.ord, mod: ModCtrl)
    end

    private def ss3_arrow_key(gl : UInt8) : Key?
      return nil unless gl >= 'A'.ord && gl <= 'D'.ord
      Key.new(code: KeyUp + gl - 'A'.ord)
    end

    private def ss3_special_key(gl : UInt8) : Key?
      case gl
      when 'E'.ord
        Key.new(code: KeyBegin)
      when 'F'.ord
        Key.new(code: KeyEnd)
      when 'H'.ord
        Key.new(code: KeyHome)
      else
        nil
      end
    end

    private def ss3_function_key(gl : UInt8) : Key?
      return nil unless gl >= 'P'.ord && gl <= 'S'.ord
      Key.new(code: KeyF1 + gl - 'P'.ord)
    end

    private def ss3_keypad_key(gl : UInt8) : Key?
      return Key.new(code: KeyKpEnter) if gl == 'M'.ord
      return Key.new(code: KeyKpEqual) if gl == 'X'.ord
      return nil unless gl >= 'j'.ord && gl <= 'y'.ord
      Key.new(code: KeyKpMultiply + gl - 'j'.ord)
    end

    private def parse_ss3(buf : Bytes) : {Int32, Event}
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, key_from_byte(buf[1], ModShift | ModAlt)}
      end

      i = parse_ss3_intro(buf)
      mod, i = parse_ss3_modifier(buf, i)

      if i >= buf.size || buf[i] < 0x21 || buf[i] > 0x7e
        return {i, UnknownEvent.new(String.new(buf[0, i]))}
      end

      gl = buf[i]
      i += 1

      key = ss3_key_for(gl)
      return {i, UnknownSs3Event.new(String.new(buf[0, i]))} unless key

      key.mod |= (mod - 1) if mod > 0

      {i, key}
    end

    private def parse_osc(buf : Bytes) : {Int32, Event}
      default_key = Key.new(code: buf[1].to_i, mod: ModAlt)
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, default_key}
      end

      i = parse_osc_intro(buf)
      cmd, i = parse_osc_cmd(buf, i)
      start = i
      if i < buf.size && buf[i] == ';'.ord
        i += 1
        start = i
      end

      ending, i, term = scan_osc_terminator(buf, i)
      return {i, UnknownEvent.new(String.new(buf[0, i]))} if term == 0_u8
      i, early = handle_osc_termination(term, buf, i, cmd, start, ending, default_key)
      return {i, early} if early

      if ending <= start
        if cmd == 52
          return {i, ClipboardEvent.new}
        end
        return {i, UnknownEvent.new(String.new(buf[0, i]))}
      end

      data = String.new(buf[start, ending - start])
      if event = osc_event_for(cmd, data)
        return {i, event}
      end

      {i, UnknownOscEvent.new(String.new(buf[0, i]))}
    end

    private def handle_osc_termination(
      term : UInt8,
      buf : Bytes,
      i : Int32,
      cmd : Int32,
      start : Int32,
      ending : Int32,
      default_key : Key,
    ) : {Int32, Event?}
      case term
      when Ansi::CAN, Ansi::SUB
        return {i, String.new(buf[0, i])}
      when Ansi::ESC
        if i >= buf.size || buf[i] != '\\'.ord
          if cmd == -1 || (start == 0 && ending == 2)
            return {2, default_key}
          end
          return {i, String.new(buf[0, i])}
        end
        return {i + 1, nil}
      else
        return {i, nil}
      end
    end

    private def parse_osc_intro(buf : Bytes) : Int32
      i = 0
      if buf[i] == Ansi::OSC || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == ']'.ord
        i += 1
      end
      i
    end

    private def parse_osc_cmd(buf : Bytes, i : Int32) : {Int32, Int32}
      cmd = -1
      while i < buf.size && buf[i] >= '0'.ord && buf[i] <= '9'.ord
        cmd = 0 if cmd == -1
        cmd = cmd * 10 + (buf[i] - '0'.ord)
        i += 1
      end
      {cmd, i}
    end

    private def scan_osc_terminator(buf : Bytes, i : Int32) : {Int32, Int32, UInt8}
      while i < buf.size
        byte = buf[i]
        if osc_terminator?(byte)
          return {i, i + 1, byte}
        end
        i += 1
      end
      {i, i, 0_u8}
    end

    private def osc_terminator?(byte : UInt8) : Bool
      byte == Ansi::BEL || byte == Ansi::ESC || byte == Ansi::ST || byte == Ansi::CAN || byte == Ansi::SUB
    end

    private def osc_event_for(cmd : Int32, data : String) : Event?
      case cmd
      when 10
        if color = Ansi.x_parse_color(data)
          ForegroundColorEvent.new(uv_color(color))
        else
          ForegroundColorEvent.new(Ultraviolet::Color.new(0_u8, 0_u8, 0_u8))
        end
      when 11
        if color = Ansi.x_parse_color(data)
          BackgroundColorEvent.new(uv_color(color))
        else
          BackgroundColorEvent.new(Ultraviolet::Color.new(0_u8, 0_u8, 0_u8))
        end
      when 12
        if color = Ansi.x_parse_color(data)
          CursorColorEvent.new(uv_color(color))
        else
          CursorColorEvent.new(Ultraviolet::Color.new(0_u8, 0_u8, 0_u8))
        end
      when 52
        osc_clipboard_event(data)
      else
        nil
      end
    end

    private def osc_clipboard_event(data : String) : Event
      parts = data.split(';')
      return ClipboardEvent.new if parts.size != 2 || parts[0].empty?

      selection = parts[0][0]
      b64 = parts[1]
      begin
        decoded = Base64.decode_string(b64)
      rescue
        return ClipboardEvent.new(parts[1], selection)
      end

      ClipboardEvent.new(decoded, selection)
    end

    private def parse_st_terminated(intro8 : Int32, intro7 : Int32, fn : (Bytes -> Event?)?) : Proc(Bytes, {Int32, Event?})
      ->(bytes : Bytes) : {Int32, Event?} { parse_st_terminated_bytes(intro8, intro7, fn, bytes) }
    end

    private def parse_st_terminated_bytes(intro8 : Int32, intro7 : Int32, fn : (Bytes -> Event?)?, bytes : Bytes) : {Int32, Event?}
      if bytes.size == 2 && bytes[0] == Ansi::ESC
        return st_default_key(intro8, bytes)
      end

      i = st_intro_index(bytes, intro8, intro7)
      start = i
      ending, i, term = scan_st_terminator(bytes, i)
      return {i, UnknownEvent.new(String.new(bytes[0, i]))} if term == 0_u8

      case term
      when Ansi::CAN, Ansi::SUB
        return {i, String.new(bytes[0, i])}
      when Ansi::ESC
        if i >= bytes.size || bytes[i] != '\\'.ord
          return st_default_key(intro8, bytes) if start == ending
          return {i, String.new(bytes[0, i])}
        end
        i += 1
      end

      if fn
        event = fn.call(bytes[start, ending - start])
        return {i, event} if event
      end

      {i, st_unknown_event(intro8, bytes[0, i])}
    end

    private def st_default_key(intro8 : Int32, bytes : Bytes) : {Int32, Event?}
      case intro8
      when Ansi::SOS
        {2, key_from_byte(bytes[1], ModShift | ModAlt)}
      when Ansi::PM, Ansi::APC
        {2, key_from_byte(bytes[1], ModAlt)}
      else
        {0, nil}
      end
    end

    private def st_intro_index(bytes : Bytes, intro8 : Int32, intro7 : Int32) : Int32
      i = 0
      if bytes[i] == intro8 || bytes[i] == Ansi::ESC
        i += 1
      end
      if i < bytes.size && bytes[i - 1] == Ansi::ESC && bytes[i] == intro7
        i += 1
      end
      i
    end

    private def scan_st_terminator(bytes : Bytes, i : Int32) : {Int32, Int32, UInt8}
      while i < bytes.size
        byte = bytes[i]
        if byte == Ansi::ESC || byte == Ansi::ST || byte == Ansi::CAN || byte == Ansi::SUB
          return {i, i + 1, byte}
        end
        i += 1
      end
      {i, i, 0_u8}
    end

    private def st_unknown_event(intro8 : Int32, bytes : Bytes) : Event
      case intro8
      when Ansi::PM
        UnknownPmEvent.new(String.new(bytes))
      when Ansi::SOS
        UnknownSosEvent.new(String.new(bytes))
      when Ansi::APC
        UnknownApcEvent.new(String.new(bytes))
      else
        UnknownEvent.new(String.new(bytes))
      end
    end

    private def parse_dcs(buf : Bytes) : {Int32, Event}
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, key_from_byte(buf[1], ModShift | ModAlt)}
      end

      cmd, params, i, ok = parse_dcs_header(buf)
      return {i, UnknownEvent.new(String.new(buf[0, i]))} unless ok

      start, ending, i, ok = scan_dcs_payload(buf, i)
      return {i, UnknownEvent.new(String.new(buf[0, i]))} unless ok

      pa = Ansi::Params.new(params)
      if event = dcs_event_for(cmd, pa, buf[start, ending - start])
        return {i, event}
      end

      {i, UnknownDcsEvent.new(String.new(buf[0, i]))}
    end

    private def parse_dcs_header(buf : Bytes) : {Int32, Array(Ansi::Param), Int32, Bool}
      cmd = 0
      i = 0
      if buf[i] == Ansi::DCS || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == 'P'.ord
        i += 1
      end

      if i < buf.size && buf[i] >= '<'.ord && buf[i] <= '?'.ord
        cmd |= (buf[i].to_i << Ansi::ParserTransition::PrefixShift)
      end

      params, i, _ = parse_params(buf, i, 16)
      intermed, i = parse_csi_intermed(buf, i)
      cmd |= (intermed.to_i << Ansi::ParserTransition::IntermedShift)
      cmd, i, ok = parse_csi_final(buf, cmd, i)
      {cmd, params, i, ok}
    end

    private def scan_dcs_payload(buf : Bytes, i : Int32) : {Int32, Int32, Int32, Bool}
      start = i
      while i < buf.size
        break if buf[i] == Ansi::ST || buf[i] == Ansi::ESC
        i += 1
      end
      return {start, i, i, false} if i >= buf.size

      ending = i
      i += 1

      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == '\\'.ord
        i += 1
      end

      {start, ending, i, true}
    end

    private def dcs_event_for(cmd : Int32, params : Ansi::Params, payload : Bytes) : Event?
      case cmd
      when ('r'.ord | ('+'.ord << Ansi::ParserTransition::IntermedShift))
        param, _, _ = params.param(0, 0)
        return parse_termcap(payload) if param == 1
      when ('|'.ord | ('>'.ord << Ansi::ParserTransition::PrefixShift))
        return TerminalVersionEvent.new(String.new(payload))
      when ('|'.ord | ('!'.ord << Ansi::ParserTransition::IntermedShift))
        return parse_tertiary_dev_attrs(payload)
      end
      nil
    end

    private def parse_apc(buf : Bytes) : {Int32, Event?}
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, key_from_byte(buf[1], ModAlt)}
      end

      parse_st_terminated(Ansi::APC, '_'.ord, ->(bytes : Bytes) {
        return nil if bytes.empty?
        if bytes[0] == 'G'.ord
          options = parse_kitty_options(bytes[1..])
          payload = Bytes.empty
          if idx = bytes.index(';'.ord)
            payload = bytes[(idx + 1)..]
          end
          return KittyGraphicsEvent.new(options, payload)
        end
        nil
      }).call(buf)
    end

    private def parse_utf8(buf : Bytes) : {Int32, Event?}
      return {0, nil} if buf.empty?

      c = buf[0]
      if c <= Ansi::US || c == Ansi::DEL
        return {1, parse_control(c)}
      elsif c > Ansi::US && c < Ansi::DEL
        code = c.to_i
        key = Key.new(code: code, text: code.chr.to_s)
        if key.text[0].uppercase?
          key.code = key.text[0].downcase.ord
          key.shifted_code = code
          key.mod |= ModShift
        end
        return {1, key}
      end

      begin
        string = String.new(buf, "UTF-8")
      rescue
        return {1, UnknownEvent.new(buf[0].chr.to_s)}
      end

      cluster = ""
      TextSegment.each_grapheme(string) do |segment|
        cluster = segment.str
        break
      end

      if cluster.empty?
        return {1, UnknownEvent.new(buf[0].chr.to_s)}
      end

      codepoint = cluster.each_char.first.ord
      if cluster.each_char.to_a.size > 1
        codepoint = KeyExtended
      end

      {cluster.bytesize, Key.new(code: codepoint, text: cluster)}
    end

    private def parse_control(b : UInt8) : Event
      if key = parse_control_legacy(b)
        return key
      end
      if key = parse_control_standard(b)
        return key
      end
      if key = parse_control_range(b)
        return key
      end
      UnknownEvent.new(b.chr.to_s)
    end

    private def parse_control_legacy(b : UInt8) : Key?
      case b
      when Ansi::NUL
        return Key.new(code: '@'.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_AT)
      when Ansi::HT
        return Key.new(code: 'i'.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_I)
      when Ansi::CR
        return Key.new(code: 'm'.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_M)
      when Ansi::ESC
        return Key.new(code: '['.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_OPEN_BRACKET)
      when Ansi::DEL
        return Key.new(code: KeyDelete) if @legacy.contains?(FLAG_BACKSPACE)
      end
      nil
    end

    private def parse_control_standard(b : UInt8) : Key?
      case b
      when Ansi::NUL
        Key.new(code: KeySpace, mod: ModCtrl)
      when Ansi::HT
        Key.new(code: KeyTab)
      when Ansi::CR
        Key.new(code: KeyEnter)
      when Ansi::ESC
        Key.new(code: KeyEscape)
      when Ansi::DEL
        Key.new(code: KeyBackspace)
      when Ansi::BS
        Key.new(code: 'h'.ord, mod: ModCtrl)
      when Ansi::SP
        Key.new(code: KeySpace, text: " ")
      else
        nil
      end
    end

    private def parse_control_range(b : UInt8) : Key?
      if b >= Ansi::SOH && b <= Ansi::SUB
        return Key.new(code: b + 0x60, mod: ModCtrl)
      end
      if b >= Ansi::FS && b <= Ansi::US
        return Key.new(code: b + 0x40, mod: ModCtrl)
      end
      nil
    end

    private def key_from_byte(byte : UInt8, mod : KeyMod) : Key
      code = byte.to_i
      key = Key.new(code: code, mod: mod)
      char = code.chr
      if Ultraviolet.mod_contains?(mod, ModShift) && char.uppercase?
        key.code = char.downcase.ord
      end
      key
    end

    private def parse_xterm_modify_other_keys(params : Ansi::Params) : Event
      xmod, _, _ = params.param(1, 1)
      xrune, _, _ = params.param(2, 1)
      mod = xmod - 1
      r = xrune

      case r
      when Ansi::BS
        return Key.new(code: KeyBackspace, mod: mod)
      when Ansi::HT
        return Key.new(code: KeyTab, mod: mod)
      when Ansi::CR
        return Key.new(code: KeyEnter, mod: mod)
      when Ansi::ESC
        return Key.new(code: KeyEscape, mod: mod)
      when Ansi::DEL
        return Key.new(code: KeyBackspace, mod: mod)
      end

      key = Key.new(code: r, mod: mod)
      key.text = r.chr.to_s if key.mod <= ModShift
      key
    end

    private def parse_kitty_keyboard(params : Ansi::Params) : Event
      is_release = false
      key = Key.new

      param_idx = 0
      sub_idx = 0
      params.each do |param|
        key, is_release = apply_kitty_param(param_idx, sub_idx, param, key, is_release)

        sub_idx += 1
        unless param_has_more?(param)
          param_idx += 1
          sub_idx = 0
        end
      end

      return KeyReleaseEvent.new(key.text, key.mod, key.code, key.shifted_code, key.base_code, key.is_repeat?) if is_release
      key
    end

    private def apply_kitty_param(param_idx : Int32, sub_idx : Int32, param : Ansi::Param, key : Key, is_release : Bool) : {Key, Bool}
      case param_idx
      when 0
        {apply_kitty_key_param(sub_idx, param, key), is_release}
      when 1
        apply_kitty_mod_param(sub_idx, param, key, is_release)
      when 2
        {apply_kitty_text_param(param, key), is_release}
      else
        {key, is_release}
      end
    end

    private def apply_kitty_key_param(sub_idx : Int32, param : Ansi::Param, key : Key) : Key
      case sub_idx
      when 0
        code = param_value(param, 1)
        mapped = kitty_key_map[code]?
        return mapped || Key.new(code: code)
      when 1
        shifted = param_value(param, 1)
        if Ultraviolet.printable_char?(shifted)
          key.shifted_code = shifted
        end
      when 2
        shifted = param_value(param, 1)
        if Ultraviolet.printable_char?(shifted)
          key.base_code = shifted
          key.shifted_code = shifted
        end
      end
      key
    end

    private def apply_kitty_mod_param(sub_idx : Int32, param : Ansi::Param, key : Key, is_release : Bool) : {Key, Bool}
      case sub_idx
      when 0
        mod = param_value(param, 1)
        if mod > 1
          key.mod = from_kitty_mod(mod - 1)
          key.text = "" if key.mod > ModShift
        end
      when 1
        case param_value(param, 1)
        when 2
          key.is_repeat = true
        when 3
          is_release = true
        end
      end
      {key, is_release}
    end

    private def apply_kitty_text_param(param : Ansi::Param, key : Key) : Key
      code = param_value(param, 0)
      key.text += Ultraviolet.safe_char(code).to_s if code != 0
      key
    end

    private def parse_kitty_keyboard_ext(params : Ansi::Params, key : Key) : Event
      return key if params.empty?
      return key if params.size < 3
      return key unless param_value(params[0], 1) == 1 && param_value(params[2], 1) == 1

      mod = param_value(params[1], 1)
      return key if mod < 2

      key.mod |= from_kitty_mod(mod - 1)
      key.text = "" if key.mod > ModShift
      key
    end

    protected def parse_primary_dev_attrs(params : Ansi::Params) : Event
      attrs = [] of Int32
      params.each do |param|
        attrs << param_value(param, 0) unless param_has_more?(param)
      end
      attrs
    end

    protected def parse_secondary_dev_attrs(params : Ansi::Params) : Event
      attrs = [] of Int32
      params.each do |param|
        attrs << param_value(param, 0) unless param_has_more?(param)
      end
      attrs
    end

    private def parse_tertiary_dev_attrs(bytes : Bytes) : Event
      begin
        decoded = hex_decode(String.new(bytes))
      rescue
        return UnknownDcsEvent.new("\eP!|#{String.new(bytes)}\e\\")
      end
      String.new(decoded)
    end

    private def parse_sgr_mouse_event(cmd : Int32, params : Ansi::Params) : Event
      x, _, ok = params.param(1, 1)
      x = 1 unless ok
      y, _, ok = params.param(2, 1)
      y = 1 unless ok
      release = (cmd & 0xff) == 'm'.ord
      b, _, _ = params.param(0, 0)
      mod, btn, _, is_motion = parse_mouse_button(b)

      x -= 1
      y -= 1

      mouse = Mouse.new(x, y, btn, mod)
      return MouseWheelEvent.new(mouse) if wheel?(btn)
      return MouseReleaseEvent.new(mouse) if !is_motion && release
      return MouseMotionEvent.new(mouse) if is_motion
      MouseClickEvent.new(mouse)
    end

    private def parse_x10_mouse_event(buf : Bytes) : Event
      v = buf[3, 3]
      b = v[0].to_i
      b = b - 32 if b >= 32

      mod, btn, is_release, is_motion = parse_mouse_button(b)
      x = v[1].to_i - 32 - 1
      y = v[2].to_i - 32 - 1

      mouse = Mouse.new(x, y, btn, mod)
      return MouseWheelEvent.new(mouse) if wheel?(btn)
      return MouseMotionEvent.new(mouse) if is_motion
      return MouseReleaseEvent.new(mouse) if is_release
      MouseClickEvent.new(mouse)
    end

    private def parse_mouse_button(value : Int32) : {KeyMod, MouseButton, Bool, Bool}
      bit_shift = 0b0000_0100
      bit_alt = 0b0000_1000
      bit_ctrl = 0b0001_0000
      bit_motion = 0b0010_0000
      bit_wheel = 0b0100_0000
      bit_add = 0b1000_0000
      bits_mask = 0b0000_0011

      mod = 0
      mod |= ModAlt if (value & bit_alt) != 0
      mod |= ModCtrl if (value & bit_ctrl) != 0
      mod |= ModShift if (value & bit_shift) != 0

      btn = MouseButton::Left
      is_release = false

      if (value & bit_add) != 0
        btn = MouseButton::Backward + (value & bits_mask)
      elsif (value & bit_wheel) != 0
        btn = MouseButton::WheelUp + (value & bits_mask)
      else
        btn = MouseButton::Left + (value & bits_mask)
        if (value & bits_mask) == bits_mask
          btn = MouseButton::None
          is_release = true
        end
      end

      is_motion = (value & bit_motion) != 0 && !wheel?(btn)

      {mod, btn, is_release, is_motion}
    end

    private def wheel?(btn : MouseButton) : Bool
      btn >= MouseButton::WheelUp && btn <= MouseButton::WheelRight
    end

    private def parse_termcap(data : Bytes) : CapabilityEvent
      return CapabilityEvent.new("") if data.empty?

      output = [] of String
      String.new(data).split(';').each do |part|
        segments = part.split('=', 2)
        next if segments.empty?

        begin
          name = hex_decode(segments[0])
        rescue
          next
        end

        value = Bytes.empty
        if segments.size > 1
          begin
            value = hex_decode(segments[1])
          rescue
            next
          end
        end

        entry = String.new(name)
        entry += "=#{String.new(value)}" unless value.empty?
        output << entry
      end

      CapabilityEvent.new(output.join(";"))
    end

    private def parse_kitty_options(bytes : Bytes) : Hash(String, String)
      data = Bytes.empty
      if idx = bytes.index(';'.ord)
        data = bytes[0, idx]
      else
        data = bytes
      end

      options = {} of String => String
      String.new(data).split(',').each do |pair|
        key, value = pair.split('=', 2)
        next if key.empty?
        options[key] = value || ""
      end
      options
    end

    private def from_kitty_mod(mod : Int32) : KeyMod
      kitty_shift = 1 << 0
      kitty_alt = 1 << 1
      kitty_ctrl = 1 << 2
      kitty_super = 1 << 3
      kitty_hyper = 1 << 4
      kitty_meta = 1 << 5
      kitty_caps_lock = 1 << 6
      kitty_num_lock = 1 << 7

      value = 0
      value |= ModShift if (mod & kitty_shift) != 0
      value |= ModAlt if (mod & kitty_alt) != 0
      value |= ModCtrl if (mod & kitty_ctrl) != 0
      value |= ModSuper if (mod & kitty_super) != 0
      value |= ModHyper if (mod & kitty_hyper) != 0
      value |= ModMeta if (mod & kitty_meta) != 0
      value |= ModCapsLock if (mod & kitty_caps_lock) != 0
      value |= ModNumLock if (mod & kitty_num_lock) != 0
      value
    end

    private def kitty_key_map : Hash(Int32, Key)
      @@kitty_key_map ||= begin
        map = {
          Ansi::BS.to_i  => Key.new(code: KeyBackspace),
          Ansi::HT.to_i  => Key.new(code: KeyTab),
          Ansi::CR.to_i  => Key.new(code: KeyEnter),
          Ansi::ESC.to_i => Key.new(code: KeyEscape),
          Ansi::DEL.to_i => Key.new(code: KeyBackspace),

          57344 => Key.new(code: KeyEscape),
          57345 => Key.new(code: KeyEnter),
          57346 => Key.new(code: KeyTab),
          57347 => Key.new(code: KeyBackspace),
          57348 => Key.new(code: KeyInsert),
          57349 => Key.new(code: KeyDelete),
          57350 => Key.new(code: KeyLeft),
          57351 => Key.new(code: KeyRight),
          57352 => Key.new(code: KeyUp),
          57353 => Key.new(code: KeyDown),
          57354 => Key.new(code: KeyPgUp),
          57355 => Key.new(code: KeyPgDown),
          57356 => Key.new(code: KeyHome),
          57357 => Key.new(code: KeyEnd),
          57358 => Key.new(code: KeyCapsLock),
          57359 => Key.new(code: KeyScrollLock),
          57360 => Key.new(code: KeyNumLock),
          57361 => Key.new(code: KeyPrintScreen),
          57362 => Key.new(code: KeyPause),
          57363 => Key.new(code: KeyMenu),
          57364 => Key.new(code: KeyF1),
          57365 => Key.new(code: KeyF2),
          57366 => Key.new(code: KeyF3),
          57367 => Key.new(code: KeyF4),
          57368 => Key.new(code: KeyF5),
          57369 => Key.new(code: KeyF6),
          57370 => Key.new(code: KeyF7),
          57371 => Key.new(code: KeyF8),
          57372 => Key.new(code: KeyF9),
          57373 => Key.new(code: KeyF10),
          57374 => Key.new(code: KeyF11),
          57375 => Key.new(code: KeyF12),
          57376 => Key.new(code: KeyF13),
          57377 => Key.new(code: KeyF14),
          57378 => Key.new(code: KeyF15),
          57379 => Key.new(code: KeyF16),
          57380 => Key.new(code: KeyF17),
          57381 => Key.new(code: KeyF18),
          57382 => Key.new(code: KeyF19),
          57383 => Key.new(code: KeyF20),
          57384 => Key.new(code: KeyF21),
          57385 => Key.new(code: KeyF22),
          57386 => Key.new(code: KeyF23),
          57387 => Key.new(code: KeyF24),
          57388 => Key.new(code: KeyF25),
          57389 => Key.new(code: KeyF26),
          57390 => Key.new(code: KeyF27),
          57391 => Key.new(code: KeyF28),
          57392 => Key.new(code: KeyF29),
          57393 => Key.new(code: KeyF30),
          57394 => Key.new(code: KeyF31),
          57395 => Key.new(code: KeyF32),
          57396 => Key.new(code: KeyF33),
          57397 => Key.new(code: KeyF34),
          57398 => Key.new(code: KeyF35),
          57399 => Key.new(code: KeyF36),
          57400 => Key.new(code: KeyF37),
          57401 => Key.new(code: KeyF38),
          57402 => Key.new(code: KeyF39),
          57403 => Key.new(code: KeyF40),
          57404 => Key.new(code: KeyF41),
          57405 => Key.new(code: KeyF42),
          57406 => Key.new(code: KeyF43),
          57407 => Key.new(code: KeyF44),
          57408 => Key.new(code: KeyF45),
          57409 => Key.new(code: KeyF46),
          57410 => Key.new(code: KeyF47),
          57411 => Key.new(code: KeyF48),
          57412 => Key.new(code: KeyF49),
          57413 => Key.new(code: KeyF50),
          57414 => Key.new(code: KeyF51),
          57415 => Key.new(code: KeyF52),
          57416 => Key.new(code: KeyF53),
          57417 => Key.new(code: KeyF54),
          57418 => Key.new(code: KeyF55),
          57419 => Key.new(code: KeyF56),
          57420 => Key.new(code: KeyF57),
          57421 => Key.new(code: KeyF58),
          57422 => Key.new(code: KeyF59),
          57423 => Key.new(code: KeyF60),
          57424 => Key.new(code: KeyF61),
          57425 => Key.new(code: KeyF62),
          57426 => Key.new(code: KeyF63),
          57427 => Key.new(code: KeyCapsLock),
          57428 => Key.new(code: KeyScrollLock),
          57429 => Key.new(code: KeyNumLock),
          57430 => Key.new(code: KeyPrintScreen),
          57431 => Key.new(code: KeyPause),
          57432 => Key.new(code: KeyMenu),
          57433 => Key.new(code: KeyMediaPlay),
          57434 => Key.new(code: KeyMediaPause),
          57435 => Key.new(code: KeyMediaPlayPause),
          57436 => Key.new(code: KeyMediaReverse),
          57437 => Key.new(code: KeyMediaStop),
          57438 => Key.new(code: KeyMediaFastForward),
          57439 => Key.new(code: KeyMediaRewind),
          57440 => Key.new(code: KeyMediaNext),
          57441 => Key.new(code: KeyMediaPrev),
          57442 => Key.new(code: KeyMediaRecord),
          57443 => Key.new(code: KeyLowerVol),
          57444 => Key.new(code: KeyRaiseVol),
          57445 => Key.new(code: KeyMute),
          57446 => Key.new(code: KeyLeftShift),
          57447 => Key.new(code: KeyLeftCtrl),
          57448 => Key.new(code: KeyLeftAlt),
          57449 => Key.new(code: KeyLeftMeta),
          57450 => Key.new(code: KeyLeftSuper),
          57451 => Key.new(code: KeyLeftHyper),
          57452 => Key.new(code: KeyRightShift),
          57453 => Key.new(code: KeyRightCtrl),
          57454 => Key.new(code: KeyRightAlt),
          57455 => Key.new(code: KeyRightMeta),
          57456 => Key.new(code: KeyRightSuper),
          57457 => Key.new(code: KeyRightHyper),
        }

        # Add faulty C0 mappings per Go init()
        # NUL maps to Ctrl+Space
        map[Ansi::NUL.to_i] = Key.new(code: KeySpace, mod: ModCtrl)

        # SOH to SUB (0x01-0x1A) map to Ctrl+letter
        (Ansi::SOH..Ansi::SUB).each do |i|
          map[i.to_i] = Key.new(code: i.to_i + 0x60, mod: ModCtrl)
        end

        # FS to US (0x1C-0x1F) map to Ctrl+symbol
        (Ansi::FS..Ansi::US).each do |i|
          map[i.to_i] = Key.new(code: i.to_i + 0x40, mod: ModCtrl)
        end

        map
      end
    end

    private def parse_win32_input_key_event(vkc : UInt16, _scan : UInt16, rune_value : Int32, key_down : Bool, cks : UInt32, repeat_count : UInt16) : Event
      base_code = rune_value
      code = rune_value
      text = ""

      # Match Go's win32 key decoding for common virtual key codes.
      case vkc
      when 0x08_u16 # VK_BACK
        base_code = KeyBackspace
        code = KeyBackspace
      when 0x09_u16 # VK_TAB
        base_code = KeyTab
        code = KeyTab
      when 0x0D_u16 # VK_RETURN
        base_code = KeyEnter
        code = KeyEnter
      when 0x1B_u16 # VK_ESCAPE
        base_code = KeyEscape
        code = KeyEscape
      when 0x20_u16 # VK_SPACE
        base_code = KeySpace
        code = KeySpace
      when 0x70_u16..0x87_u16 # VK_F1..VK_F24
        base_code = KeyF1 + (vkc.to_i - 0x70)
        code = base_code
      end

      if Ultraviolet.printable_char?(code)
        text = Ultraviolet.safe_char(code).to_s
      end

      key = Key.new(code: code, base_code: base_code, text: text, mod: translate_control_key_state(cks))
      key
    end

    private def translate_control_key_state(cks : UInt32) : KeyMod
      left_ctrl = 1_u32 << 0
      right_ctrl = 1_u32 << 1
      left_alt = 1_u32 << 2
      right_alt = 1_u32 << 3
      shift = 1_u32 << 4
      caps = 1_u32 << 5
      num = 1_u32 << 6
      scroll = 1_u32 << 7

      mod = 0
      mod |= ModCtrl if (cks & (left_ctrl | right_ctrl)) != 0
      mod |= ModAlt if (cks & (left_alt | right_alt)) != 0
      mod |= ModShift if (cks & shift) != 0
      mod |= ModCapsLock if (cks & caps) != 0
      mod |= ModNumLock if (cks & num) != 0
      mod |= ModScrollLock if (cks & scroll) != 0
      mod
    end

    private def ensure_key_case(key : Key, cks : UInt32) : Key
      return key if key.text.empty?

      has_shift = (cks & (1_u32 << 4)) != 0 # SHIFT_PRESSED
      has_caps = (cks & (1_u32 << 5)) != 0  # CAPSLOCK_ON

      if has_shift || has_caps
        if key.code.chr?.try(&.lowercase?)
          key.shifted_code = key.code.chr.upcase.ord
          key.text = key.shifted_code.chr.to_s
        end
      else
        if key.code.chr?.try(&.uppercase?)
          key.shifted_code = key.code.chr.downcase.ord
          key.text = key.shifted_code.chr.to_s
        end
      end

      key
    end

    private def hex_decode(value : String) : Bytes
      raise ArgumentError.new("hex string must be even") if value.bytesize.odd?
      bytes = Bytes.new(value.bytesize // 2)
      idx = 0
      offset = 0
      while idx < value.bytesize
        hi = value.byte_at(idx)
        lo = value.byte_at(idx + 1)
        bytes[offset] = ((hex_value(hi) << 4) | hex_value(lo)).to_u8
        idx += 2
        offset += 1
      end
      bytes
    end

    private def hex_value(byte : UInt8) : Int32
      case byte
      when '0'.ord..'9'.ord
        byte.to_i - '0'.ord
      when 'a'.ord..'f'.ord
        10 + (byte.to_i - 'a'.ord)
      when 'A'.ord..'F'.ord
        10 + (byte.to_i - 'A'.ord)
      else
        raise ArgumentError.new("invalid hex")
      end
    end
  end
end
