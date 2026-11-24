# Shared pty capture for the example harnesses.
#
# `script(1)` cannot be used here: it echoes pty noise on macOS and prints
# "Session terminated" on Linux, which made otherwise identical program output
# differ. Owning the pty also pins the size, so a capture depends only on the
# program being run.
require "process"
require "../../src/ultraviolet"

lib LibUtil
  fun openpty(amaster : Int32*, aslave : Int32*, name : UInt8*, termp : LibC::Termios*, winp : Void*) : Int32
end

module PtyCapture
  extend self

  ROWS     = 24
  COLS     = 80
  IDLE     = 1.second
  DEADLINE = 8.seconds
  LIMIT    = 8192

  # Examples that animate on a one second clock: the default idle gap is the same
  # length as their tick period, so a capture stops at whichever tick happened to
  # drift past it. Give those a window longer than the period.
  IDLE_OVERRIDES = {
    "panic" => 2.seconds,
  }

  # Examples whose stream ends with output only one language can produce (a panic
  # report and its backtrace). Everything from the marker on is dropped, so the
  # comparison covers the frames and the shutdown, not the report.
  CUT = {
    "panic" => "recovered from panic",
  }

  # capture runs *binary* with its stdio on a fresh 80x24 pty and returns what
  # it wrote before the output went quiet.
  #
  # An animating program never goes quiet, so the cut is a byte count for those
  # and "everything before the idle gap" for the rest. Taking whichever comes
  # first keeps both classes deterministic: time decides how much of a fixed
  # byte stream has been produced, never what it contains.
  # capture_example captures one example by name, applying its idle window and
  # dropping any language-specific tail (see `IDLE_OVERRIDES` and `CUT`).
  def capture_example(binary : String, name : String, chdir : String? = nil) : String
    output = capture(binary, chdir: chdir, idle: IDLE_OVERRIDES.fetch(name, IDLE))
    if marker = CUT[name]?
      if index = output.index(marker)
        output = output[0, index]
      end
    end
    output
  end

  def capture(binary : String, limit : Int32 = LIMIT, chdir : String? = nil, idle : Time::Span = IDLE) : String
    master_fd = uninitialized Int32
    slave_fd = uninitialized Int32
    winsize = uninitialized LibC::Winsize
    winsize.ws_row = ROWS.to_u16
    winsize.ws_col = COLS.to_u16
    winsize.ws_xpixel = 0_u16
    winsize.ws_ypixel = 0_u16

    status = LibUtil.openpty(pointerof(master_fd), pointerof(slave_fd),
      Pointer(UInt8).null, Pointer(LibC::Termios).null, pointerof(winsize).as(Void*))
    raise "openpty failed" unless status == 0

    master = IO::FileDescriptor.new(master_fd)
    slave = IO::FileDescriptor.new(slave_fd)
    process = Process.new(binary, input: slave, output: slave, error: slave,
      chdir: chdir, env: {"TERM" => "xterm-256color"})
    slave.close

    output = IO::Memory.new
    begin
      deadline = Time.instant + DEADLINE
      # The first byte gets the whole budget: process start takes milliseconds to
      # seconds depending on load, and a short first timeout captured nothing at
      # all. Only once data flows does the idle gap mean "frame complete".
      master.read_timeout = DEADLINE
      while Time.instant < deadline
        buffer = Bytes.new(4096)
        read = master.read(buffer)
        break if read == 0
        output.write(buffer[0, read])
        break if output.size >= limit
        master.read_timeout = idle
      end
    rescue IO::TimeoutError
      # Idle: the first frame is complete.
    ensure
      process.terminate
      begin
        process.wait
      rescue
      end
      master.close
    end

    output.to_s[0, Math.min(output.size, limit)]
  end
end
