module Ultraviolet
  class SizeNotifier
    getter sig : Channel(Nil)

    def initialize(@tty : IO::FileDescriptor?)
      @sig = Channel(Nil).new(1)
      @lock = Mutex.new
      @running = false
    end

    def start : Nil
      {% if flag?(:win32) %}
        raise ErrPlatformNotSupported
      {% else %}
        @lock.synchronize do
          raise ErrNotTerminal unless terminal?(@tty)
          return if @running
          Signal::WINCH.trap { @sig.try_send(nil) }
          @running = true
        end
      {% end %}
    end

    def stop : Nil
      {% if flag?(:win32) %}
        return
      {% else %}
        @lock.synchronize do
          return unless @running
          Signal::WINCH.reset
          @running = false
        end
      {% end %}
    end

    def window_size : {Size, Size}
      {% if flag?(:win32) %}
        raise ErrPlatformNotSupported
      {% else %}
        raise ErrNotTerminal unless terminal?(@tty)

        winsize = uninitialized LibC::Winsize
        if LibC.ioctl(@tty.not_nil!.fd, TIOCGWINSZ, pointerof(winsize).as(Void*)) != 0
          raise Errno.new("ioctl")
        end

        cells = Size.new(winsize.ws_col.to_i, winsize.ws_row.to_i)
        pixels = Size.new(winsize.ws_xpixel.to_i, winsize.ws_ypixel.to_i)
        {cells, pixels}
      {% end %}
    end

    private def terminal?(tty : IO::FileDescriptor?) : Bool
      {% if flag?(:win32) %}
        false
      {% else %}
        return false unless tty
        LibC.isatty(tty.fd) == 1
      {% end %}
    end
  end
end
