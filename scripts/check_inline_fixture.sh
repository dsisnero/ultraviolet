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
# `src` is copied in, so its shard requirements must come from this checkout too:
# an ansi older than the one pinned here can lack an API `src` now uses (for
# example `Ansi::Grapheme`), and the fixture would fail for a reason that has
# nothing to do with the frame it is checking.
swapped_ansi=0
if [[ -d "${ROOT_DIR}/lib/ansi" ]]; then
  if [[ -d "${BUBBLE_DIR}/lib/ansi" ]]; then
    mv "${BUBBLE_DIR}/lib/ansi" "${backup}/ansi"
  fi
  cp -R "${ROOT_DIR}/lib/ansi" "${BUBBLE_DIR}/lib/ansi"
  swapped_ansi=1
fi
restore() {
  rm -rf "${BUBBLE_DIR}/lib/ultraviolet"
  mv "${backup}/ultraviolet" "${BUBBLE_DIR}/lib/ultraviolet"
  if [[ "${swapped_ansi}" == "1" ]]; then
    rm -rf "${BUBBLE_DIR}/lib/ansi"
    if [[ -d "${backup}/ansi" ]]; then
      mv "${backup}/ansi" "${BUBBLE_DIR}/lib/ansi"
    fi
  fi
  rmdir "${backup}" 2>/dev/null || true
}
trap restore EXIT

mkdir -p "${BUBBLE_DIR}/lib/ultraviolet"
cp -R "${ROOT_DIR}/src" "${BUBBLE_DIR}/lib/ultraviolet/src"
cp "${ROOT_DIR}/shard.yml" "${BUBBLE_DIR}/lib/ultraviolet/shard.yml"

cd "${BUBBLE_DIR}"
crystal spec "${SPEC}"
