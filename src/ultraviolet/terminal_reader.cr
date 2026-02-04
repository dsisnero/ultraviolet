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
    @paste : String?
    @logger : Logger?

    def initialize(reader : IO, term_type : String, legacy : LegacyKeyEncoding = LegacyKeyEncoding.new, use_terminfo : Bool = false)
      super(legacy, use_terminfo)
      @reader = reader
      @term = term_type
      @lookup = true
      @esc_timeout = DEFAULT_ESC_TIMEOUT
      @table = Ultraviolet.build_keys_table(@legacy, @term, use_terminfo?)
      @paste = nil
      @logger = nil
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
          send_bytes(readc, stop)
          errc.send(nil)
        rescue ex
          errc.send(ex)
        end
      end

      buffer = Bytes.empty
      deadline = Time.monotonic + @esc_timeout
      loop do
        if buffer.empty?
          select
          when data = readc.receive
            buffer = append_bytes(buffer, data)
            deadline = Time.monotonic + @esc_timeout
            processed = send_events(buffer, false, eventc)
            buffer = buffer[processed, buffer.size - processed] if processed > 0
          when err = errc.receive
            send_events(buffer, true, eventc)
            raise err if err
            break
          when _ = stop.try &.receive?
            send_events(buffer, true, eventc)
            break
          end
        else
          wait = deadline - Time.monotonic
          wait = 0.seconds if wait < 0.seconds
          select
          when data = readc.receive
            buffer = append_bytes(buffer, data)
            deadline = Time.monotonic + @esc_timeout
            processed = send_events(buffer, false, eventc)
            buffer = buffer[processed, buffer.size - processed] if processed > 0
          when err = errc.receive
            send_events(buffer, true, eventc)
            raise err if err
            break
          when timeout(wait)
            processed = send_events(buffer, true, eventc)
            buffer = buffer[processed, buffer.size - processed] if processed > 0
            deadline = Time.monotonic + @esc_timeout unless buffer.empty?
          when _ = stop.try &.receive?
            send_events(buffer, true, eventc)
            break
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
        break if n == 0
        readc.send(buf[0, n])
      end
    end

    private def send_events(buf : Bytes, expired : Bool, eventc : Channel(Event)) : Int32
      total, events = scan_events(buf, expired)
      events.each { |event| eventc.send(event) }
      total
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def scan_events(buf : Bytes, expired : Bool) : {Int32, Array(Event)}
      return {0, [] of Event} if buf.empty?

      if @lookup && buf.size > 2 && buf[0] == Ansi::ESC
        if key = @table[String.new(buf)]?
          return {buf.size, [key.as(Event)]}
        end
      end

      total = 0
      events = [] of Event
      while buf.size > 0
        esc = buf[0] == Ansi::ESC
        n, event = decode(buf)
        break if n == 0

        if paste = @paste
          if event.is_a?(PasteEndEvent)
            events << PasteEvent.new(paste)
            @paste = nil
          else
            if event.is_a?(Key)
              key = event.as(Key)
              if !key.text.empty?
                @paste = paste + key.text
              else
                @paste = paste + String.new(buf[0, n])
              end
            elsif !expired && event.is_a?(UnknownEvent)
              return {total, events}
            else
              @paste = paste + String.new(buf[0, n])
            end
          end
          buf = buf[n, buf.size - n]
          total += n
          next
        end

        case event
        when UnknownEvent
          return {total, events} unless expired
          if key = @table[String.new(buf[0, n])]?
            events << key
            return {total + n, events}
          end
          events << event
        when PasteStartEvent
          @paste = ""
        when PasteEndEvent
          events << PasteEvent.new
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

    private def append_bytes(buffer : Bytes, data : Bytes) : Bytes
      return data if buffer.empty?
      combined = Bytes.new(buffer.size + data.size)
      combined.copy_from(buffer)
      combined[buffer.size, data.size].copy_from(data)
      combined
    end
  end
end
