#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
MANIFEST="${2:-${ROOT_DIR}/plans/inventory/go_source_parity.tsv}"
SOURCE_PATH="${3:-${GO_PORT_SOURCE_DIR:-}}"

if [[ ! -f "${MANIFEST}" ]]; then
  echo "Missing manifest: ${MANIFEST}" >&2
  exit 1
fi

if [[ -n "${SOURCE_PATH}" ]]; then
  if [[ "${SOURCE_PATH}" = /* ]]; then
    GO_BASE="${SOURCE_PATH}"
  else
    GO_BASE="${ROOT_DIR}/${SOURCE_PATH}"
  fi
elif [[ -d "${ROOT_DIR}/vendor" ]]; then
  GO_BASE="${ROOT_DIR}/vendor"
else
  GO_BASE="${ROOT_DIR}"
fi

if [[ ! -d "${GO_BASE}" ]]; then
  echo "Go source directory does not exist: ${GO_BASE}" >&2
  exit 1
fi

GO_FILES=()
while IFS= read -r f; do
  GO_FILES+=("$f")
done < <(find "${GO_BASE}" -type d -name .git -prune -o -type f -name '*.go' ! -name '*_test.go' -print | sort)

if [[ ${#GO_FILES[@]} -eq 0 ]]; then
  echo "No Go source files found under ${GO_BASE}" >&2
  exit 1
fi

tmp_go="$(mktemp)"
tmp_manifest_ids="$(mktemp)"
tmp_manifest_rows="$(mktemp)"
tmp_missing="$(mktemp)"
tmp_stale="$(mktemp)"
trap 'rm -f "${tmp_go}" "${tmp_manifest_ids}" "${tmp_manifest_rows}" "${tmp_missing}" "${tmp_stale}"' EXIT

awk -v base="${GO_BASE}" '
function rel(file) {
  if (index(file, base "/") == 1) return substr(file, length(base) + 2)
  return file
}
function emit(file, kind, name){print rel(file) "::" kind "::" name}
/^type [A-Z][A-Za-z0-9_]*/ {emit(FILENAME, "type", $2)}
/^func [A-Z][A-Za-z0-9_]*\(/ {
  name=$2; sub(/\(.*/, "", name); emit(FILENAME, "func", name)
}
/^func \([^)]*\) [A-Z][A-Za-z0-9_]*\(/ {
  line=$0
  sub(/^func \([^)]*\) /, "", line)
  sub(/\(.*/, "", line)
  emit(FILENAME, "method", line)
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
END { if (!ok) exit 2 }
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
