module Ultraviolet
  # DefaultBufferSize is the default size of the input buffer used for reading
  # terminal events.
  DEFAULT_BUFFER_SIZE = 4096

  # DefaultEventTimeout is the default duration to wait for input events before
  # timing out.
  DEFAULT_EVENT_TIMEOUT = 100.milliseconds

  # Options represents options for creating a new Terminal.
  #
  # Matching Go's `Options` struct at `terminal.go`.
  struct Options
    # BufferSize is the size of the input buffer used for reading terminal
    # events. If zero, DEFAULT_BUFFER_SIZE is used.
    property buffer_size : Int32

    # EventTimeout is the duration to wait for input events before timing out.
    # If zero, DEFAULT_EVENT_TIMEOUT is used.
    property event_timeout : Time::Span

    # LegacyKeyEncoding represents any legacy key encoding ambiguities.
    property legacy_key_encoding : LegacyKeyEncoding

    # LookupKeys whether to use a lookup table for common key sequences.
    property lookup_keys : Bool

    # UseTerminfoKeys whether to use terminfo databases key definitions to
    # build up the keys lookup table.
    property use_terminfo_keys : Bool

    def initialize(
      @buffer_size : Int32 = DEFAULT_BUFFER_SIZE,
      @event_timeout : Time::Span = DEFAULT_EVENT_TIMEOUT,
      @legacy_key_encoding : LegacyKeyEncoding = LegacyKeyEncoding.new,
      @lookup_keys : Bool = true,
      @use_terminfo_keys : Bool = false,
    )
    end

    # DefaultOptions returns the default options.
    def self.default : Options
      Options.new
    end
  end
end
