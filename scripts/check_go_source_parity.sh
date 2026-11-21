#!/usr/bin/env bash
# Generated source-parity manifest gate (819 Go APIs).
#
# Thin forwarding wrapper around the installed parity skill. Do not add parity
# logic here; see AGENTS.md ("Parity tooling").
#
# Usage: scripts/check_go_source_parity.sh [ROOT_DIR] [MANIFEST] [SOURCE_PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=parity_skill_dir.sh
. "${SCRIPT_DIR}/parity_skill_dir.sh"
SKILL_DIR="$(parity_skill_dir)"

ROOT_DIR="${1:-$(pwd)}"
MANIFEST="${2:-plans/inventory/go_source_parity.tsv}"
SOURCE_PATH="${3:-vendor/ultraviolet}"

export PORT_PARSER="${PORT_PARSER:-regex}"

exec "${SKILL_DIR}/scripts/check_source_parity.sh" \
  "${ROOT_DIR}" "${MANIFEST}" "${SOURCE_PATH}" go
