#!/usr/bin/env bash
# Generate a candidate curated ledger for a new upstream baseline.
#
# The ledger at plans/inventory/go_port_inventory.tsv is hand-curated, so this
# wrapper writes a candidate under temp/ by default. Review the candidate
# against the curated ledger, migrate row by row, then delete temp/.
#
# Thin forwarding wrapper around the installed parity skill. Do not add parity
# logic here; see AGENTS.md ("Parity tooling").
#
# Usage: scripts/generate_go_port_inventory.sh [ROOT_DIR] [OUT] [SOURCE_PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=parity_skill_dir.sh
. "${SCRIPT_DIR}/parity_skill_dir.sh"
SKILL_DIR="$(parity_skill_dir)"

ROOT_DIR="${1:-$(pwd)}"
OUT="${2:-temp/go_port_inventory.candidate.tsv}"
SOURCE_PATH="${3:-vendor/ultraviolet}"

export PORT_PARSER="${PORT_PARSER:-regex}"

exec "${SKILL_DIR}/scripts/generate_port_inventory.sh" \
  "${ROOT_DIR}" "${OUT}" "${SOURCE_PATH}" go
