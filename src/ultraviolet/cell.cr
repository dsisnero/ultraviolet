require "./style"

module Ultraviolet
  alias WidthMethod = Proc(String, Int32)

  DEFAULT_WIDTH_METHOD = ->(str : String) do
    count = 0
    str.each_grapheme { count += 1 }
    count
  end

  struct Link
    getter url : String
    getter params : String

    def initialize(@url : String = "", @params : String = "")
    end

    def empty? : Bool
      @url.empty? && @params.empty?
    end

    def string : String
      @url
    end

    def start_sequence : String
      return "" if @url.empty?
      "\e]8;#{@params};#{@url}\a"
    end

    def end_sequence : String
      return "" if @url.empty?
      "\e]8;;\a"
    end
  end

  struct Cell
    property content : String
    property style : Style
    property link : Link
    property width : Int32

    def initialize(
      @content : String = "",
      @width : Int32 = 0,
      @style : Style = Style.new,
      @link : Link = Link.new,
    )
    end

    def self.empty : Cell
      Cell.new(" ", 1)
    end

    def self.new_cell(method : WidthMethod, grapheme : String) : Cell
      return Cell.new if grapheme.empty?
      return Cell.empty if grapheme == " "
      Cell.new(grapheme, method.call(grapheme))
    end

    def string : String
      @content
    end

    def zero? : Bool
      @content.empty? && @width == 0 && @style.zero? && @link.empty?
    end

    def clone : Cell
      Cell.new(@content, @width, @style, @link)
    end

    def empty! : Nil
      @content = " "
      @width = 1
    end
  end

  EMPTY_CELL = Cell.empty

  def self.new_link(url : String, params : Array(String) = [] of String) : Link
    Link.new(url, params.join(":"))
  end
end
