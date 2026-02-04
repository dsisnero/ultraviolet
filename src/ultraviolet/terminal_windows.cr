{% if flag?(:win32) %}
  module Ultraviolet
    class Terminal
      private def optimize_movements : Nil
      end

      private def make_raw : Nil
        raise ErrPlatformNotSupported
      end

      private def restore_tty : Nil
        raise ErrPlatformNotSupported
      end
    end
  end
{% end %}
