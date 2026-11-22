{% if flag?(:darwin) || flag?(:freebsd) || flag?(:openbsd) || flag?(:netbsd) || flag?(:dragonfly) %}
  require "./poll"

  module Ultraviolet
    # KqueueReader is Go's kqueue-based poll reader (poll_bsd.go).
    #
    # Crystal's event loop already waits on descriptors with kqueue on these
    # platforms, so this reader keeps the platform's identity and shares
    # [FdPollReader], which polls through the event loop instead of driving
    # `kevent` itself.
    class KqueueReader < FdPollReader
    end

    def self.new_poll_reader(reader : IO) : PollReader
      if reader.is_a?(IO::FileDescriptor)
        KqueueReader.new(reader)
      else
        FallbackReader.new(reader)
      end
    end
  end
{% end %}
