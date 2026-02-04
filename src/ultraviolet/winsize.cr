{% unless flag?(:win32) %}
lib LibC
  struct Winsize
    ws_row : UInt16
    ws_col : UInt16
    ws_xpixel : UInt16
    ws_ypixel : UInt16
  end

  fun ioctl(fd : Int32, request : LibC::ULong, argp : Void*) : Int32
end

module Ultraviolet
  {% if flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) %}
    TIOCGWINSZ = 0x40087468_u64
  {% elsif flag?(:linux) %}
    TIOCGWINSZ = 0x5413_u64
  {% else %}
    TIOCGWINSZ = 0x5413_u64
  {% end %}
end
{% end %}
