module Ultraviolet
  {% if flag?(:win32) %}
    def self.open_tty : {File, File}
      in_tty = File.open("CONIN$", "r+")
      out_tty = File.open("CONOUT$", "r+")
      {in_tty, out_tty}
    end

    def self.suspend : Nil
    end
  {% elsif flag?(:darwin) || flag?(:dragonfly) || flag?(:freebsd) || flag?(:linux) || flag?(:netbsd) || flag?(:openbsd) || flag?(:solaris) || flag?(:aix) %}
    def self.open_tty : {File, File}
      tty = File.open("/dev/tty", "r+")
      {tty, tty}
    end

    def self.suspend : Nil
      resumed = Channel(Nil).new(1)
      Signal::CONT.trap { resumed.try_send(nil) }
      Process.kill(Signal::TSTP, 0)
      resumed.receive
    ensure
      Signal::CONT.reset
    end
  {% else %}
    # Unsupported platform (matching Go's tty_other.go build tags)
    def self.open_tty : {File, File}
      raise ErrPlatformNotSupported
    end

    def self.suspend : Nil
      raise ErrPlatformNotSupported
    end
  {% end %}
end

module Ultraviolet
  {% if flag?(:win32) %}
    # Notifies the channel when the terminal window size changes.
    #
    # SIGWINCH is not available on Windows; this raises
    # [ErrPlatformNotSupported].
    def self.notify_winch(channel : Channel(Nil)) : Nil
      raise ErrPlatformNotSupported
    end
  {% else %}
    # Notifies the channel when the terminal receives SIGWINCH.
    #
    # Use a buffered channel, as the signal handler must not block.
    def self.notify_winch(channel : Channel(Nil)) : Nil
      Signal::WINCH.trap do
        begin
          channel.send(nil)
        rescue Channel::ClosedError
        end
      end
    end
  {% end %}
end
