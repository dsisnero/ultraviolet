module Ultraviolet
  class Console
    getter input : IO
    getter output : IO
    getter environ : Array(String)

    def initialize(@input : IO, @output : IO, @environ : Array(String))
    end

    def self.default : Console
      Console.new(STDIN, STDOUT, ENV.map { |k, v| "#{k}=#{v}" })
    end

    def self.controlling : Console
      in_tty, out_tty = Ultraviolet.open_tty
      Console.new(in_tty, out_tty, ENV.map { |k, v| "#{k}=#{v}" })
    end

    def reader : IO
      @input
    end

    def writer : IO
      @output
    end

    def getenv(key : String) : String
      prefix = "#{key}="
      entry = @environ.find(&.starts_with?(prefix))
      return "" unless entry
      entry[prefix.bytesize..]
    end

    def lookup_env(key : String) : {String, Bool}
      prefix = "#{key}="
      if entry = @environ.find(&.starts_with?(prefix))
        {entry[prefix.bytesize..], true}
      else
        {"", false}
      end
    end
  end
end
