require "./decoder"
require "./key_table"
require "./cancelreader"

module Ultraviolet
  ErrReaderNotStarted = Exception.new("reader not started")

  DEFAULT_ESC_TIMEOUT = 50.milliseconds
  READ_BUF_SIZE       = 4096

  class TerminalReader < EventDecoder
    property mouse_mode : MouseMode?
    property esc_timeout : Time::Span

    @reader : IO
    @table : Hash(String, Key)
    @term : String
    @lookup : Bool
    @paste : Bytes?
    @logger : Logger?
    @utf16_half : Array(Bool)
    @utf16_buf : Array(Array(Int32))
    @grapheme_buf : Array(Array(Int32))
    {% if flag?(:win32) %}
      @vt_input : Bool = false
      @last_mouse_btns : UInt32 = 0_u32
      @last_winsize_x : Int32 = 0
      @last_winsize_y : Int32 = 0
    {% end %}

    def initialize(reader : IO, term_type : String, legacy : LegacyKeyEncoding = LegacyKeyEncoding.new, use_terminfo : Bool = false)
      super(legacy, use_terminfo)
      @reader = reader
      @term = term_type
      @lookup = true
      @esc_timeout = DEFAULT_ESC_TIMEOUT
      @table = Ultraviolet.build_keys_table(@legacy, @term, use_terminfo?)
      @paste = nil
      @logger = nil
      @utf16_half = [false, false]
      @utf16_buf = [[0, 0], [0, 0]]
      @grapheme_buf = [Array(Int32).new, Array(Int32).new]
    end

    def logger=(logger : Logger?) : Nil
      @logger = logger
    end

    # ameba:disable Metrics/CyclomaticComplexity
    def stream_events(eventc : Channel(Event), stop : Channel(Nil)? = nil) : Nil
      readc = Channel(Bytes).new
      errc = Channel(Exception?).new(1)

      spawn do
        begin
          stream_data(readc, stop)
          errc.send(nil)
        rescue ex
          errc.send(ex)
        end
      end

      buffer = Bytes.empty
      deadline = Time.instant + @esc_timeout
      loop do
        if buffer.empty?
          if stop
            select
            when data = readc.receive
              buffer = append_bytes(buffer, data)
              deadline = Time.instant + @esc_timeout
              processed = send_events(buffer, false, eventc)
              buffer = buffer[processed, buffer.size - processed] if processed > 0
            when err = errc.receive
              send_events(buffer, true, eventc)
              raise err if err && !err.is_a?(CancelError)
              break
            when _ = stop.receive?
              send_events(buffer, true, eventc)
              break
            end
          else
            select
            when data = readc.receive
              buffer = append_bytes(buffer, data)
              deadline = Time.instant + @esc_timeout
              processed = send_events(buffer, false, eventc)
              buffer = buffer[processed, buffer.size - processed] if processed > 0
            when err = errc.receive
              send_events(buffer, true, eventc)
              raise err if err && !err.is_a?(CancelError)
              break
            end
          end
        else
          wait = deadline - Time.instant
          wait = 0.seconds if wait < 0.seconds
          if stop
            select
            when data = readc.receive
              buffer = append_bytes(buffer, data)
              deadline = Time.instant + @esc_timeout
              processed = send_events(buffer, false, eventc)
              buffer = buffer[processed, buffer.size - processed] if processed > 0
            when err = errc.receive
              send_events(buffer, true, eventc)
              raise err if err && !err.is_a?(CancelError)
              break
            when timeout(wait)
              processed = send_events(buffer, true, eventc)
              buffer = buffer[processed, buffer.size - processed] if processed > 0
              deadline = Time.instant + @esc_timeout unless buffer.empty?
            when _ = stop.receive?
              send_events(buffer, true, eventc)
              break
            end
          else
            select
            when data = readc.receive
              buffer = append_bytes(buffer, data)
              deadline = Time.instant + @esc_timeout
              processed = send_events(buffer, false, eventc)
              buffer = buffer[processed, buffer.size - processed] if processed > 0
            when err = errc.receive
              send_events(buffer, true, eventc)
              raise err if err && !err.is_a?(CancelError)
              break
            when timeout(wait)
              processed = send_events(buffer, true, eventc)
              buffer = buffer[processed, buffer.size - processed] if processed > 0
              deadline = Time.instant + @esc_timeout unless buffer.empty?
            end
          end
        end
      end
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def send_bytes(readc : Channel(Bytes), stop : Channel(Nil)?) : Nil
      loop do
        break if stop && stop.closed?
        buf = Bytes.new(READ_BUF_SIZE)
        n = @reader.read(buf)
        if n == 0
          STDERR.puts("uv: read eof") if ENV["UV_DEBUG_IO"]?
          break
        end
        if ENV["UV_DEBUG_IO"]?
          slice = buf[0, n]
          hex = String.build do |io|
            slice.each_with_index do |byte, idx|
              io << ' ' if idx > 0
              io << byte.to_s(16).rjust(2, '0')
            end
          end
          STDERR.puts("uv: read #{n} bytes: #{hex}")
        end
        readc.send(buf[0, n])
      end
    end

    private def stream_data(readc : Channel(Bytes), stop : Channel(Nil)?) : Nil
      send_bytes(readc, stop)
    end

    private def send_events(buf : Bytes, expired : Bool, eventc : Channel(Event)) : Int32
      total, events = scan_events(buf, expired)
      if ENV["UV_DEBUG_IO"]? && !events.empty?
        summary = events.map { |event| "#{event.class}(#{event})" }.join(", ")
        STDERR.puts("uv: events #{summary}")
      end
      events.each { |event| eventc.send(event) }
      total
    end

    # TODO: Ensure behavior matches Go's scanEvents (logging, control char detection, etc.)
    # ameba:disable Metrics/CyclomaticComplexity
    private def scan_events(buf : Bytes, expired : Bool) : {Int32, Array(Event)}
      return {0, [] of Event} if buf.empty?

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
            # fall through to case statement
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
          # ignore this event
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

      {total, events}
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def control_char?(code : Int32) : Bool
      return false if code < 0 || code > 0x10FFFF
      return false if code >= 0xD800 && code <= 0xDFFF # surrogates
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

    # TODO: Compare with Go's deserializeWin32Input (uses ansi.DecodeSequence)
    private def deserialize_win32_input(buf : Bytes) : {Int32, Bytes}
      processed = 0
      out = IO::Memory.new
      i = 0
      while i < buf.size
        if buf[i] == Ansi::ESC && i + 1 < buf.size && buf[i + 1] == '['.ord
          seq_len, params = parse_win32_sequence(buf, i)
          if seq_len == 0
            break
          end
          if seq_len == -1
            out.write(encode_grapheme_bufs)
            out.write_byte(buf[i])
            i += 1
            next
          end

          if params.size == 6
            vk = params[0]
            if vk == 0
              uc = params[2]
              kd = params[3]
              kd = kd.clamp(0, 1)
              store_grapheme_rune(kd, uc)
              processed += seq_len
              i += seq_len
              next
            end
          end

          out.write(encode_grapheme_bufs)
          out.write(buf[i, seq_len])
          i += seq_len
          next
        end

        out.write(encode_grapheme_bufs)
        out.write_byte(buf[i])
        i += 1
      end

      out.write(encode_grapheme_bufs)
      result = out.to_slice
      if i < buf.size
        result = append_bytes(result, buf[i, buf.size - i])
      end
      {processed, result}
    end

    private def parse_win32_sequence(buf : Bytes, start : Int32) : {Int32, Array(Int32)}
      return {0, [] of Int32} if start + 2 >= buf.size
      return {0, [] of Int32} unless buf[start] == Ansi::ESC && buf[start + 1] == '['.ord

      params = [] of Int32
      value = 0
      has_value = false
      i = start + 2
      while i < buf.size
        byte = buf[i]
        if byte >= '0'.ord && byte <= '9'.ord
          value = value * 10 + (byte - '0'.ord)
          has_value = true
        elsif byte == ';'.ord
          params << (has_value ? value : 0)
          value = 0
          has_value = false
        else
          if byte == '_'.ord
            params << (has_value ? value : 0)
            return {i - start + 1, params}
          end
          return {-1, [] of Int32}
        end
        i += 1
      end

      {0, [] of Int32}
    end

    # TODO: Verify grapheme encoding matches Go's encodeGraphemeBufs (kitty keyboard sequences)
    private def encode_grapheme_bufs : Bytes
      out = IO::Memory.new
      @grapheme_buf.each_with_index do |buf, kind|
        next if buf.empty?
        if kind == 1
          buf.each do |code|
            out << Ultraviolet.safe_char(code).to_s
          end
        else
          graphemes = String.build do |io|
            buf.each { |code| io << Ultraviolet.safe_char(code) }
          end
          TextSegment.each_grapheme(graphemes) do |segment|
            grapheme = segment.str
            codes = [] of String
            first_code = 0
            grapheme.each_char_with_index do |char, idx|
              next if char.ord == 0
              codes << char.ord.to_s
              first_code = char.ord if idx == 0
            end
            next if codes.empty?
            seq = "\e[#{first_code};1:3;#{codes.join(":")}u"
            out << seq
          end
        end
        buf.clear
      end
      out.to_slice
    end

    private def store_grapheme_rune(kd : Int32, code : Int32) : Nil
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
      return 0xFFFD unless high >= 0xD800 && high <= 0xDBFF && low >= 0xDC00 && low <= 0xDFFF
      0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
    end
  end
end
