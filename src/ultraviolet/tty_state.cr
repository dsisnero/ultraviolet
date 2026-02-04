{% if flag?(:win32) %}
  module Ultraviolet
    alias TtyState = Nil
  end
{% else %}
  require "c/termios"

  module Ultraviolet
    alias TtyState = LibC::Termios
  end
{% end %}
