{% if flag?(:win32) %}
  # Type-check the Windows console reader layer for the Windows target.
  #
  # macOS/Linux cannot require "c/consoleapi", so a normal `crystal build` skips
  # every win32-gated file. scripts/check_win32.sh compiles this driver with
  # `--target x86_64-windows-msvc --no-codegen`, which runs the semantic
  # analysis against the Windows stdlib without linking or executing.
  #
  # Crystal types method bodies lazily, so requiring the library is not enough:
  # an error inside a method that nothing calls goes unnoticed. The `if false`
  # block below is semantic-checked but never executed (the driver is built with
  # --no-codegen), and it makes the reader methods reachable so their bodies are
  # type-checked too.
  require "../src/ultraviolet"

  module Win32Typecheck
    def self.reader_layer : Nil
      conin = Ultraviolet::ConInputReader.new(LibC::HANDLE.null)
      conin.wait_for_input
      conin.cancel
      conin.close
      conin.read(Bytes.new(0))

      # Reach send_bytes_windows through the public stream entry point, so the
      # reader loop's body is type-checked too.
      reader = Ultraviolet::TerminalReader.new(conin, "xterm-256color")
      reader.stream_events(Channel(Ultraviolet::Event).new(1))
    end
  end

  if false
    Win32Typecheck.reader_layer
  end
{% end %}
