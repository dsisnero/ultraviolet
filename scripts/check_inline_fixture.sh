#!/usr/bin/env bash
# Reproduce the bubbletea.cr inline-fixture failure against this checkout.
#
# The sibling resolves ultraviolet from its own lib/, so temporarily swap that
# directory for this repository's src/shard.yml, run the fixture, and restore on
# exit. The sibling's git state and lockfile are not modified.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUBBLE_DIR="${BUBBLE_DIR:-${ROOT_DIR}/../bubbletea.cr}"
SPEC="${SPEC:-spec/parity/v2_control_sequences_spec.cr}"

if [[ ! -f "${BUBBLE_DIR}/shard.yml" ]]; then
  echo "error: bubbletea checkout not found at ${BUBBLE_DIR}" >&2
  echo "       set BUBBLE_DIR=/path/to/bubbletea.cr" >&2
  exit 1
fi
if [[ ! -d "${BUBBLE_DIR}/lib/ultraviolet" ]]; then
  echo "error: ${BUBBLE_DIR}/lib/ultraviolet is missing; run shards install there" >&2
  exit 1
fi

backup="$(mktemp -d "${TMPDIR:-/tmp}/uv-bubbletea-lib.XXXXXX")"
mv "${BUBBLE_DIR}/lib/ultraviolet" "${backup}/ultraviolet"
restore() {
  rm -rf "${BUBBLE_DIR}/lib/ultraviolet"
  mv "${backup}/ultraviolet" "${BUBBLE_DIR}/lib/ultraviolet"
  rmdir "${backup}" 2>/dev/null || true
}
trap restore EXIT

mkdir -p "${BUBBLE_DIR}/lib/ultraviolet"
cp -R "${ROOT_DIR}/src" "${BUBBLE_DIR}/lib/ultraviolet/src"
cp "${ROOT_DIR}/shard.yml" "${BUBBLE_DIR}/lib/ultraviolet/shard.yml"

cd "${BUBBLE_DIR}"
crystal spec "${SPEC}"
