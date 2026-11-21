#!/usr/bin/env bash
# Regenerate plans/inventory/go_source_parity.tsv for a new upstream baseline.
#
# Only run this for an intentional vendor refresh; the manifest is generated
# output and the curated ledger is the artifact that carries porting decisions.
#
# Thin forwarding wrapper around the installed parity skill. Do not add parity
# logic here; see AGENTS.md ("Parity tooling").
#
# Usage: scripts/generate_go_source_parity_manifest.sh [ROOT_DIR] [OUT] [SOURCE_PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=parity_skill_dir.sh
. "${SCRIPT_DIR}/parity_skill_dir.sh"
SKILL_DIR="$(parity_skill_dir)"

ROOT_DIR="${1:-$(pwd)}"
OUT="${2:-plans/inventory/go_source_parity.tsv}"
SOURCE_PATH="${3:-vendor/ultraviolet}"

export PORT_PARSER="${PORT_PARSER:-regex}"
export PORT_FORCE_OVERWRITE="${PORT_FORCE_OVERWRITE:-1}"

exec "${SKILL_DIR}/scripts/generate_source_parity_manifest.sh" \
  "${ROOT_DIR}" "${OUT}" "${SOURCE_PATH}" go
