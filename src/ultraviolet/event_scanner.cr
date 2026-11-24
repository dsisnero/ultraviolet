module Ultraviolet
  # EventScanner handles the low-level event scanning logic, matching Go's
  # `eventScanner` struct in terminal_reader.go. It embeds EventDecoder for
  # access to the Decode method.
  class EventScanner < EventDecoder
    property? lookup : Bool = true
    property logger : Logger?

    @utf16_half : Array(Bool)
    @utf16_buf : Array(Array(Int32))
    @grapheme_buf : Array(Array(Int32))
    @paste : Bytes?
    @table : Hash(String, Key)
    @logger : Logger?

    def initialize(legacy : LegacyKeyEncoding = LegacyKeyEncoding.new, use_terminfo : Bool = false)
      super(legacy, use_terminfo)
      @lookup = true
      @utf16_half = [false, false]
      @utf16_buf = [[0, 0], [0, 0]]
      @grapheme_buf = [Array(Int32).new, Array(Int32).new]
      @paste = nil
      @table = Hash(String, Key).new
      @logger = nil
    end

    def build_table(term : String)
      @table = Ultraviolet.build_keys_table(@legacy, term, @use_terminfo)
    end

    # Main scan method — matches Go's eventScanner.scanEvents.
    # ameba:disable Metrics/CyclomaticComplexity
    def scan_events(buf : Bytes, expired : Bool) : {Int32, Array(Event)}
      return {0, [] of Event} if buf.empty?

      logf("processing buf %d %q", buf.size, buf)

      total = 0
      dn, buf = deserialize_win32_input(buf)
      total += dn

      if @lookup && buf.size > 2 && buf[0] == Ansi::ESC
        if key = @table[String.new(buf)]?
          return {buf.size, [key.as(Event)]}
        end
      end

      events = [] of Event
      while buf.size > 0
        esc = buf[0] == Ansi::ESC
        n, event = decode(buf)
        break if n == 0

        if paste = @paste
          if event.is_a?(PasteEndEvent)
            # fall through to case
          else
            if event.is_a?(Key)
              key = event.as(Key)
              if !key.text.empty?
                @paste = append_bytes(paste, key.text.to_slice)
              else
                seq_bytes = buf[0, n]
                is_win32 = seq_bytes.size >= 3 && seq_bytes[0] == Ansi::ESC && seq_bytes[1] == '['.ord && seq_bytes[seq_bytes.size - 1] == '_'.ord
                if is_win32 && key.code == KeyEnter && key.code == key.base_code
                  @paste = append_bytes(paste, "\n".to_slice)
                elsif is_win32 && key.code == key.base_code && control_char?(key.code)
                  @paste = append_bytes(paste, Bytes.new(1, Ultraviolet.safe_char(key.code).ord.to_u8))
                elsif !is_win32
                  if esc && n <= 2 && !expired
                    return {total, events}
                  end
                  @paste = append_bytes(paste, seq_bytes)
                end
              end
            elsif !expired && event.is_a?(UnknownEvent)
              return {total, events}
            end
            buf = buf[n, buf.size - n]
            total += n
            next
          end
        end

        case event
        when String
          # ignored
        when UnknownEvent
          return {total, events} unless expired
          if key = @table[String.new(buf[0, n])]?
            events << key
            return {total + n, events}
          end
          events << event
        when PasteStartEvent
          @paste = Bytes.new(0)
          events << event
        when PasteEndEvent
          if paste = @paste
            events << PasteEvent.new(decode_paste_bytes(paste))
          else
            events << PasteEvent.new("")
          end
          @paste = nil
          events << event
        else
          if event
            if esc && n <= 2 && !expired
              return {total, events}
            end
            if event.is_a?(Array)
              event.as(Array(EventSingle)).each { |item| events << item }
            else
              events << event
            end
          end
        end

        buf = buf[n, buf.size - n]
        total += n
      end

      logf("processed %d bytes from buffer", total)
      {total, events}
    end

    # ameba:enable Metrics/CyclomaticComplexity

    protected def logf(format : String, *args) : Nil
      return unless l = @logger
      l.printf(format, *args)
    end

    protected def control_char?(code : Int32) : Bool
      return false if code < 0 || code > 0x10FFFF
      return false if code >= 0xD800 && code <= 0xDFFF
      begin
        code.chr.control?
      rescue
        false
      end
    end

    private def decode_paste_bytes(paste_bytes : Bytes) : String
      return "" if paste_bytes.empty?
      String.new(paste_bytes, "UTF-8", invalid: :skip)
    end

    private def append_bytes(buffer : Bytes, data : Bytes) : Bytes
      return data if buffer.empty?
      combined = Bytes.new(buffer.size + data.size)
      combined.copy_from(buffer)
      combined[buffer.size, data.size].copy_from(data)
      combined
    end

    # Mirrors Go's eventScanner.deserializeWin32Input
    # (terminal_reader.go:454): decode through the ANSI parser rather than
    # matching CSI shapes by hand, so prefixed, intermediate, multi-byte and
    # short-parameter records are classified exactly as Go classifies them.
    # The parser comes from the shard's pool, as Go takes one from `ansi`.
    protected def deserialize_win32_input(buf : Bytes) : {Int32, Bytes}
      parser = Ansi.get_parser
      begin
        deserialize_win32_input(buf, parser)
      ensure
        Ansi.put_parser(parser)
      end
    end

    private def deserialize_win32_input(buf : Bytes, parser : Ansi::Parser) : {Int32, Bytes}
      processed = 0
      state = Ansi::NormalState
      out = IO::Memory.new
      data = buf

      while data.size > 0
        seq, width, n, new_state = Ansi.decode_sequence(data, state, parser)
        # A zero-width sequence that the parser classifies as Win32 Input Mode
        # with virtual key 0 is a serialized key record or a UTF-16 half; it is
        # consumed instead of forwarded. Go's `break` leaves only the switch,
        # so the tail of the loop body still runs for the non-zero vk case.
        if width == 0 && parser.command == '_'.ord && parser.param(0, 0)[0] == 0
          kd = parser.param(3, 0)[0].clamp(0, 1)
          store_grapheme_rune(kd, parser.param(2, 0)[0])
          processed += n
        else
          out.write(encode_grapheme_bufs)
          out.write(seq)
        end

        state = new_state
        data = data[n, data.size - n]
        # Go cannot reach this, and neither can a caller that starts in the
        # normal state; stop rather than spin if the parser ever consumes none.
        break if n <= 0
      end

      out.write(encode_grapheme_bufs)
      {processed, out.to_slice}
    end

    # Mirrors Go's eventScanner.encodeGraphemeBufs (terminal_reader.go:390).
    # Two details are Go's, not a cleaner version of it: every kitty sequence
    # leads with the buffer's *first* rune (`graphemeBuf[kd][0]`) rather than
    # the grapheme's own first rune, and codepoints are joined by the rune's
    # byte offset (`for i, r := range gr`), which also emits a sequence for a
    # grapheme whose runes are all NUL.
    protected def encode_grapheme_bufs : Bytes
      out = IO::Memory.new
      @grapheme_buf.each_with_index do |buf, kind|
        next if buf.empty?
        if kind == 1
          buf.each do |code|
            out << Ultraviolet.safe_char(code).to_s
          end
        else
          first_code = buf[0]
          text = String.build do |io|
            buf.each { |code| io << Ultraviolet.safe_char(code) }
          end
          TextSegment.each_grapheme(text) do |segment|
            offset = 0
            codepoints = String.build do |io|
              segment.str.each_char do |char|
                unless char.ord == 0
                  io << ':' if offset > 0
                  io << char.ord
                end
                offset += char.bytesize
              end
            end
            out << "\e[#{first_code};1:3;#{codepoints}u"
          end
        end
        buf.clear
      end
      out.to_slice
    end

    protected def store_grapheme_rune(kd : Int32, code : Int32) : Nil
      idx = kd.clamp(0, 1)
      if @utf16_half[idx]
        @utf16_half[idx] = false
        @utf16_buf[idx][1] = code
        r = decode_surrogate(@utf16_buf[idx][0], @utf16_buf[idx][1])
        @grapheme_buf[idx] << r
      elsif surrogate?(code)
        @utf16_half[idx] = true
        @utf16_buf[idx][0] = code
      else
        @grapheme_buf[idx] << code
      end
    end

    private def surrogate?(code : Int32) : Bool
      code >= 0xD800 && code <= 0xDFFF
    end

    private def decode_surrogate(high : Int32, low : Int32) : Int32
      0x10000 + (high - 0xD800) * 0x400 + (low - 0xDC00)
    end
  end
end
