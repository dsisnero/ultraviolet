#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT_DIR}/docs/go_test_parity.tsv"
GO_DIR="${ROOT_DIR}/ultraviolet_go"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Missing manifest: ${MANIFEST}" >&2
  exit 1
fi

if [[ ! -d "${GO_DIR}" ]]; then
  echo "Missing submodule directory: ${GO_DIR}" >&2
  exit 1
fi

tmp_go="$(mktemp)"
tmp_manifest_ids="$(mktemp)"
tmp_manifest_rows="$(mktemp)"
tmp_missing="$(mktemp)"
tmp_stale="$(mktemp)"

cleanup() {
  rm -f "${tmp_go}" "${tmp_manifest_ids}" "${tmp_manifest_rows}" "${tmp_missing}" "${tmp_stale}"
}
trap cleanup EXIT

while IFS= read -r go_file; do
  rel_file="${go_file#${GO_DIR}/}"
  rg -n '^func Test[^(]+' "${go_file}" \
    | sed -E "s#^[0-9]+:func (Test[^ (]+)\\(.*#${rel_file}::\\1#"
done < <(find "${GO_DIR}" -name '*_test.go' | sort) | sort -u > "${tmp_go}"

awk -F '\t' '
  BEGIN {
    ok = 1
  }
  /^#/ || NF == 0 {
    next
  }
  {
    if (NF < 4) {
      printf("Malformed manifest row (expected 4 tab-separated columns): %s\n", $0) > "/dev/stderr"
      ok = 0
      next
    }

    id = $1
    status = $2
    refs = $3

    if (seen[id]++) {
      printf("Duplicate go_test_id in manifest: %s\n", id) > "/dev/stderr"
      ok = 0
    }

    if (status != "ported" && status != "intentional_divergence" && status != "missing") {
      printf("Invalid status for %s: %s\n", id, status) > "/dev/stderr"
      ok = 0
    }

    if (refs == "") {
      printf("Missing crystal_refs for %s\n", id) > "/dev/stderr"
      ok = 0
    }

    printf("%s\t%s\n", id, status)
  }
  END {
    if (!ok) {
      exit 2
    }
  }
' "${MANIFEST}" > "${tmp_manifest_rows}"

cut -f1 "${tmp_manifest_rows}" | sort -u > "${tmp_manifest_ids}"

comm -23 "${tmp_go}" "${tmp_manifest_ids}" > "${tmp_missing}"
comm -13 "${tmp_go}" "${tmp_manifest_ids}" > "${tmp_stale}"

if [[ -s "${tmp_missing}" ]]; then
  echo "Go tests missing from parity manifest:" >&2
  sed 's/^/  - /' "${tmp_missing}" >&2
  exit 1
fi

if [[ -s "${tmp_stale}" ]]; then
  echo "Manifest entries with no matching Go tests:" >&2
  sed 's/^/  - /' "${tmp_stale}" >&2
  exit 1
fi

if awk -F '\t' '$2 == "missing" { found = 1 } END { exit(found ? 0 : 1) }' "${tmp_manifest_rows}"; then
  echo "Parity manifest contains tests marked as missing." >&2
  awk -F '\t' '$2 == "missing" { printf("  - %s\n", $1) }' "${tmp_manifest_rows}" >&2
  exit 1
fi

go_count="$(wc -l < "${tmp_go}" | tr -d ' ')"
manifest_count="$(wc -l < "${tmp_manifest_ids}" | tr -d ' ')"
echo "Go test parity check passed (${go_count} tests mapped; ${manifest_count} manifest entries)."
