require "log"

module Ultraviolet
  # Logger is a simple logger interface matching Go's Logger interface.
  # It can be implemented to provide custom logging, or use the built-in
  # LogBackend which delegates to Crystal's standard Log module.
  module Logger
    abstract def printf(format : String, *args)
  end

  # LogBackend implements Logger interface using Crystal's Log module.
  class LogBackend
    include Logger

    def initialize(@source : Log::Source = Log.for("ultraviolet"))
    end

    def printf(format : String, *args) : Nil
      # Use Kernel.sprintf for proper format string support
      message = sprintf(format, *args)
      @source.debug { message.chomp }
    end
  end

  # Default null logger that does nothing
  class NullLogger
    include Logger

    def printf(format : String, *args) : Nil
      # Do nothing
    end
  end
end
