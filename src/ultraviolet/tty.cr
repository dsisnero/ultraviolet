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

    def self.notify_winch_context(channel : Channel(Nil), stop : Channel(Nil)) : Nil
      raise ErrPlatformNotSupported
    end
  {% else %}
    # Fans a single SIGWINCH handler out to every active subscriber.
    private class WinchHub
      @@listeners = [] of Channel(Nil)
      @@mutex = Mutex.new
      @@installed = false

      def self.add(channel : Channel(Nil)) : Nil
        @@mutex.synchronize do
          @@listeners << channel unless @@listeners.includes?(channel)
          unless @@installed
            Signal::WINCH.trap do
              listeners = @@mutex.synchronize { @@listeners.dup }
              listeners.each do |listener|
                spawn do
                  begin
                    listener.send(nil)
                  rescue Channel::ClosedError
                  end
                end
              end
            end
            @@installed = true
          end
        end
      end

      def self.remove(channel : Channel(Nil)) : Nil
        @@mutex.synchronize do
          @@listeners.delete(channel)
          if @@listeners.empty? && @@installed
            Signal::WINCH.reset
            @@installed = false
          end
        end
      end
    end

    # Notifies the channel when the terminal receives SIGWINCH.
    #
    # Use a buffered channel, as the signal handler must not block.
    def self.notify_winch(channel : Channel(Nil)) : Nil
      WinchHub.add(channel)
    end

    # Notifies the channel on SIGWINCH until the stop channel receives or is
    # closed.
    #
    # Go's `NotifyWinchContext` uses `context.Context`; Crystal has no direct
    # equivalent, so callers pass a stop channel instead.
    def self.notify_winch_context(channel : Channel(Nil), stop : Channel(Nil)) : Nil
      WinchHub.add(channel)
      spawn do
        stop.receive?
        WinchHub.remove(channel)
      end
    end
  {% end %}
end
