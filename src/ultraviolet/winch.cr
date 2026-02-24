{% if flag?(:win32) %}
  require "c/consoleapi"

  lib LibC
    struct Coord
      x : Int16
      y : Int16
    end

    struct SmallRect
      left : Int16
      top : Int16
      right : Int16
      bottom : Int16
    end

    struct ConsoleScreenBufferInfo
      dwSize : Coord
      dwCursorPosition : Coord
      wAttributes : UInt16
      srWindow : SmallRect
      dwMaximumWindowSize : Coord
    end

    fun GetConsoleScreenBufferInfo(hConsoleOutput : HANDLE, lpConsoleScreenBufferInfo : ConsoleScreenBufferInfo*) : BOOL
  end
{% end %}

module Ultraviolet
  class SizeNotifier
    getter sig : Channel(Nil)
    getter c : Channel(Nil) { @sig }

    def self.new_size_notifier(tty : IO::FileDescriptor?) : SizeNotifier
      raise "no file set" unless tty
      new(tty)
    end

    def initialize(@tty : IO::FileDescriptor?)
      @sig = Channel(Nil).new(1)
      @lock = Mutex.new
      @running = false
    end

    def start : Nil
      {% if flag?(:win32) %}
        raise ErrPlatformNotSupported
      {% elsif flag?(:darwin) || flag?(:dragonfly) || flag?(:freebsd) || flag?(:linux) || flag?(:netbsd) || flag?(:openbsd) || flag?(:solaris) || flag?(:aix) %}
        @lock.synchronize do
          raise ErrNotTerminal unless terminal?(@tty)
          return if @running
          Signal::WINCH.trap do
            begin
              @sig.send(nil)
            rescue Channel::ClosedError
            end
          end
          @running = true
        end
      {% else %}
        raise ErrPlatformNotSupported
      {% end %}
    end

    def stop : Nil
      {% if flag?(:win32) %}
        return
      {% elsif flag?(:darwin) || flag?(:dragonfly) || flag?(:freebsd) || flag?(:linux) || flag?(:netbsd) || flag?(:openbsd) || flag?(:solaris) || flag?(:aix) %}
        @lock.synchronize do
          return unless @running
          Signal::WINCH.reset
          @running = false
        end
      {% else %}
        raise ErrPlatformNotSupported
      {% end %}
    end

    def window_size : {Size, Size}
      {% if flag?(:win32) %}
        width, height = console_size
        {Size.new(width, height), Size.new(0, 0)}
      {% elsif flag?(:darwin) || flag?(:dragonfly) || flag?(:freebsd) || flag?(:linux) || flag?(:netbsd) || flag?(:openbsd) || flag?(:solaris) || flag?(:aix) %}
        raise ErrNotTerminal unless terminal?(@tty)

        winsize = uninitialized LibC::Winsize
        if LibC.ioctl(@tty.not_nil!.fd, TIOCGWINSZ, pointerof(winsize).as(Void*)) != 0
          raise IO::Error.from_errno("ioctl")
        end

        cells = Size.new(winsize.ws_col.to_i, winsize.ws_row.to_i)
        pixels = Size.new(winsize.ws_xpixel.to_i, winsize.ws_ypixel.to_i)
        {cells, pixels}
      {% else %}
        raise ErrPlatformNotSupported
      {% end %}
    end

    def size : {Int32, Int32}
      @lock.synchronize do
        cells, _ = window_size
        {cells.width, cells.height}
      end
    end

    private def terminal?(tty : IO::FileDescriptor?) : Bool
      {% if flag?(:win32) %}
        return false unless tty
        LibC.GetConsoleMode(LibC::HANDLE.new(tty.fd), out _) != 0
      {% elsif flag?(:darwin) || flag?(:dragonfly) || flag?(:freebsd) || flag?(:linux) || flag?(:netbsd) || flag?(:openbsd) || flag?(:solaris) || flag?(:aix) %}
        return false unless tty
        LibC.isatty(tty.fd) == 1
      {% else %}
        false
      {% end %}
    end

    private def console_size : {Int32, Int32}
      tty = @tty
      raise ErrNotTerminal unless tty
      handle = LibC::HANDLE.new(tty.fd)
      info = uninitialized LibC::ConsoleScreenBufferInfo
      if LibC.GetConsoleScreenBufferInfo(handle, pointerof(info)) == 0
        raise IO::Error.from_winerror("GetConsoleScreenBufferInfo")
      end
      width = info.srWindow.right.to_i - info.srWindow.left.to_i + 1
      height = info.srWindow.bottom.to_i - info.srWindow.top.to_i + 1
      {width, height}
    end
  end
end
