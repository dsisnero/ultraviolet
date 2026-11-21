# Type-check the Windows console reader layer for the Windows target.
#
# macOS/Linux cannot require "c/consoleapi", so a normal `crystal build` skips
# every `{% if flag?(:win32) %}` file. This driver is compiled with
# `--target x86_64-windows-msvc --no-codegen`, which runs the full semantic
# analysis against the Windows stdlib without linking or executing anything.
#
# Run it through scripts/check_win32.sh (or `make check-win32`).
require "../src/ultraviolet/cancelreader"
require "../src/ultraviolet/cancel_event_lifetime"
require "../src/ultraviolet/win32_api"
require "../src/ultraviolet/cancelreader_windows"
require "../src/ultraviolet/terminal_reader_windows"
