#!/usr/bin/env bash
# Generated test-parity manifest gate (196 Go tests).
#
# Thin forwarding wrapper around the installed parity skill. Do not add parity
# logic here; see AGENTS.md ("Parity tooling").
#
# Usage: scripts/check_go_test_parity.sh [ROOT_DIR] [MANIFEST] [SOURCE_PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=parity_skill_dir.sh
. "${SCRIPT_DIR}/parity_skill_dir.sh"
SKILL_DIR="$(parity_skill_dir)"

ROOT_DIR="${1:-$(pwd)}"
MANIFEST="${2:-plans/inventory/go_test_parity.tsv}"
SOURCE_PATH="${3:-vendor/ultraviolet}"

export PORT_PARSER="${PORT_PARSER:-regex}"

exec "${SKILL_DIR}/scripts/check_test_parity.sh" \
  "${ROOT_DIR}" "${MANIFEST}" "${SOURCE_PATH}" go
