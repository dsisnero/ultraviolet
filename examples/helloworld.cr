require "../src/ultraviolet"

env = ENV.map { |key, value| "#{key}=#{value}" }
term = Ultraviolet::Terminal.new(STDIN, STDOUT, env)
term.start
term.enter_alt_screen

loop do
  event = term.events.receive
  case event
  when Ultraviolet::WindowSizeEvent
    term.resize(event.width, event.height)
    term.erase
  when Ultraviolet::Key
    break if event.match_string("q", "ctrl+c")
  end

  "Hello, World!".each_char_with_index do |char, idx|
    term.set_cell(idx, 0, Ultraviolet::Cell.new(char.to_s, 1))
  end
  term.display
end

term.shutdown(1.second)
