# Snapshot harness for examples/: captures each example's first frame and
# compares it with a committed golden file.
#
# Run through `make snapshot-examples` (verify) or `make snapshot-update`
# (regenerate). Comparison and updating are handled by the `golden` shard,
# configured by `.golden.yml` at the repository root.
#
# These goldens are a *regression* check: they pin this port's current output so
# a change shows up as a diff. `scripts/parity_examples.cr` is the other half —
# it compares the same capture against the vendored Go example.
require "golden"
require "./support/pty_capture"

module SnapshotExamples
  extend self

  ROOT         = File.expand_path("..", __DIR__)
  EXAMPLES_DIR = File.join(ROOT, "examples")

  # Examples whose first frame is not a function of the program alone. They are
  # reported as skipped rather than snapshotted with a masked colour or a frozen
  # clock, because masking the thing the example exists to show is worse than
  # not snapshotting it.
  SKIP = {
    "space"       => "animates from the wall clock",
    "prependline" => "random background colour per frame",
  }

  def binaries : Array(String)
    Dir.glob(File.join(EXAMPLES_DIR, "*"))
      .reject { |path| !File.extname(path).empty? || File.basename(path).starts_with?("._") }
      .select { |path| File.file?(path) && File::Info.executable?(path) }
      .sort
  end

  def run : Int32
    Golden.auto_configure!(ROOT)
    Golden.init
    # Verify unless GOLDEN_UPDATE=1 asked for regeneration: the shard's default
    # "auto" mode writes .new files outside CI, which is wrong for a make target.
    Golden.settings.update_mode = Golden::UpdateMode::No unless Golden.update?

    failures = 0
    binaries.each do |binary|
      name = File.basename(binary)
      if reason = SKIP[name]?
        puts "skip    #{name} (#{reason})"
        next
      end
      begin
        Golden.require_equal("examples/#{name}", PtyCapture.capture_example(binary, name))
        puts "ok      #{name}"
      rescue ex
        failures += 1
        puts "FAILED  #{name}"
        puts ex.message.to_s.lines.first(12).map { |line| "        #{line}" }.join("\n")
      end
    end

    if Golden.update?
      # The shard writes a .meta sidecar (name + timestamp) next to every
      # snapshot. Nothing reads it and its timestamp changes on each run.
      Dir.glob(File.join(ROOT, "spec/testdata/**/*.golden.meta")).each { |path| File.delete(path) }
    end

    failures
  end
end

exit(SnapshotExamples.run == 0 ? 0 : 1)
