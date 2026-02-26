require "./spec_helper"

describe Ultraviolet::Console do
  it "uses last matching environment value" do
    con = Ultraviolet::Console.new_console(
      IO::Memory.new,
      IO::Memory.new,
      ["TERM=dumb", "TERM=xterm-256color", "LANG=en_US.UTF-8"]
    )

    con.getenv("TERM").should eq("xterm-256color")
    con.lookup_env("TERM").should eq({"xterm-256color", true})
    con.lookup_env("MISSING").should eq({"", false})
  end

  it "reads and writes through configured streams" do
    input = IO::Memory.new("abcdef")
    output = IO::Memory.new
    con = Ultraviolet::Console.new_console(input, output, [] of String)

    buf = Bytes.new(3)
    con.read(buf).should eq(3)
    String.new(buf).should eq("abc")

    payload = "hello".to_slice
    con.write(payload).should eq(5)
    output.to_s.should eq("hello")
  end

  it "returns not-terminal for raw mode on non-tty streams" do
    con = Ultraviolet::Console.new_console(IO::Memory.new, IO::Memory.new, [] of String)

    expect_raises(Exception, "not a terminal") do
      con.make_raw
    end
  end

  it "returns not-terminal for size on non-tty streams" do
    con = Ultraviolet::Console.new_console(IO::Memory.new, IO::Memory.new, [] of String)

    expect_raises(Exception, "not a terminal") do
      con.get_size
    end
  end

  it "builds platform-specific console wrappers" do
    con = Ultraviolet::Console.default

    {% if flag?(:win32) %}
      con.should be_a(Ultraviolet::WinCon)
    {% else %}
      con.should be_a(Ultraviolet::TTY)
    {% end %}
  end
end
