#!/usr/bin/env bash
# Adversarial parity signoff: re-derive the ledgers, then prove the gates can
# fail (no false green from stale manifests).
#
# Thin forwarding wrapper around the installed parity skill. Do not add parity
# logic here; see AGENTS.md ("Parity tooling").
#
# Usage: scripts/verify_parity_adversarial.sh [ROOT_DIR] [SOURCE_PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=parity_skill_dir.sh
. "${SCRIPT_DIR}/parity_skill_dir.sh"
SKILL_DIR="$(parity_skill_dir)"

ROOT_DIR="${1:-$(pwd)}"
SOURCE_PATH="${2:-vendor/ultraviolet}"

export PORT_PARSER="${PORT_PARSER:-regex}"

exec "${SKILL_DIR}/scripts/verify_parity_adversarial.sh" \
  "${ROOT_DIR}" "${SOURCE_PATH}" go 'crystal spec' 'go test ./...'
