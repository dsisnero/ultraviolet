{% if flag?(:linux) %}
  require "./poll"

  module Ultraviolet
    # EpollReader is Go's epoll-based poll reader (poll_linux.go).
    #
    # Crystal's event loop already waits on descriptors with epoll on Linux, so
    # this reader keeps the platform's identity and shares [FdPollReader], which
    # polls through the event loop instead of creating an epoll set of its own.
    class EpollReader < FdPollReader
    end

    def self.new_poll_reader(reader : IO) : PollReader
      if reader.is_a?(IO::FileDescriptor)
        EpollReader.new(reader)
      else
        FallbackReader.new(reader)
      end
    end
  end
{% end %}
