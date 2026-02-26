require "textseg"

module Ultraviolet
  module Screen
    class Context
      @scr : Ultraviolet::Screen
      @style : Style
      @link : Link
      @pos : Position

      def initialize(@scr : Ultraviolet::Screen)
        @style = Style.new
        @link = Link.new
        @pos = Position.new(0, 0)
      end

      def reset : Nil
        @style = Style.new
        @link = Link.new
        @pos = Position.new(0, 0)
      end

      def set_style(style : Style) : Nil
        @style = style
      end

      def style=(style : Style) : Nil
        set_style(style)
      end

      def with_style(style : Style) : Context
        dup_ctx = copy
        dup_ctx.set_style(style)
        dup_ctx
      end

      def set_link(link : Link) : Nil
        @link = link
      end

      def link=(link : Link) : Nil
        set_link(link)
      end

      def with_link(link : Link) : Context
        dup_ctx = copy
        dup_ctx.set_link(link)
        dup_ctx
      end

      def set_attrs(attrs : Attr) : Nil
        @style.attrs = attrs
      end

      def attrs=(attrs : Attr) : Nil
        set_attrs(attrs)
      end

      def with_attrs(attrs : Attr) : Context
        dup_ctx = copy
        dup_ctx.set_attrs(attrs)
        dup_ctx
      end

      def set_background(bg : Color?) : Nil
        @style.bg = bg
      end

      def background=(bg : Color?) : Nil
        set_background(bg)
      end

      def with_background(bg : Color?) : Context
        dup_ctx = copy
        dup_ctx.set_background(bg)
        dup_ctx
      end

      def set_foreground(fg : Color?) : Nil
        @style.fg = fg
      end

      def foreground=(fg : Color?) : Nil
        set_foreground(fg)
      end

      def with_foreground(fg : Color?) : Context
        dup_ctx = copy
        dup_ctx.set_foreground(fg)
        dup_ctx
      end

      def set_bold(bold : Bool) : Nil
        @style.attrs = bold ? (@style.attrs | Attr::BOLD) : (@style.attrs & ~Attr::BOLD)
      end

      def bold=(bold : Bool) : Nil
        set_bold(bold)
      end

      def with_bold(bold : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_bold(bold)
        dup_ctx
      end

      def set_italic(italic : Bool) : Nil
        @style.attrs = italic ? (@style.attrs | Attr::ITALIC) : (@style.attrs & ~Attr::ITALIC)
      end

      def italic=(italic : Bool) : Nil
        set_italic(italic)
      end

      def with_italic(italic : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_italic(italic)
        dup_ctx
      end

      def set_strikethrough(strikethrough : Bool) : Nil
        @style.attrs = strikethrough ? (@style.attrs | Attr::STRIKETHROUGH) : (@style.attrs & ~Attr::STRIKETHROUGH)
      end

      def strikethrough=(strikethrough : Bool) : Nil
        set_strikethrough(strikethrough)
      end

      def with_strikethrough(strikethrough : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_strikethrough(strikethrough)
        dup_ctx
      end

      def set_faint(faint : Bool) : Nil
        @style.attrs = faint ? (@style.attrs | Attr::FAINT) : (@style.attrs & ~Attr::FAINT)
      end

      def faint=(faint : Bool) : Nil
        set_faint(faint)
      end

      def with_faint(faint : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_faint(faint)
        dup_ctx
      end

      def set_blink(blink : Bool) : Nil
        @style.attrs = blink ? (@style.attrs | Attr::BLINK) : (@style.attrs & ~Attr::BLINK)
      end

      def blink=(blink : Bool) : Nil
        set_blink(blink)
      end

      def with_blink(blink : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_blink(blink)
        dup_ctx
      end

      def set_reverse(reverse : Bool) : Nil
        @style.attrs = reverse ? (@style.attrs | Attr::REVERSE) : (@style.attrs & ~Attr::REVERSE)
      end

      def reverse=(reverse : Bool) : Nil
        set_reverse(reverse)
      end

      def with_reverse(reverse : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_reverse(reverse)
        dup_ctx
      end

      def set_conceal(conceal : Bool) : Nil
        @style.attrs = conceal ? (@style.attrs | Attr::CONCEAL) : (@style.attrs & ~Attr::CONCEAL)
      end

      def conceal=(conceal : Bool) : Nil
        set_conceal(conceal)
      end

      def with_conceal(conceal : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_conceal(conceal)
        dup_ctx
      end

      def set_underline_style(underline : Underline) : Nil
        @style.underline = underline
      end

      def underline_style=(underline : Underline) : Nil
        set_underline_style(underline)
      end

      def with_underline_style(underline : Underline) : Context
        dup_ctx = copy
        dup_ctx.set_underline_style(underline)
        dup_ctx
      end

      def set_underline(underline : Bool) : Nil
        set_underline_style(underline ? Underline::Single : Underline::None)
      end

      def underline=(underline : Bool) : Nil
        set_underline(underline)
      end

      def with_underline(underline : Bool) : Context
        dup_ctx = copy
        dup_ctx.set_underline(underline)
        dup_ctx
      end

      def set_underline_color(color : Color?) : Nil
        @style.underline_color = color
      end

      def underline_color=(color : Color?) : Nil
        set_underline_color(color)
      end

      def with_underline_color(color : Color?) : Context
        dup_ctx = copy
        dup_ctx.set_underline_color(color)
        dup_ctx
      end

      def set_url(url : String, params : Array(String) = [] of String) : Nil
        if url.empty?
          @link = Link.new
        else
          @link = Link.new(url, params.join(":"))
        end
      end

      def set_url(url : String, *params : String) : Nil
        set_url(url, params.to_a)
      end

      def with_url(url : String, params : Array(String) = [] of String) : Context
        dup_ctx = copy
        dup_ctx.set_url(url, params)
        dup_ctx
      end

      def with_url(url : String, *params : String) : Context
        with_url(url, params.to_a)
      end

      def position : {Int32, Int32}
        {@pos.x, @pos.y}
      end

      def set_position(x : Int32, y : Int32) : Nil
        move_to(x, y)
      end

      def with_position(x : Int32, y : Int32) : Context
        dup_ctx = copy
        dup_ctx.move_to(x, y)
        dup_ctx
      end

      def move_to(x : Int32, y : Int32) : Nil
        @pos = Position.new(x, y)
      end

      def print(*values) : Int32
        write_string(values.join)
      end

      def println(*values) : Int32
        write_string("#{values.join(" ")}\n")
      end

      def printf(format : String, *args) : Int32
        write_string(format % args)
      end

      def draw_string(value : String, x : Int32, y : Int32) : Nil
        draw_string_at(value, x, y, false)
      end

      def draw_string_wrapped(value : String, x : Int32, y : Int32) : Nil
        draw_string_at(value, x, y, true)
      end

      def write(bytes : Bytes) : Int32
        write_string(String.new(bytes))
      end

      def write_string(value : String) : Int32
        x, y = draw_string_at(value, @pos.x, @pos.y, true)
        @pos = Position.new(x, y)
        value.bytesize
      end

      private def copy : Context
        dup_ctx = Context.new(@scr)
        dup_ctx.set_style(@style)
        dup_ctx.set_link(@link)
        dup_ctx.move_to(@pos.x, @pos.y)
        dup_ctx
      end

      private def draw_string_at(value : String, x : Int32, y : Int32, wrap : Bool) : {Int32, Int32}
        bounds = @scr.bounds
        width = bounds.dx
        height = bounds.dy
        return {x, y} if x < 0 || y < 0 || x >= width || y >= height

        TextSegment.each_grapheme(value) do |cluster|
          grapheme = cluster.str
          if grapheme == "\n"
            x = 0
            y += 1
            next
          end

          w = @scr.width_method.call(grapheme)
          if x + w > width
            if wrap
              x = 0
              y += 1
            else
              break
            end
          end
          break if x < 0 || y < 0 || x >= width || y >= height

          @scr.set_cell(x, y, Cell.new(grapheme, w, @style, @link))
          x += w

          if wrap && x >= width
            x = 0
            y += 1
          end
        end

        {x, y}
      end
    end
  end
end
