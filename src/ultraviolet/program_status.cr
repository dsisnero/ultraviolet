require "ansi"
require "base64"

# Program Status Protocol (OSC 7501) support.
#
# This is a port of charmbracelet/x/ansi's program status implementation. The
# ansi shard does not expose these types yet, so they live here until they are
# available upstream.
module Ansi
  # ProgramState is the state of a program reported with the Program Status
  # Protocol (OSC 7501).
  #
  # See: https://www.superlogical.com/rex/docs/build/program-status
  alias ProgramState = String

  # Program states.
  ProgramStateIdle    = "idle"
  ProgramStateWorking = "working"
  ProgramStateDone    = "done"
  ProgramStateBlocked = "blocked"
  ProgramStateError   = "error"
  ProgramStateClear   = "clear"

  # ProgramStatusKind says what a blocked program is waiting for.
  alias ProgramStatusKind = String

  # Program status kinds.
  ProgramStatusKindPermission = "permission"
  ProgramStatusKindQuestion   = "question"
  ProgramStatusKindAuth       = "auth"

  # ProgramStatus is a report of the Program Status Protocol (OSC 7501).
  #
  # Each report replaces its record completely, so fields such as app and title
  # should be included in every report.
  #
  # See: https://www.superlogical.com/rex/docs/build/program-status
  struct ProgramStatus
    # State is the program state. Required.
    property state : ProgramState

    # ID addresses a record. Empty means the root record. It is a "/"
    # separated path of segments matching [A-Za-z0-9_.+-]{1,32}.
    property id : String

    # App is a stable machine-readable program name matching
    # [A-Za-z0-9_.+-]{1,32}. Invalid values are omitted.
    property app : String

    # Kind says what a blocked program waits for. Only used with
    # ProgramStateBlocked.
    property kind : ProgramStatusKind

    # Progress is a percentage between 0 and 100. Only used with
    # ProgramStateWorking and ProgramStateBlocked when has_progress is true.
    # Otherwise progress is indeterminate.
    property progress : Int32

    # HasProgress reports whether progress is set.
    property? has_progress : Bool

    # Title is a short human-readable label for the record.
    property title : String

    # Message is one human-readable line describing the record.
    property message : String

    def initialize(
      @state : ProgramState = "",
      @id : String = "",
      @app : String = "",
      @kind : ProgramStatusKind = "",
      @progress : Int32 = 0,
      @has_progress : Bool = false,
      @title : String = "",
      @message : String = "",
    )
    end
  end

  # ClearProgramStatus is a sequence that removes every program status record
  # on the terminal.
  #
  #   OSC 7501 ; state=clear BEL
  #
  # See: https://www.superlogical.com/rex/docs/build/program-status
  ClearProgramStatus = "\e]7501;state=clear\a"

  # RequestProgramStatusSupport is a sequence that asks the terminal whether it
  # supports the Program Status Protocol. A supporting terminal replies with
  # OSC 7501 ; ? ST.
  #
  #   OSC 7501 ; ? BEL
  #
  # See: https://www.superlogical.com/rex/docs/build/program-status
  RequestProgramStatusSupport = "\e]7501;?\a"

  # ClearProgramStatusID returns a sequence that removes the record with the
  # given id and every record beneath it. An empty id removes every record. It
  # returns an empty string if the id is invalid.
  #
  #   OSC 7501 ; state=clear:id=Id BEL
  def self.clear_program_status_id(id : String) : String
    set_program_status(ProgramStatus.new(state: ProgramStateClear, id: id))
  end

  # SetProgramStatus returns a sequence that reports a program status using the
  # Program Status Protocol (OSC 7501).
  #
  #   OSC 7501 ; key=value:key=value BEL
  #
  # Terminals discard a whole report when any part of it is invalid, so the
  # report is sanitized: control characters in title and message are replaced
  # with spaces and the text is truncated to the protocol limits, and an
  # invalid app, or a kind or progress used with the wrong state, is omitted.
  # It returns an empty string if the state is unknown or the id is invalid.
  #
  # See: https://www.superlogical.com/rex/docs/build/program-status
  # ameba:disable Metrics/CyclomaticComplexity, Naming/AccessorMethodName
  def self.set_program_status(status : ProgramStatus) : String
    case status.state
    when ProgramStateIdle, ProgramStateWorking, ProgramStateDone,
         ProgramStateBlocked, ProgramStateError, ProgramStateClear
    else
      return ""
    end

    unless status.id.empty? || valid_program_status_id?(status.id)
      return ""
    end

    pairs = ["state=#{status.state}"]
    pairs << "id=#{status.id}" unless status.id.empty?
    return program_status_sequence(pairs) if status.state == ProgramStateClear

    if status.state == ProgramStateBlocked && valid_program_status_kind?(status.kind)
      pairs << "kind=#{status.kind}"
    end

    if status.has_progress? && (status.state == ProgramStateWorking || status.state == ProgramStateBlocked)
      pairs << "progress=#{status.progress.clamp(0, 100)}"
    end

    pairs << "app=#{status.app}" if valid_program_status_segment?(status.app)

    title = program_status_text(status.title, 192)
    pairs << "title=#{title}" unless title.empty?

    message = program_status_text(status.message, 2048)
    pairs << "msg=#{message}" unless message.empty?

    program_status_sequence(pairs)
  end

  # ameba:enable Metrics/CyclomaticComplexity, Naming/AccessorMethodName

  private def self.program_status_sequence(pairs : Array(String)) : String
    "\e]7501;#{pairs.join(':')}\a"
  end

  private def self.valid_program_status_kind?(kind : ProgramStatusKind) : Bool
    case kind
    when ProgramStatusKindPermission, ProgramStatusKindQuestion, ProgramStatusKindAuth
      true
    else
      false
    end
  end

  # Sanitizes, truncates, and base64 encodes free text.
  private def self.program_status_text(text : String, limit : Int32) : String
    text = text.scrub

    builder = String::Builder.new
    space = false
    text.each_char do |char|
      codepoint = char.ord
      if codepoint < 0x20 || (codepoint >= 0x7f && codepoint <= 0x9f)
        unless space
          builder << ' '
          space = true
        end
        next
      end

      space = false
      builder << char
    end

    text = builder.to_s.strip
    if text.bytesize > limit
      bytes = text.to_slice
      size = limit
      while size > 0 && !String.new(bytes[0, size]).valid_encoding?
        size -= 1
      end
      text = String.new(bytes[0, size]).strip
    end

    return "" if text.empty?

    Base64.strict_encode(text)
  end

  private def self.valid_program_status_id?(id : String) : Bool
    return false if id.bytesize > 128

    segments = id.split('/')
    return false if segments.size > 8

    segments.all? { |segment| valid_program_status_segment?(segment) }
  end

  private def self.valid_program_status_segment?(segment : String) : Bool
    segment.matches?(/\A[A-Za-z0-9_.+-]{1,32}\z/)
  end
