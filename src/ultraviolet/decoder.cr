require "base64"
require "textseg"

module Ultraviolet
  class EventDecoder
    property legacy : LegacyKeyEncoding
    property? use_terminfo : Bool

    @last_cks : UInt32 = 0

    def initialize(@legacy : LegacyKeyEncoding = LegacyKeyEncoding.new, @use_terminfo : Bool = false)
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

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_csi(buf : Bytes) : {Int32, Event}
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, Key.new(code: buf[1].to_i, mod: ModAlt)}
      end

      cmd = 0
      params = [] of Ansi::Param
      i = 0

      if buf[i] == Ansi::CSI || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == '['.ord
        i += 1
      end

      if i < buf.size && buf[i] >= '<'.ord && buf[i] <= '?'.ord
        cmd |= (buf[i].to_i << Ansi::Parser::PrefixShift)
      end

      param_bytes = 0
      current = Ansi::Param.new
      while i < buf.size && params.size < Ansi::Parser::MaxParamsSize && buf[i] >= 0x30 && buf[i] <= 0x3f
        param_bytes += 1
        byte = buf[i]
        if byte >= '0'.ord && byte <= '9'.ord
          unless current.present?
            current.present = true
            current.value = 0
          end
          current.value = current.value * 10 + (byte - '0'.ord)
        end
        if byte == ':'.ord
          current.has_more = true
        end
        if byte == ';'.ord || byte == ':'.ord
          params << current
          current = Ansi::Param.new
        end
        i += 1
      end

      if param_bytes > 0 && params.size < Ansi::Parser::MaxParamsSize
        params << current
      end

      intermed = 0_u8
      while i < buf.size && buf[i] >= 0x20 && buf[i] <= 0x2f
        intermed = buf[i]
        i += 1
      end
      cmd |= (intermed.to_i << Ansi::Parser::IntermedShift)

      if i >= buf.size || buf[i] < 0x40 || buf[i] > 0x7e
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

      cmd |= buf[i].to_i
      i += 1

      pa = Ansi::Params.new(params)
      case cmd
      when ('y'.ord | ('?'.ord << Ansi::Parser::PrefixShift) | ('$'.ord << Ansi::Parser::IntermedShift))
        mode, _, ok = pa.param(0, -1)
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless ok && mode != -1
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} if params.size < 2
        value, _, _ = pa.param(1, Ansi::ModeNotRecognized)
        return {i, ModeReportEvent.new(mode, value)}
      when ('c'.ord | ('?'.ord << Ansi::Parser::PrefixShift))
        return {i, parse_primary_dev_attrs(pa)}
      when ('c'.ord | ('>'.ord << Ansi::Parser::PrefixShift))
        return {i, parse_secondary_dev_attrs(pa)}
      when ('u'.ord | ('?'.ord << Ansi::Parser::PrefixShift))
        flags, _, _ = pa.param(0, 0)
        return {i, KeyboardEnhancementsEvent.new(flags)}
      when ('R'.ord | ('?'.ord << Ansi::Parser::PrefixShift))
        row, _, _ = pa.param(0, 1)
        col, _, ok = pa.param(1, 1)
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless ok
        return {i, CursorPositionEvent.new(row - 1, col - 1)}
      when ('m'.ord | ('<'.ord << Ansi::Parser::PrefixShift)), ('M'.ord | ('<'.ord << Ansi::Parser::PrefixShift))
        if params.size == 3
          return {i, parse_sgr_mouse_event(cmd, pa)}
        end
      when ('m'.ord | ('>'.ord << Ansi::Parser::PrefixShift))
        mok, _, ok = pa.param(0, 0)
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless ok && mok == 4
        val, _, ok = pa.param(1, -1)
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless ok && val != -1
        return {i, ModifyOtherKeysEvent.new(val)}
      when ('n'.ord | ('?'.ord << Ansi::Parser::PrefixShift))
        report, _, _ = pa.param(0, -1)
        dark_light, _, _ = pa.param(1, -1)
        if report == 997
          return {i, DarkColorSchemeEvent.new} if dark_light == 1
          return {i, LightColorSchemeEvent.new} if dark_light == 2
        end
      when 'I'.ord
        return {i, FocusEvent.new}
      when 'O'.ord
        return {i, BlurEvent.new}
      when 'R'.ord
        if params.empty?
          return {i, Key.new(code: KeyF3)}
        end
        row, _, row_ok = pa.param(0, 1)
        col, _, col_ok = pa.param(1, 1)
        if params.size == 2 && row_ok && col_ok
          m = CursorPositionEvent.new(row - 1, col - 1)
          if row == 1 && (col - 1) <= (ModMeta | ModShift | ModAlt | ModCtrl)
            events = [] of EventSingle
            events << Key.new(code: KeyF3, mod: col - 1)
            events << m
            return {i, events}
          end
          return {i, m}
        end

        if params.size != 0
          return {i, UnknownCsiEvent.new(String.new(buf[0, i]))}
        end
      when 'a'.ord, 'b'.ord, 'c'.ord, 'd'.ord, 'A'.ord, 'B'.ord, 'C'.ord, 'D'.ord, 'E'.ord, 'F'.ord, 'H'.ord, 'P'.ord, 'Q'.ord, 'S'.ord, 'Z'.ord
        key = Key.new
        case cmd & 0xff
        when 'a'.ord, 'b'.ord, 'c'.ord, 'd'.ord
          key = Key.new(code: KeyUp + (cmd & 0xff) - 'a'.ord, mod: ModShift)
        when 'A'.ord, 'B'.ord, 'C'.ord, 'D'.ord
          key = Key.new(code: KeyUp + (cmd & 0xff) - 'A'.ord)
        when 'E'.ord
          key = Key.new(code: KeyBegin)
        when 'F'.ord
          key = Key.new(code: KeyEnd)
        when 'H'.ord
          key = Key.new(code: KeyHome)
        when 'P'.ord, 'Q'.ord, 'R'.ord, 'S'.ord
          key = Key.new(code: KeyF1 + (cmd & 0xff) - 'P'.ord)
        when 'Z'.ord
          key = Key.new(code: KeyTab, mod: ModShift)
        end

        id, _, _ = pa.param(0, 1)
        mod, _, _ = pa.param(1, 1)
        if params.size > 2 && !pa[1].has_more? || id != 1
          return {i, UnknownCsiEvent.new(String.new(buf[0, i]))}
        end
        if params.size > 1 && id == 1 && mod != -1
          key.mod |= (mod - 1)
        end

        return {i, parse_kitty_keyboard_ext(pa, key)}
      when 'M'.ord
        if i + 3 > buf.size
          return {i, UnknownCsiEvent.new(String.new(buf[0, i]))}
        end
        data = Bytes.new(i + 3)
        data.copy_from(buf[0, i])
        data[i, 3].copy_from(buf[i, 3])
        return {i + 3, parse_x10_mouse_event(data)}
      when ('y'.ord | ('$'.ord << Ansi::Parser::IntermedShift))
        mode, _, ok = pa.param(0, -1)
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless ok && mode != -1
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} if params.size < 2
        val, _, _ = pa.param(1, Ansi::ModeNotRecognized)
        return {i, ModeReportEvent.new(mode, val)}
      when 'u'.ord
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} if params.empty?
        return {i, parse_kitty_keyboard(pa)}
      when '_'.ord
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} if params.size != 6

        vk, _, _ = pa.param(0, 0)
        sc, _, _ = pa.param(1, 0)
        uc, _, _ = pa.param(2, 0)
        kd, _, _ = pa.param(3, 0)
        cs, _, _ = pa.param(4, 0)
        rc, _, _ = pa.param(5, 0)
        event = parse_win32_input_key_event(vk.to_u16, sc.to_u16, uc, kd == 1, cs.to_u32, {1, rc}.max.to_u16)
        return {i, event}
      when '@'.ord, '^'.ord, '~'.ord
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} if params.empty?

        param, _, _ = pa.param(0, 0)
        if (cmd & 0xff) == '~'.ord
          case param
          when 27
            return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} if params.size != 3
            return {i, parse_xterm_modify_other_keys(pa)}
          when 200
            return {i, PasteStartEvent.new}
          when 201
            return {i, PasteEndEvent.new}
          end
        end

        if [1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 26, 28, 29, 31, 32, 33, 34].includes?(param)
          key = Key.new
          case param
          when 1
            key = @legacy.contains?(FLAG_FIND) ? Key.new(code: KeyFind) : Key.new(code: KeyHome)
          when 2
            key = Key.new(code: KeyInsert)
          when 3
            key = Key.new(code: KeyDelete)
          when 4
            key = @legacy.contains?(FLAG_SELECT) ? Key.new(code: KeySelect) : Key.new(code: KeyEnd)
          when 5
            key = Key.new(code: KeyPgUp)
          when 6
            key = Key.new(code: KeyPgDown)
          when 7
            key = Key.new(code: KeyHome)
          when 8
            key = Key.new(code: KeyEnd)
          when 11, 12, 13, 14, 15
            key = Key.new(code: KeyF1 + param - 11)
          when 17, 18, 19, 20, 21
            key = Key.new(code: KeyF6 + param - 17)
          when 23, 24, 25, 26
            key = Key.new(code: KeyF11 + param - 23)
          when 28, 29
            key = Key.new(code: KeyF15 + param - 28)
          when 31, 32, 33, 34
            key = Key.new(code: KeyF17 + param - 31)
          end

          mod, _, _ = pa.param(1, -1)
          if params.size > 1 && mod != -1
            key.mod |= (mod - 1)
          end

          case cmd & 0xff
          when '~'.ord
            return {i, parse_kitty_keyboard_ext(pa, key)}
          when '^'.ord
            key.mod |= ModCtrl
          when '@'.ord
            key.mod |= ModCtrl | ModShift
          end

          return {i, key}
        end
      when 't'.ord
        param, _, ok = pa.param(0, 0)
        return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless ok

        case param
        when 4
          if params.size == 3
            height, _, h_ok = pa.param(1, 0)
            width, _, w_ok = pa.param(2, 0)
            return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless h_ok && w_ok
            return {i, PixelSizeEvent.new(width, height)}
          end
        when 6
          if params.size == 3
            height, _, h_ok = pa.param(1, 0)
            width, _, w_ok = pa.param(2, 0)
            return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless h_ok && w_ok
            return {i, CellSizeEvent.new(width, height)}
          end
        when 8
          if params.size == 3
            height, _, h_ok = pa.param(1, 0)
            width, _, w_ok = pa.param(2, 0)
            return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless h_ok && w_ok
            return {i, WindowSizeEvent.new(width, height)}
          end
        when 48
          if params.size == 5
            cell_height, _, ch_ok = pa.param(1, 0)
            cell_width, _, cw_ok = pa.param(2, 0)
            pixel_height, _, ph_ok = pa.param(3, 0)
            pixel_width, _, pw_ok = pa.param(4, 0)
            return {i, UnknownCsiEvent.new(String.new(buf[0, i]))} unless ch_ok && cw_ok && ph_ok && pw_ok
            events = [] of EventSingle
            events << WindowSizeEvent.new(cell_width, cell_height)
            events << PixelSizeEvent.new(pixel_width, pixel_height)
            return {i, events}
          end
        end

        winop = WindowOpEvent.new(param)
        j = 1
        while j < params.size
          val, _, ok = pa.param(j, 0)
          winop.args << val if ok
          j += 1
        end
        return {i, winop}
      end

      {i, UnknownCsiEvent.new(String.new(buf[0, i]))}
    end

    # ameba:enable Metrics/CyclomaticComplexity

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_ss3(buf : Bytes) : {Int32, Event}
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, key_from_byte(buf[1], ModShift | ModAlt)}
      end

      i = 0
      if buf[i] == Ansi::SS3 || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == 'O'.ord
        i += 1
      end

      mod = 0
      while i < buf.size && buf[i] >= '0'.ord && buf[i] <= '9'.ord
        mod *= 10
        mod += buf[i] - '0'.ord
        i += 1
      end

      if i >= buf.size || buf[i] < 0x21 || buf[i] > 0x7e
        return {i, UnknownEvent.new(String.new(buf[0, i]))}
      end

      gl = buf[i]
      i += 1

      key = Key.new
      case gl
      when 'a'.ord, 'b'.ord, 'c'.ord, 'd'.ord
        key = Key.new(code: KeyUp + gl - 'a'.ord, mod: ModCtrl)
      when 'A'.ord, 'B'.ord, 'C'.ord, 'D'.ord
        key = Key.new(code: KeyUp + gl - 'A'.ord)
      when 'E'.ord
        key = Key.new(code: KeyBegin)
      when 'F'.ord
        key = Key.new(code: KeyEnd)
      when 'H'.ord
        key = Key.new(code: KeyHome)
      when 'P'.ord, 'Q'.ord, 'R'.ord, 'S'.ord
        key = Key.new(code: KeyF1 + gl - 'P'.ord)
      when 'M'.ord
        key = Key.new(code: KeyKpEnter)
      when 'X'.ord
        key = Key.new(code: KeyKpEqual)
      when 'j'.ord, 'k'.ord, 'l'.ord, 'm'.ord, 'n'.ord, 'o'.ord, 'p'.ord, 'q'.ord, 'r'.ord, 's'.ord, 't'.ord, 'u'.ord, 'v'.ord, 'w'.ord, 'x'.ord, 'y'.ord
        key = Key.new(code: KeyKpMultiply + gl - 'j'.ord)
      else
        return {i, UnknownSs3Event.new(String.new(buf[0, i]))}
      end

      key.mod |= (mod - 1) if mod > 0

      {i, key}
    end

    # ameba:enable Metrics/CyclomaticComplexity

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_osc(buf : Bytes) : {Int32, Event}
      default_key = Key.new(code: buf[1].to_i, mod: ModAlt)
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, default_key}
      end

      i = 0
      if buf[i] == Ansi::OSC || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == ']'.ord
        i += 1
      end

      cmd = -1
      start = 0
      while i < buf.size && buf[i] >= '0'.ord && buf[i] <= '9'.ord
        cmd = 0 if cmd == -1
        cmd = cmd * 10 + (buf[i] - '0'.ord)
        i += 1
      end

      if i < buf.size && buf[i] == ';'.ord
        i += 1
        start = i
      end

      while i < buf.size
        if [Ansi::BEL, Ansi::ESC, Ansi::ST, Ansi::CAN, Ansi::SUB].includes?(buf[i])
          break
        end
        i += 1
      end

      return {i, UnknownEvent.new(String.new(buf[0, i]))} if i >= buf.size

      ending = i
      i += 1

      case buf[i - 1]
      when Ansi::CAN, Ansi::SUB
        return {i, String.new(buf[0, i])}
      when Ansi::ESC
        if i >= buf.size || buf[i] != '\\'.ord
          if cmd == -1 || (start == 0 && ending == 2)
            return {2, default_key}
          end
          return {i, String.new(buf[0, i])}
        end
        i += 1
      end

      return {i, UnknownEvent.new(String.new(buf[0, i]))} if ending <= start

      data = String.new(buf[start, ending - start])
      case cmd
      when 10
        return {i, ForegroundColorEvent.new(Ansi.x_parse_color(data))}
      when 11
        return {i, BackgroundColorEvent.new(Ansi.x_parse_color(data))}
      when 12
        return {i, CursorColorEvent.new(Ansi.x_parse_color(data))}
      when 52
        parts = data.split(';')
        if parts.size != 2 || parts[0].empty?
          return {i, ClipboardEvent.new}
        end

        selection = parts[0][0]
        b64 = parts[1]
        begin
          decoded = Base64.decode_string(b64)
        rescue
          return {i, ClipboardEvent.new(parts[1], selection)}
        end

        return {i, ClipboardEvent.new(decoded, selection)}
      end

      {i, UnknownOscEvent.new(String.new(buf[0, i]))}
    end

    # ameba:enable Metrics/CyclomaticComplexity

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_st_terminated(intro8 : Int32, intro7 : Int32, fn : (Bytes -> Event?)?) : Proc(Bytes, {Int32, Event?})
      default_key = ->(bytes : Bytes) do
        case intro8
        when Ansi::SOS
          {2, key_from_byte(bytes[1], ModShift | ModAlt)}
        when Ansi::PM, Ansi::APC
          {2, key_from_byte(bytes[1], ModAlt)}
        else
          {0, nil}
        end
      end

      # ameba:disable Metrics/CyclomaticComplexity
      ->(bytes : Bytes) : {Int32, Event?} do
        if bytes.size == 2 && bytes[0] == Ansi::ESC
          return default_key.call(bytes)
        end

        i = 0
        if bytes[i] == intro8 || bytes[i] == Ansi::ESC
          i += 1
        end
        if i < bytes.size && bytes[i - 1] == Ansi::ESC && bytes[i] == intro7
          i += 1
        end

        start = i
        while i < bytes.size
          if [Ansi::ESC, Ansi::ST, Ansi::CAN, Ansi::SUB].includes?(bytes[i])
            break
          end
          i += 1
        end

        return {i, UnknownEvent.new(String.new(bytes[0, i]))} if i >= bytes.size

        ending = i
        i += 1

        case bytes[i - 1]
        when Ansi::CAN, Ansi::SUB
          return {i, String.new(bytes[0, i])}
        when Ansi::ESC
          if i >= bytes.size || bytes[i] != '\\'.ord
            return default_key.call(bytes) if start == ending
            return {i, String.new(bytes[0, i])}
          end
          i += 1
        end

        if fn
          event = fn.call(bytes[start, ending - start])
          return {i, event} if event
        end

        case intro8
        when Ansi::PM
          return {i, UnknownPmEvent.new(String.new(bytes[0, i]))}
        when Ansi::SOS
          return {i, UnknownSosEvent.new(String.new(bytes[0, i]))}
        when Ansi::APC
          return {i, UnknownApcEvent.new(String.new(bytes[0, i]))}
        end

        {i, UnknownEvent.new(String.new(bytes[0, i]))}
      end
      # ameba:enable Metrics/CyclomaticComplexity
    end

    # ameba:enable Metrics/CyclomaticComplexity

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_dcs(buf : Bytes) : {Int32, Event}
      if buf.size == 2 && buf[0] == Ansi::ESC
        return {2, key_from_byte(buf[1], ModShift | ModAlt)}
      end

      params = [] of Ansi::Param
      cmd = 0

      i = 0
      if buf[i] == Ansi::DCS || buf[i] == Ansi::ESC
        i += 1
      end
      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == 'P'.ord
        i += 1
      end

      if i < buf.size && buf[i] >= '<'.ord && buf[i] <= '?'.ord
        cmd |= (buf[i].to_i << Ansi::Parser::PrefixShift)
      end

      param_bytes = 0
      current = Ansi::Param.new
      while i < buf.size && params.size < 16 && buf[i] >= 0x30 && buf[i] <= 0x3f
        param_bytes += 1
        byte = buf[i]
        if byte >= '0'.ord && byte <= '9'.ord
          unless current.present?
            current.present = true
            current.value = 0
          end
          current.value = current.value * 10 + (byte - '0'.ord)
        end
        current.has_more = true if byte == ':'.ord
        if byte == ';'.ord || byte == ':'.ord
          params << current
          current = Ansi::Param.new
        end
        i += 1
      end

      if param_bytes > 0 && params.size < 16
        params << current
      end

      intermed = 0_u8
      while i < buf.size && buf[i] >= 0x20 && buf[i] <= 0x2f
        intermed = buf[i]
        i += 1
      end
      cmd |= (intermed.to_i << Ansi::Parser::IntermedShift)

      if i >= buf.size || buf[i] < 0x40 || buf[i] > 0x7e
        return {i, UnknownEvent.new(String.new(buf[0, i]))}
      end

      cmd |= buf[i].to_i
      i += 1

      start = i
      while i < buf.size
        break if buf[i] == Ansi::ST || buf[i] == Ansi::ESC
        i += 1
      end

      return {i, UnknownEvent.new(String.new(buf[0, i]))} if i >= buf.size

      ending = i
      i += 1

      if i < buf.size && buf[i - 1] == Ansi::ESC && buf[i] == '\\'.ord
        i += 1
      end

      pa = Ansi::Params.new(params)
      case cmd
      when ('r'.ord | ('+'.ord << Ansi::Parser::IntermedShift))
        param, _, _ = pa.param(0, 0)
        if param == 1
          return {i, parse_termcap(buf[start, ending - start])}
        end
      when ('|'.ord | ('>'.ord << Ansi::Parser::PrefixShift))
        return {i, TerminalVersionEvent.new(String.new(buf[start, ending - start]))}
      when ('|'.ord | ('!'.ord << Ansi::Parser::IntermedShift))
        return {i, parse_tertiary_dev_attrs(buf[start, ending - start])}
      end

      {i, UnknownDcsEvent.new(String.new(buf[0, i]))}
    end

    # ameba:enable Metrics/CyclomaticComplexity

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

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_control(b : UInt8) : Event
      if b == Ansi::NUL
        return Key.new(code: '@'.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_AT)
        return Key.new(code: KeySpace, mod: ModCtrl)
      end
      if b == Ansi::HT
        return Key.new(code: 'i'.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_I)
        return Key.new(code: KeyTab)
      end
      if b == Ansi::CR
        return Key.new(code: 'm'.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_M)
        return Key.new(code: KeyEnter)
      end
      if b == Ansi::ESC
        return Key.new(code: '['.ord, mod: ModCtrl) if @legacy.contains?(FLAG_CTRL_OPEN_BRACKET)
        return Key.new(code: KeyEscape)
      end
      if b == Ansi::DEL
        return Key.new(code: KeyDelete) if @legacy.contains?(FLAG_BACKSPACE)
        return Key.new(code: KeyBackspace)
      end
      if b == Ansi::BS
        return Key.new(code: 'h'.ord, mod: ModCtrl)
      end
      return Key.new(code: KeySpace, text: " ") if b == Ansi::SP

      if b >= Ansi::SOH && b <= Ansi::SUB
        code = b + 0x60
        return Key.new(code: code, mod: ModCtrl)
      end
      if b >= Ansi::FS && b <= Ansi::US
        code = b + 0x40
        return Key.new(code: code, mod: ModCtrl)
      end
      UnknownEvent.new(b.chr.to_s)
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

    # ameba:enable Metrics/CyclomaticComplexity

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

    # ameba:disable Metrics/CyclomaticComplexity
    private def parse_kitty_keyboard(params : Ansi::Params) : Event
      is_release = false
      key = Key.new

      param_idx = 0
      sub_idx = 0
      params.each do |param|
        case param_idx
        when 0
          case sub_idx
          when 0
            code = param.param(1)
            mapped = kitty_key_map[code]?
            key = mapped || Key.new(code: code)
          when 2
            shifted = param.param(1)
            if Ultraviolet.printable_char?(shifted)
              key.base_code = shifted
            end
            if Ultraviolet.printable_char?(shifted)
              key.shifted_code = shifted
            end
          when 1
            shifted = param.param(1)
            if Ultraviolet.printable_char?(shifted)
              key.shifted_code = shifted
            end
          end
        when 1
          case sub_idx
          when 0
            mod = param.param(1)
            if mod > 1
              key.mod = from_kitty_mod(mod - 1)
              key.text = "" if key.mod > ModShift
            end
          when 1
            case param.param(1)
            when 2
              key.is_repeat = true
            when 3
              is_release = true
            end
          end
        when 2
          code = param.param(0)
          key.text += Ultraviolet.safe_char(code).to_s if code != 0
        end

        sub_idx += 1
        unless param.has_more?
          param_idx += 1
          sub_idx = 0
        end
      end

      return KeyReleaseEvent.new(key.text, key.mod, key.code, key.shifted_code, key.base_code, key.is_repeat?) if is_release
      key
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def parse_kitty_keyboard_ext(params : Ansi::Params, key : Key) : Event
      return key if params.empty?
      return key if params.size < 3
      return key unless params[0].param(1) == 1 && params[2].param(1) == 1

      mod = params[1].param(1)
      return key if mod < 2

      key.mod |= from_kitty_mod(mod - 1)
      key.text = "" if key.mod > ModShift
      key
    end

    private def parse_primary_dev_attrs(params : Ansi::Params) : Event
      attrs = [] of Int32
      params.each do |param|
        attrs << param.param(0) unless param.has_more?
      end
      attrs
    end

    private def parse_secondary_dev_attrs(params : Ansi::Params) : Event
      attrs = [] of Int32
      params.each do |param|
        attrs << param.param(0) unless param.has_more?
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
      return mouse if wheel?(btn)
      return mouse if !is_motion && release
      return mouse if is_motion
      mouse
    end

    private def parse_x10_mouse_event(buf : Bytes) : Event
      v = buf[3, 3]
      b = v[0]
      b = b - 32 if b >= 32

      mod, btn, is_release, is_motion = parse_mouse_button(b)
      x = v[1] - 32 - 1
      y = v[2] - 32 - 1

      mouse = Mouse.new(x, y, btn, mod)
      return mouse if wheel?(btn)
      return mouse if is_motion
      return mouse if is_release
      mouse
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
      @@kitty_key_map ||= {
        Ansi::BS  => Key.new(code: KeyBackspace),
        Ansi::HT  => Key.new(code: KeyTab),
        Ansi::CR  => Key.new(code: KeyEnter),
        Ansi::ESC => Key.new(code: KeyEscape),
        Ansi::DEL => Key.new(code: KeyBackspace),

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
    end

    private def parse_win32_input_key_event(vkc : UInt16, _scan : UInt16, rune_value : Int32, key_down : Bool, cks : UInt32, repeat_count : UInt16) : Event
      base_code = rune_value
      code = rune_value
      text = ""

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
