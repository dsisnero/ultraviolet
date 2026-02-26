#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT_DIR}/docs/go_source_parity.tsv"

GO_FILES=(
  "${ROOT_DIR}/ultraviolet_go/uv.go"
  "${ROOT_DIR}/ultraviolet_go/terminal_screen.go"
  "${ROOT_DIR}/ultraviolet_go/console.go"
  "${ROOT_DIR}/ultraviolet_go/screen/context.go"
)

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Missing manifest: ${MANIFEST}" >&2
  exit 1
fi

for file in "${GO_FILES[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing source file for drift check: ${file}" >&2
    exit 1
  fi
done

tmp_go="$(mktemp)"
tmp_manifest_ids="$(mktemp)"
tmp_manifest_rows="$(mktemp)"
tmp_missing="$(mktemp)"
tmp_stale="$(mktemp)"

cleanup() {
  rm -f "${tmp_go}" "${tmp_manifest_ids}" "${tmp_manifest_rows}" "${tmp_missing}" "${tmp_stale}"
}
trap cleanup EXIT

awk '
function emit(file, kind, name){print file "::" kind "::" name}
FNR==1{file=FILENAME; sub(/^.*ultraviolet_go\//, "", file)}
/^type [A-Z][A-Za-z0-9_]*/ {emit(file, "type", $2)}
/^func [A-Z][A-Za-z0-9_]*\(/ {
  name=$2; sub(/\(.*/, "", name); emit(file, "func", name)
}
/^func \([^)]*\) [A-Z][A-Za-z0-9_]*\(/ {
  line=$0
  sub(/^func \([^)]*\) /, "", line)
  sub(/\(.*/, "", line)
  emit(file, "method", line)
}
' "${GO_FILES[@]}" | sort -u > "${tmp_go}"

awk -F '\t' '
  BEGIN { ok = 1 }
  /^#/ || NF == 0 { next }
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
      printf("Duplicate go_source_id in manifest: %s\n", id) > "/dev/stderr"
      ok = 0
    }
    if (status != "mapped" && status != "partial" && status != "missing") {
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
  echo "Go exported API items missing from source parity manifest:" >&2
  sed 's/^/  - /' "${tmp_missing}" >&2
  exit 1
fi

if [[ -s "${tmp_stale}" ]]; then
  echo "Source parity manifest has stale API entries:" >&2
  sed 's/^/  - /' "${tmp_stale}" >&2
  exit 1
fi

go_count="$(wc -l < "${tmp_go}" | tr -d ' ')"
manifest_count="$(wc -l < "${tmp_manifest_ids}" | tr -d ' ')"
echo "Go source parity check passed (${go_count} API items tracked; ${manifest_count} manifest entries)."