end

module Ultraviolet
  alias ProgramStatus = Ansi::ProgramStatus
  alias ProgramState = Ansi::ProgramState
  alias ProgramStatusKind = Ansi::ProgramStatusKind

  # Program states.
  ProgramStateIdle    = Ansi::ProgramStateIdle
  ProgramStateWorking = Ansi::ProgramStateWorking
  ProgramStateDone    = Ansi::ProgramStateDone
  ProgramStateBlocked = Ansi::ProgramStateBlocked
  ProgramStateError   = Ansi::ProgramStateError
  ProgramStateClear   = Ansi::ProgramStateClear

  # Program status kinds.
  ProgramStatusKindPermission = Ansi::ProgramStatusKindPermission
  ProgramStatusKindQuestion   = Ansi::ProgramStatusKindQuestion
  ProgramStatusKindAuth       = Ansi::ProgramStatusKindAuth

  # ProgramStatusSupportEvent is emitted when the terminal replies to a Program
  # Status Protocol (OSC 7501) feature detection query, meaning the terminal
  # supports the protocol.
  #
  # See: https://www.superlogical.com/rex/docs/build/program-status
  struct ProgramStatusSupportEvent
  end

  # EncodeProgramStatus encodes the program status to the given writer. A nil
  # status removes every program status record on the terminal.
  def self.encode_program_status(io : IO, status : ProgramStatus?) : Nil
    if status
      sequence = Ansi.set_program_status(status)
      io << sequence unless sequence.empty?
    else
      io << Ansi::ClearProgramStatus
    end
  end
end
