module Ultraviolet
  # ImageEncoding represents the encoding used for images in terminal, matching
  # Go's `imageEncoding` type in examples/image/main.go.
  enum ImageEncoding
    Unknown
    Blocks
    Sixel
    ITerm
    Kitty

    def to_s(io : IO) : Nil
      io << case self
      in .blocks?  then "blocks"
      in .sixel?   then "sixel"
      in .iterm?   then "iterm"
      in .kitty?   then "kitty"
      in .unknown? then "unknown"
      end
    end
  end
end
