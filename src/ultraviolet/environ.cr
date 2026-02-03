module Ultraviolet
  struct Environ
    getter items : Array(String)

    def initialize(@items : Array(String))
    end

    def getenv(key : String) : String
      value, _found = lookup_env(key)
      value
    end

    def lookup_env(key : String) : {String, Bool}
      needle = "#{key}="
      i = @items.size - 1
      while i >= 0
        entry = @items[i]
        if entry.starts_with?(needle)
          return {entry[needle.size..], true}
        end
        i -= 1
      end
      {"", false}
    end
  end
end
