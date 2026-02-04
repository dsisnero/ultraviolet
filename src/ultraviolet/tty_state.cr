{% if flag?(:win32) %}
  require "c/consoleapi"

  module Ultraviolet
    alias TtyState = LibC::DWORD
  end
{% else %}
  require "c/termios"

  module Ultraviolet
    alias TtyState = LibC::Termios
  end
{% end %}
