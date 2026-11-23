require "./spec_helper"

# Robustness against the vendored conformance fuzz seeds.
#
# These files are arbitrary byte strings: upstream feeds them to its *renderer
# program* decoder, not to `EventDecoder`, so this is not a parity assertion on
# event types. It pins the weaker property the seeds can actually prove here:
# our decoder terminates deterministically on the same hostile inputs and never
# raises, however partial or malformed the sequence is.
module FuzzSeedHelper
  FUZZ_DIR = File.expand_path("../vendor/ultraviolet/internal/conformance/testdata/fuzz", __DIR__)

  def self.seeds : Array({String, Bytes})
    Dir.glob(File.join(FUZZ_DIR, "*", "*")).sort.compact_map do |path|
      literal = File.read_lines(path).find(&.starts_with?("[]byte(")) || next
      quoted = literal.strip.lchop("[]byte(").rchop(")")
      {path, unquote_go(quoted)}
    end
  end

  # strconv.Unquote for the escape forms these seeds use.
  private def self.unquote_go(quoted : String) : Bytes
    raise "not a quoted Go string: #{quoted}" unless quoted.starts_with?('"') && quoted.ends_with?('"')

    body = quoted[1, quoted.bytesize - 2]
    out = IO::Memory.new
    index = 0
    while index < body.bytesize
      byte = body.to_slice[index]
      if byte == '\\'.ord
        index += 1
        case body[index]
        when 'x'
          out.write_byte(body[index + 1, 2].hexbytes[0])
          index += 2
        when 'n'  then out.write_byte(0x0a_u8)
        when 'r'  then out.write_byte(0x0d_u8)
        when 't'  then out.write_byte(0x09_u8)
        when '\\' then out.write_byte(0x5c_u8)
        when '"'  then out.write_byte(0x22_u8)
        else
          raise "unhandled Go escape \\#{body[index]} in #{quoted}"
        end
      else
        out.write_byte(byte)
      end
      index += 1
    end
    out.to_slice
  end

  # Runs the decoder the way an input loop would, with a bound so a decoder that
  # stops making progress fails instead of hanging the suite.
  def self.decode_until_done(input : Bytes) : Int32
    decoder = Ultraviolet::EventDecoder.new
    buffer = input
    steps = 0
    while !buffer.empty? && steps < 10_000
      n, _event = decoder.decode(buffer)
      break if n <= 0
      buffer = buffer[n..]
      steps += 1
    end
    steps
  end
end

describe "Decoder on vendored fuzz seeds" do
  it "has the upstream seeds available" do
    FuzzSeedHelper.seeds.size.should be > 0
  end

  it "consumes or rejects every seed without raising" do
    FuzzSeedHelper.seeds.each do |path, data|
      steps = FuzzSeedHelper.decode_until_done(data)
      steps.should be <= 10_000, "decoder did not terminate on #{File.basename(path)}"
    end
  end

  it "decodes the same seed the same way twice" do
    _, data = FuzzSeedHelper.seeds.first
    first = FuzzSeedHelper.decode_until_done(data)
    second = FuzzSeedHelper.decode_until_done(data)
    first.should eq(second)
  end
end
