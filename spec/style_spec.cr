require "./spec_helper"

describe Ultraviolet::Style do
  def color(r : Int32, g : Int32, b : Int32) : Ultraviolet::Color
    Ultraviolet::Color.new(r.to_u8, g.to_u8, b.to_u8)
  end

  it "converts styles and links by color profile" do
    black = color(0, 0, 0)
    white = color(255, 255, 255)
    style = Ultraviolet::Style.new(fg: black, bg: white, underline_color: black)

    Ultraviolet.convert_style(style, Ultraviolet::ColorProfile::TrueColor).should eq(style)

    ansi256 = Ultraviolet.convert_style(style, Ultraviolet::ColorProfile::ANSI256)
    ansi256.fg.should eq(black)
    ansi256.bg.should eq(white)
    ansi256.underline_color.should eq(black)

    ansi = Ultraviolet.convert_style(style, Ultraviolet::ColorProfile::ANSI)
    ansi.fg.should eq(black)
    ansi.bg.should eq(white)
    ansi.underline_color.should eq(black)

    ascii = Ultraviolet.convert_style(style, Ultraviolet::ColorProfile::Ascii)
    ascii.fg.should be_nil
    ascii.bg.should be_nil
    ascii.underline_color.should be_nil

    Ultraviolet.convert_style(style, Ultraviolet::ColorProfile::NoTTY).should eq(Ultraviolet::Style.new)

    link = Ultraviolet::Link.new("https://example.com", "id=1")
    Ultraviolet.convert_link(link, Ultraviolet::ColorProfile::TrueColor).should eq(link)
    Ultraviolet.convert_link(link, Ultraviolet::ColorProfile::NoTTY).should eq(Ultraviolet::Link.new)
  end

  it "matches StyleDiff behavior from Go" do
    red = color(255, 0, 0)
    blue = color(0, 0, 255)
    green = color(0, 255, 0)
    yellow = color(255, 255, 0)
    cyan = color(0, 255, 255)
    magenta = color(255, 0, 255)

    tests = [
      {name: "both nil", from: nil, to: nil, want: ""},
      {name: "from nil to zero", from: nil, to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "from zero to zero", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new, want: ""},
      {
        name: "from nil to styled",
        from: nil,
        to:   Ultraviolet::Style.new(fg: red, attrs: Ultraviolet::Attr::BOLD),
        want: "\e[1;38;2;255;0;0m",
      },
      {
        name: "foreground color change",
        from: Ultraviolet::Style.new(fg: red),
        to:   Ultraviolet::Style.new(fg: blue),
        want: "\e[38;2;0;0;255m",
      },
      {
        name: "add foreground color",
        from: Ultraviolet::Style.new,
        to:   Ultraviolet::Style.new(fg: red),
        want: "\e[38;2;255;0;0m",
      },
      {
        name: "remove foreground color",
        from: Ultraviolet::Style.new(fg: red),
        to:   Ultraviolet::Style.new,
        want: "\e[m",
      },
      {
        name: "foreground color same",
        from: Ultraviolet::Style.new(fg: red),
        to:   Ultraviolet::Style.new(fg: red),
        want: "",
      },
      {
        name: "background color change",
        from: Ultraviolet::Style.new(bg: red),
        to:   Ultraviolet::Style.new(bg: blue),
        want: "\e[48;2;0;0;255m",
      },
      {
        name: "add background color",
        from: Ultraviolet::Style.new,
        to:   Ultraviolet::Style.new(bg: blue),
        want: "\e[48;2;0;0;255m",
      },
      {
        name: "remove background color",
        from: Ultraviolet::Style.new(bg: blue),
        to:   Ultraviolet::Style.new,
        want: "\e[m",
      },
      {
        name: "background color same",
        from: Ultraviolet::Style.new(bg: blue),
        to:   Ultraviolet::Style.new(bg: blue),
        want: "",
      },
      {
        name: "underline color change",
        from: Ultraviolet::Style.new(underline_color: red, underline: Ultraviolet::Underline::Single),
        to:   Ultraviolet::Style.new(underline_color: blue, underline: Ultraviolet::Underline::Single),
        want: "\e[58;2;0;0;255m",
      },
      {
        name: "add underline color",
        from: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single),
        to:   Ultraviolet::Style.new(underline_color: green, underline: Ultraviolet::Underline::Single),
        want: "\e[58;2;0;255;0m",
      },
      {
        name: "remove underline color",
        from: Ultraviolet::Style.new(underline_color: green, underline: Ultraviolet::Underline::Single),
        to:   Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single),
        want: "\e[59m",
      },
      {
        name: "underline color same",
        from: Ultraviolet::Style.new(underline_color: green, underline: Ultraviolet::Underline::Single),
        to:   Ultraviolet::Style.new(underline_color: green, underline: Ultraviolet::Underline::Single),
        want: "",
      },
      {name: "add bold", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD), want: "\e[1m"},
      {name: "remove bold", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep bold", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD), want: ""},
      {name: "add faint", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT), want: "\e[2m"},
      {name: "remove faint", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep faint", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT), want: ""},
      {
        name: "bold to faint",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT),
        want: "\e[22;2m",
      },
      {
        name: "faint to bold",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        want: "\e[22;1m",
      },
      {
        name: "bold and faint to bold",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        want: "\e[22;1m",
      },
      {
        name: "bold to bold and faint",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT),
        want: "\e[2m",
      },
      {name: "add italic", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC), want: "\e[3m"},
      {name: "remove italic", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep italic", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC), want: ""},
      {
        name: "bold to bold and italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC),
        want: "\e[3m",
      },
      {
        name: "bold and italic to bold",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        want: "\e[23m",
      },
      {
        name: "bold and faint to italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC),
        want: "\e[22;3m",
      },
      {
        name: "italic to bold and faint",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT),
        want: "\e[23;1;2m",
      },
      {
        name: "bold, faint, and italic to bold",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        want: "\e[22;23;1m",
      },
      {
        name: "bold to bold, faint, and italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        want: "\e[2;3m",
      },
      {
        name: "faint to bold and italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC),
        want: "\e[22;1;3m",
      },
      {
        name: "italic to bold and faint",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT),
        want: "\e[23;1;2m",
      },
      {
        name: "bold, faint, and italic to faint",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT),
        want: "\e[22;23;2m",
      },
      {
        name: "bold, faint, and italic to italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC),
        want: "\e[22m",
      },
      {
        name: "faint to bold, faint, and italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::FAINT),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        want: "\e[1;3m",
      },
      {
        name: "italic to bold, faint, and italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        want: "\e[1;2m",
      },
      {
        name: "bold, faint, and italic to bold, faint, and italic",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        want: "",
      },
      {
        name: "no attributes to bold, faint, and italic",
        from: Ultraviolet::Style.new,
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC),
        want: "\e[1;2;3m",
      },
      {name: "add slow blink", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK), want: "\e[5m"},
      {name: "remove slow blink", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep slow blink", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK), want: ""},
      {name: "add rapid blink", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::RAPID_BLINK), want: "\e[6m"},
      {name: "remove rapid blink", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::RAPID_BLINK), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep rapid blink", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::RAPID_BLINK), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::RAPID_BLINK), want: ""},
      {
        name: "change from slow to rapid blink",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::RAPID_BLINK),
        want: "\e[25;6m",
      },
      {
        name: "change from rapid to slow blink",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::RAPID_BLINK),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK),
        want: "\e[25;5m",
      },
      {
        name: "slow and rapid blink to slow blink",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK | Ultraviolet::Attr::RAPID_BLINK),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BLINK),
        want: "\e[25;5m",
      },
      {name: "add reverse", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::REVERSE), want: "\e[7m"},
      {name: "remove reverse", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::REVERSE), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep reverse", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::REVERSE), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::REVERSE), want: ""},
      {name: "add conceal", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::CONCEAL), want: "\e[8m"},
      {name: "remove conceal", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::CONCEAL), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep conceal", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::CONCEAL), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::CONCEAL), want: ""},
      {name: "add strikethrough", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::STRIKETHROUGH), want: "\e[9m"},
      {name: "remove strikethrough", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::STRIKETHROUGH), to: Ultraviolet::Style.new, want: "\e[m"},
      {name: "keep strikethrough", from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::STRIKETHROUGH), to: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::STRIKETHROUGH), want: ""},
      {name: "add single underline", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single), want: "\e[4m"},
      {name: "add double underline", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double), want: "\e[4:2m"},
      {name: "add curly underline", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Curly), want: "\e[4:3m"},
      {name: "add dotted underline", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dotted), want: "\e[4:4m"},
      {name: "add dashed underline", from: Ultraviolet::Style.new, to: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Dashed), want: "\e[4:5m"},
      {
        name: "change underline style single to double",
        from: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single),
        to:   Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double),
        want: "\e[4:2m",
      },
      {
        name: "change underline style double to curly",
        from: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Double),
        to:   Ultraviolet::Style.new(underline: Ultraviolet::Underline::Curly),
        want: "\e[4:3m",
      },
      {
        name: "remove underline",
        from: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single),
        to:   Ultraviolet::Style.new,
        want: "\e[m",
      },
      {
        name: "keep underline style",
        from: Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single),
        to:   Ultraviolet::Style.new(underline: Ultraviolet::Underline::Single),
        want: "",
      },
      {
        name: "add multiple attributes",
        from: Ultraviolet::Style.new,
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC, underline: Ultraviolet::Underline::Single),
        want: "\e[1;3;4m",
      },
      {
        name: "remove multiple attributes",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC | Ultraviolet::Attr::REVERSE),
        to:   Ultraviolet::Style.new,
        want: "\e[m",
      },
      {
        name: "combine multiple attribute changes",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::REVERSE),
        want: "\e[23;7m",
      },
      {
        name: "swap italic and strikethrough",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::ITALIC),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::STRIKETHROUGH),
        want: "\e[23;9m",
      },
      {
        name: "all attributes added",
        from: Ultraviolet::Style.new,
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC | Ultraviolet::Attr::BLINK | Ultraviolet::Attr::RAPID_BLINK | Ultraviolet::Attr::REVERSE | Ultraviolet::Attr::CONCEAL | Ultraviolet::Attr::STRIKETHROUGH),
        want: "\e[1;2;3;5;6;7;8;9m",
      },
      {
        name: "all attributes removed",
        from: Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::FAINT | Ultraviolet::Attr::ITALIC | Ultraviolet::Attr::BLINK | Ultraviolet::Attr::RAPID_BLINK | Ultraviolet::Attr::REVERSE | Ultraviolet::Attr::CONCEAL | Ultraviolet::Attr::STRIKETHROUGH),
        to:   Ultraviolet::Style.new,
        want: "\e[m",
      },
      {
        name: "complex style change with all properties",
        from: Ultraviolet::Style.new(fg: red, bg: blue, attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(
          fg: green,
          bg: yellow,
          underline_color: cyan,
          attrs: Ultraviolet::Attr::ITALIC,
          underline: Ultraviolet::Underline::Single,
        ),
        want: "\e[38;2;0;255;0;48;2;255;255;0;58;2;0;255;255;22;3;4m",
      },
      {
        name: "complex change keeping some properties",
        from: Ultraviolet::Style.new(
          fg: red,
          bg: blue,
          attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC,
          underline: Ultraviolet::Underline::Single,
        ),
        to: Ultraviolet::Style.new(
          fg: red,
          bg: green,
          attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::REVERSE,
          underline: Ultraviolet::Underline::Double,
        ),
        want: "\e[48;2;0;255;0;23;7;4:2m",
      },
      {
        name: "complete style reset",
        from: Ultraviolet::Style.new(
          fg: red,
          bg: blue,
          underline_color: green,
          attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC | Ultraviolet::Attr::REVERSE,
          underline: Ultraviolet::Underline::Single,
        ),
        to:   Ultraviolet::Style.new,
        want: "\e[m",
      },
      {
        name: "no changes with all properties",
        from: Ultraviolet::Style.new(
          fg: red,
          bg: blue,
          underline_color: green,
          attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC,
          underline: Ultraviolet::Underline::Single,
        ),
        to: Ultraviolet::Style.new(
          fg: red,
          bg: blue,
          underline_color: green,
          attrs: Ultraviolet::Attr::BOLD | Ultraviolet::Attr::ITALIC,
          underline: Ultraviolet::Underline::Single,
        ),
        want: "",
      },
      {
        name: "only colors change",
        from: Ultraviolet::Style.new(fg: red, bg: blue, attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(fg: green, bg: yellow, attrs: Ultraviolet::Attr::BOLD),
        want: "\e[38;2;0;255;0;48;2;255;255;0m",
      },
      {
        name: "only attributes change",
        from: Ultraviolet::Style.new(fg: red, attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(fg: red, attrs: Ultraviolet::Attr::ITALIC),
        want: "\e[22;3m",
      },
      {
        name: "add all colors",
        from: Ultraviolet::Style.new,
        to:   Ultraviolet::Style.new(
          fg: red,
          bg: blue,
          underline_color: green,
          underline: Ultraviolet::Underline::Single,
        ),
        want: "\e[38;2;255;0;0;48;2;0;0;255;58;2;0;255;0;4m",
      },
      {
        name: "add all colors without underline",
        from: Ultraviolet::Style.new,
        to:   Ultraviolet::Style.new(fg: red, bg: blue, underline_color: green),
        want: "\e[38;2;255;0;0;48;2;0;0;255;58;2;0;255;0m",
      },
      {
        name: "remove all colors with attributes",
        from: Ultraviolet::Style.new(fg: red, bg: blue, attrs: Ultraviolet::Attr::BOLD),
        to:   Ultraviolet::Style.new(attrs: Ultraviolet::Attr::BOLD),
        want: "\e[39;49m",
      },
      {
        name: "change all colors",
        from: Ultraviolet::Style.new(fg: red, bg: blue, underline_color: green),
        to:   Ultraviolet::Style.new(fg: cyan, bg: magenta, underline_color: yellow),
        want: "\e[38;2;0;255;255;48;2;255;0;255;58;2;255;255;0m",
      },
    ]

    tests.each do |test_case|
      got = Ultraviolet::Style.diff(test_case[:from], test_case[:to])
      got.should eq(test_case[:want]), test_case[:name]
    end
  end
end
