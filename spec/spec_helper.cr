require "spec"
require "../src/ultraviolet"

# Pseudo terminals let specs drive a real Terminal: `start` requires a tty, so
# a pipe cannot stand in for one.
{% unless flag?(:win32) %}
  lib LibSpecUtil
    fun openpty(amaster : Int32*, aslave : Int32*, name : UInt8*, termp : LibC::Termios*, winp : Void*) : Int32
  end

  # pty_pair opens a pseudo terminal and returns its {master, slave} ends.
  # Writing to the master is what the terminal user's typing looks like.
  # A non-zero size is installed with the pty, the way a real terminal window
  # has dimensions before the program starts.
  def pty_pair(rows : Int32 = 0, cols : Int32 = 0) : {IO::FileDescriptor, IO::FileDescriptor}
    master_fd = uninitialized Int32
    slave_fd = uninitialized Int32
    winsize = uninitialized LibC::Winsize
    winp = Pointer(Void).null
    if rows > 0 || cols > 0
      winsize.ws_row = rows.to_u16
      winsize.ws_col = cols.to_u16
      winsize.ws_xpixel = 0_u16
      winsize.ws_ypixel = 0_u16
      winp = pointerof(winsize).as(Void*)
    end
    result = LibSpecUtil.openpty(pointerof(master_fd), pointerof(slave_fd), Pointer(UInt8).null, Pointer(LibC::Termios).null, winp)
    raise "openpty failed: #{Errno.value}" unless result == 0
    {IO::FileDescriptor.new(master_fd), IO::FileDescriptor.new(slave_fd)}
  end
{% end %}

# Feeds an SGR sequence through the parser and returns the resulting pen, the
# same path WrapWriter takes.
def parse_pen(sequence : String) : Ultraviolet::Style
  pen = Ultraviolet::Style.new
  parser = Ansi::Parser.new
  parser.set_handler(Ansi::Handler.new(
    handle_csi: ->(cmd : Ansi::Cmd, params : Ansi::Params) do
      pen = Ultraviolet.read_style(params, pen) if cmd == 'm'.ord
    end
  ))
  parser.parse(sequence)
  pen
end

# Returns the parser's parameters for an SGR sequence.
def parse_params(sequence : String) : Ansi::Params
  params : Ansi::Params? = nil
  parser = Ansi::Parser.new
  parser.set_handler(Ansi::Handler.new(
    handle_csi: ->(cmd : Ansi::Cmd, got : Ansi::Params) do
      params = got if cmd == 'm'.ord
    end
  ))
  parser.parse(sequence)
  params.not_nil!
end
