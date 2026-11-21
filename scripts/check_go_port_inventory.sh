#!/usr/bin/env bash
# Curated ledger gate: every Go symbol in the pinned snapshot must have a row,
# and every crystal_refs entry must point at a file that still exists.
#
# Thin forwarding wrapper around the installed parity skill. Do not add parity
# logic here; see AGENTS.md ("Parity tooling").
#
# Usage: scripts/check_go_port_inventory.sh [ROOT_DIR] [MANIFEST] [SOURCE_PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=parity_skill_dir.sh
. "${SCRIPT_DIR}/parity_skill_dir.sh"
SKILL_DIR="$(parity_skill_dir)"

ROOT_DIR="${1:-$(pwd)}"
MANIFEST="${2:-plans/inventory/go_port_inventory.tsv}"
SOURCE_PATH="${3:-vendor/ultraviolet}"

# The ledger was curated with the regex vocabulary; pin it so `auto` cannot
# silently switch backends underneath it.
export PORT_PARSER="${PORT_PARSER:-regex}"

exec "${SKILL_DIR}/scripts/check_port_inventory.sh" \
  "${ROOT_DIR}" "${MANIFEST}" "${SOURCE_PATH}" go
