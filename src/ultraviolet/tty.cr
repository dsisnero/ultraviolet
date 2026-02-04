module Ultraviolet
  {% if flag?(:win32) %}
    def self.open_tty : {File, File}
      raise ErrPlatformNotSupported
    end

    def self.suspend : Nil
      raise ErrPlatformNotSupported
    end
  {% else %}
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
  {% end %}
end
