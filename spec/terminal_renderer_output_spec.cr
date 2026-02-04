require "./spec_helper"

module Ultraviolet
  describe "TerminalRenderer output" do
    it "matches output cases" do
      cases = [
        {
          "scroll to bottom in inline mode",
          ["ABC", "XXX"],
          [] of Bool,
          true,
          false,
          ["\rABC\r\n\n\n\n", "\e[4AXXX"],
        },
        {
          "scroll one line",
          [lorem_ipsum[0], lorem_ipsum[0][10..]],
          [true, true],
          false,
          true,
          {% if flag?(:win32) %}
            [
              "\e[H\e[2JLorem ipsu\r\nm dolor si\r\nt amet, co\r\nnsectetur\r\nadipiscin\e[?7lg\e[?7h",
              "\e[Hm dolor si\r\nt amet, co\r\nnsectetur\e[K\r\nadipiscing\r\n elit. Vi\e[?7lv\e[?7h",
            ]
          {% else %}
            [
              "\e[H\e[2JLorem ipsu\r\nm dolor si\r\nt amet, co\r\nnsectetur\r\nadipiscin\e[?7lg\e[?7h",
              "\r\n elit. Vi\e[?7lv\e[?7h",
            ]
          {% end %},
        },
        {
          "scroll two lines",
          [lorem_ipsum[0], lorem_ipsum[0][20..]],
          [true, true],
          false,
          true,
          {% if flag?(:win32) %}
            [
              "\e[H\e[2JLorem ipsu\r\nm dolor si\r\nt amet, co\r\nnsectetur\r\nadipiscin\e[?7lg\e[?7h",
              "\e[Ht amet, co\r\nnsectetur\e[K\r\nadipiscing\r\n elit. Viv\r\namus at o\e[?7lr\e[?7h",
            ]
          {% else %}
            [
              "\e[H\e[2JLorem ipsu\r\nm dolor si\r\nt amet, co\r\nnsectetur\r\nadipiscin\e[?7lg\e[?7h",
              "\r\e[2S\eM elit. Viv\r\namus at o\e[?7lr\e[?7h",
            ]
          {% end %},
        },
        {
          "insert line in the middle",
          ["ABC\nDEF\nGHI\n", "ABC\n\nDEF\nGHI"],
          [true, true],
          false,
          true,
          {% if flag?(:win32) %}
            [
              "\e[H\e[2JABC\r\nDEF\r\nGHI",
              "\r\eM\e[K\nDEF\r\nGHI",
            ]
          {% else %}
            [
              "\e[H\e[2JABC\r\nDEF\r\nGHI",
              "\r\eM\e[L",
            ]
          {% end %},
        },
        {
          "erase until end of line",
          ["\nABCEFGHIJK", "\nABCE      "],
          [] of Bool,
          false,
          false,
          [
            "\e[2;1HABCEFGHIJK\r\n\n\n",
            "\e[2;5H\e[K",
          ],
        },
      ]

      cases.each do |entry|
        _name, input, wrap, relative, altscreen, expected = entry
        buf = IO::Memory.new
        renderer = TerminalRenderer.new(buf, ["TERM=xterm-256color", "COLORTERM=truecolor"])

        renderer.scroll_optim = {% if flag?(:win32) %} false {% else %} true {% end %}
        renderer.fullscreen = altscreen
        renderer.relative_cursor = relative
        if altscreen
          renderer.save_cursor
          renderer.erase
        end

        scr = ScreenBuffer.new(10, 5)
        input.each_with_index do |frame, idx|
          buf.clear
          comp = StyledString.new(frame)
          comp.wrap = wrap[idx]? || false
          comp.draw(scr, scr.bounds)
          renderer.render(scr)
          renderer.flush

          buf.to_s.should eq(expected[idx])
        end
      end
    end
  end

  private def self.lorem_ipsum : Array(String)
    [
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus at ornare risus, quis lacinia magna. Suspendisse egestas purus risus, id rutrum diam porta non. Duis luctus tempus dictum. Maecenas luctus metus vitae nulla consectetur egestas. Curabitur faucibus nunc vel eros semper scelerisque. Proin dictum aliquam lacus dignissim fringilla. Praesent ut quam id dui aliquam vehicula in vitae orci. Fusce imperdiet aliquam quam. Nullam euismod magna tincidunt nisl ullamcorper, dignissim rutrum arcu rutrum. Nulla ac fringilla velit. Duis non pellentesque erat.",
      "In egestas ex et sem vulputate, congue bibendum diam ultrices. Nam auctor dictum enim, in rutrum nulla vestibulum sit amet. Vestibulum vel velit ac sem pellentesque accumsan. Vivamus pharetra mi non arcu tristique gravida. Interdum et malesuada fames ac ante ipsum primis in faucibus. Sed molestie lectus nunc, sit amet rhoncus orci laoreet vel. Nulla eget mattis massa. Nunc porta eros sollicitudin lorem dapibus luctus. Vestibulum ut turpis ut nibh tincidunt feugiat. Integer eget augue nunc. Morbi vitae ultrices neque. Nulla et convallis libero. Cras nec faucibus odio. Maecenas lacinia sed odio sit amet ultrices.",
      "Nunc at molestie massa. Phasellus commodo dui odio, quis pulvinar orci eleifend a. In et erat nec nisl auctor facilisis at at orci. Curabitur ut ligula in ipsum consequat consectetur. Suspendisse pulvinar arcu metus, et faucibus risus interdum pharetra. Vestibulum vulputate, arcu at malesuada varius, nisl turpis molestie risus, ut lobortis dolor neque vitae diam. Donec lectus libero, iaculis non diam sit amet, sagittis mattis lectus. Vestibulum a magna molestie neque molestie faucibus sagittis et ante. Etiam porta tincidunt nisi sit amet blandit. Vivamus et tellus diam. Vivamus id dolor placerat, tristique magna non, congue est. Nulla a condimentum nulla. Fusce maximus semper nunc, at bibendum mi. Nam malesuada vitae mi molestie tincidunt. Pellentesque sed vestibulum lectus, eu ultrices ligula. Phasellus id nibh tristique, ultricies diam vel, cursus odio.",
      "Integer sed mi viverra, convallis urna congue, efficitur libero. Duis non eros commodo, ultricies quam hendrerit, molestie velit. Nunc non eros vitae lectus hendrerit gravida. Nunc lacinia neque sapien, et accumsan orci elementum vel. Praesent vel interdum nisl. Duis eget diam turpis. Nunc gravida, lacus dictum congue pharetra, dui est laoreet massa, ac convallis elit est sed dui. Morbi luctus convallis dui id tristique.",
      "Praesent vitae laoreet risus. Sed ac facilisis justo. Morbi fringilla in est vel volutpat. Aliquam erat tortor, posuere ac libero sit amet, vehicula blandit sapien. Nullam feugiat purus eget sapien bibendum, id posuere risus finibus. Aliquam erat volutpat. Pellentesque ac purus accumsan, accumsan mi vel, viverra lectus. Ut sed porta erat, vitae mollis nibh. Nunc dignissim quis tellus sed blandit. Mauris id velit in odio commodo aliquet.",
    ]
  end
end
