#!/usr/bin/env bash
# Type-check the Win32 console reader layer (cancel reader + terminal reader)
# for the Windows target.
#
# The win32 files are `{% if flag?(:win32) %}`-gated, so the macOS/Linux gates
# never look at them. Cross-target `--no-codegen` runs the full semantic
# analysis against the Windows stdlib: it catches duplicate LibC constants,
# conflicting signatures, and bad require paths without needing a Windows host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET="${WIN32_TARGET:-x86_64-windows-msvc}"

cd "${ROOT_DIR}"

echo "Checking Win32 console readers for ${TARGET}"
crystal build --no-codegen --cross-compile --target "${TARGET}" \
  "${SCRIPT_DIR}/win32_readers_check.cr"
echo "Win32 reader layer type-checks"
