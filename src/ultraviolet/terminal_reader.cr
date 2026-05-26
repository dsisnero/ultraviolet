require "./decoder"
require "./key_table"
require "./cancelreader"
require "./event_scanner"

module Ultraviolet
  ErrReaderNotStarted = Exception.new("reader not started")

  DEFAULT_ESC_TIMEOUT = 50.milliseconds
  READ_BUF_SIZE       = 4096

  class TerminalReader
    property mouse_mode : MouseMode?
    property esc_timeout : Time::Span
    property buffer_size : Int32
    getter scanner : EventScanner

    @reader : IO
    @term : String
    @logger : Logger?
    @lookup : Bool = true

    {% if flag?(:win32) %}
      @vt_input : Bool = false
      @last_mouse_btns : UInt32 = 0_u32
      @last_winsize_x : Int32 = 0
      @last_winsize_y : Int32 = 0
    {% end %}

    def initialize(reader : IO, term_type : String, legacy : LegacyKeyEncoding = LegacyKeyEncoding.new, use_terminfo : Bool = false)
      @reader = reader
      @term = term_type
      @lookup = true
      @esc_timeout = DEFAULT_ESC_TIMEOUT
      @buffer_size = READ_BUF_SIZE
      @scanner = EventScanner.new(legacy, use_terminfo)
      @scanner.lookup = @lookup
      @scanner.build_table(@term)
      @logger = nil
    end

    def lookup? : Bool
      @lookup
    end

    def lookup=(value : Bool) : Bool
      @lookup = value
      @scanner.lookup = value
    end

    def lookup=(value : Bool) : Bool
      @lookup = value
      @scanner.lookup = value
    end

    def logger=(logger : Logger?) : Nil
      @logger = logger
      @scanner.logger = logger
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
              logf("input: %q", data)
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
              logf("timeout expired, processing buffer")
              processed = send_events(buffer, true, eventc)
              buffer = buffer[processed, buffer.size - processed] if processed > 0
              logf("resetting timeout for remaining buffer") if processed < buffer.size
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
              logf("timeout expired, processing buffer")
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
        buf = Bytes.new(@buffer_size)
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
      total, events = @scanner.scan_events(buf, expired)
      if ENV["UV_DEBUG_IO"]? && !events.empty?
        summary = events.map { |event| "#{event.class}(#{event})" }.join(", ")
        STDERR.puts("uv: events #{summary}")
      end
      events.each { |event| eventc.send(event) }
      total
    end

    private def logf(format : String, *args) : Nil
      return unless (l = @logger)
      l.printf(format, *args)
    end

    private def append_bytes(buffer : Bytes, data : Bytes) : Bytes
      return data if buffer.empty?
      combined = Bytes.new(buffer.size + data.size)
      combined.copy_from(buffer)
      combined[buffer.size, data.size].copy_from(data)
      combined
    end
  end
end
