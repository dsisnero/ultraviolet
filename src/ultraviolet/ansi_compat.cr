require "ansi"

# Compatibility layer for ANSI constants not present in the ansi shard.
module Ansi
  # Kitty keyboard enhancement flags.
  KittyDisambiguateEscapeCodes    = 1 << 0
  KittyReportEventTypes           = 1 << 1
  KittyReportAlternateKeys        = 1 << 2
  KittyReportAllKeysAsEscapeCodes = 1 << 3
  KittyReportAssociatedText       = 1 << 4
end
