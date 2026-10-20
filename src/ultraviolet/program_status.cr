require "ansi"

module Ultraviolet
  alias ProgramStatus = Ansi::ProgramStatus
  alias ProgramState = Ansi::ProgramState
  alias ProgramStatusKind = Ansi::ProgramStatusKind

  # Program states.
  ProgramStateIdle    = Ansi::ProgramState::Idle
  ProgramStateWorking = Ansi::ProgramState::Working
  ProgramStateDone    = Ansi::ProgramState::Done
  ProgramStateBlocked = Ansi::ProgramState::Blocked
  ProgramStateError   = Ansi::ProgramState::Error
  ProgramStateClear   = Ansi::ProgramState::Clear

  # Program status kinds.
  ProgramStatusKindPermission = Ansi::ProgramStatusKind::Permission
  ProgramStatusKindQuestion   = Ansi::ProgramStatusKind::Question
  ProgramStatusKindAuth       = Ansi::ProgramStatusKind::Auth

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
