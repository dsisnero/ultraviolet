# This file provides stub implementations for non-Windows platforms
# (matching Go's terminal_reader_other.go build tag: !windows).
# The actual implementation is in terminal_reader.cr.
{% unless flag?(:win32) %}
  # No additional methods needed beyond those in terminal_reader.cr
{% end %}
