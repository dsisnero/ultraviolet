#!/usr/bin/env bash
# Resolve the canonical cross-language-crystal-parity skill directory.
#
# The parity gates in this repo forward to the installed skill's scripts. They
# are deliberately NOT copied here: copies drift, keep stale parser backends,
# and report passes the canonical scripts would fail.
#
# Override the location with PARITY_SKILL_DIR when the skill lives elsewhere.
set -euo pipefail

parity_skill_dir() {
  local default_dir="${HOME}/.agents/skills/crystal_forge/skills/cross-language-crystal-parity"
  local dir="${PARITY_SKILL_DIR:-${default_dir}}"

  if [[ ! -x "${dir}/scripts/check_port_inventory.sh" ]]; then
    echo "Parity skill scripts not found at: ${dir}" >&2
    echo "Install the crystal_forge cross-language-crystal-parity skill or set PARITY_SKILL_DIR." >&2
    return 2
  fi

  printf '%s\n' "${dir}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  parity_skill_dir
fi
