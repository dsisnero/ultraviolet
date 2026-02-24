# This file provides stub implementations for platforms not supported by
# terminal_unix.cr or terminal_windows.cr (matching Go's terminal_other.go).
# It uses the same build logic as Go's terminal_other.go:
# !darwin && !dragonfly && !freebsd && !linux && !netbsd && !openbsd && !solaris && !aix && !windows

{% unless flag?(:darwin) || flag?(:dragonfly) || flag?(:freebsd) || flag?(:linux) || flag?(:netbsd) || flag?(:openbsd) || flag?(:solaris) || flag?(:aix) || flag?(:win32) %}
  module Ultraviolet
    class Terminal
      private def make_raw : Nil
        raise ErrPlatformNotSupported
      end

      private def platform_size : {Int32, Int32}
        raise ErrPlatformNotSupported
      end

      def enable_windows_mouse : Nil
        raise ErrPlatformNotSupported
      end

      def disable_windows_mouse : Nil
        raise ErrPlatformNotSupported
      end

      private def optimize_movements : Nil
        # No-op for unsupported platforms
      end
    end
  end
{% end %}
