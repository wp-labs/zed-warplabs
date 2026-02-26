#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXT_TOML="${ROOT_DIR}/extension.toml"
LANGS=(gxl oml wfg wfl wfs wpl)
if [ -n "${CHECK_LANGS:-}" ]; then
  # shellcheck disable=SC2206
  LANGS=(${CHECK_LANGS})
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] missing required command: $1" >&2
    exit 1
  fi
}

run_with_timeout() {
  local seconds="$1"
  shift
  python3 - "$seconds" "$@" <<'PY'
import subprocess
import sys

timeout_seconds = float(sys.argv[1])
cmd = sys.argv[2:]

try:
    subprocess.run(cmd, check=True, timeout=timeout_seconds)
except subprocess.TimeoutExpired:
    print(f"[ERROR] command timed out after {timeout_seconds:.0f}s: {' '.join(cmd)}", file=sys.stderr)
    sys.exit(124)
except subprocess.CalledProcessError as exc:
    sys.exit(exc.returncode)
PY
}

read_toml_value() {
  local lang="$1"
  local key="$2"
  awk -v section="[grammars.${lang}]" -v key="${key}" '
    $0 == section { in_section = 1; next }
    in_section && /^\[/ { in_section = 0 }
    in_section && $1 == key && $2 == "=" {
      value = $0
      sub(/^[^=]+= */, "", value)
      sub(/#.*/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "${EXT_TOML}"
}

need_cmd git
need_cmd tree-sitter
need_cmd python3

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/warplabs-grammar-check.XXXXXX")"
trap 'rm -rf "${TMP_ROOT}"' EXIT
CMD_TIMEOUT_SECONDS="${CMD_TIMEOUT_SECONDS:-20}"

echo "[INFO] temp workspace: ${TMP_ROOT}"

for lang in "${LANGS[@]}"; do
  queries_dir="${ROOT_DIR}/languages/${lang}"
  examples_dir="${ROOT_DIR}/examples/${lang}"

  if [ ! -d "${queries_dir}" ]; then
    echo "[ERROR] missing language query directory: ${queries_dir}" >&2
    exit 1
  fi

  shopt -s nullglob
  query_files=("${queries_dir}"/*.scm)
  shopt -u nullglob
  if [ "${#query_files[@]}" -eq 0 ]; then
    echo "[ERROR] no query files found under ${queries_dir}" >&2
    exit 1
  fi

  shopt -s nullglob
  examples=("${examples_dir}"/*.${lang})
  shopt -u nullglob
  if [ "${#examples[@]}" -eq 0 ]; then
    echo "[ERROR] no .${lang} examples found under ${examples_dir}" >&2
    exit 1
  fi

  repo="$(read_toml_value "${lang}" repository)"
  rev="$(read_toml_value "${lang}" rev)"
  if [ -z "${repo}" ] || [ -z "${rev}" ]; then
    echo "[ERROR] missing repository/rev in [grammars.${lang}] of extension.toml" >&2
    exit 1
  fi

  clone_dir="${TMP_ROOT}/${lang}"
  echo "[INFO] [${lang}] clone ${repo} @ ${rev}"
  git clone --quiet --filter=blob:none "${repo}" "${clone_dir}"
  git -C "${clone_dir}" checkout --quiet "${rev}"

  echo "[INFO] [${lang}] tree-sitter generate"
  (cd "${clone_dir}" && tree-sitter generate >/dev/null)

  echo "[INFO] [${lang}] parse ${#examples[@]} example(s)"
  for file in "${examples[@]}"; do
    (cd "${clone_dir}" && run_with_timeout "${CMD_TIMEOUT_SECONDS}" tree-sitter parse -q "${file}" >/dev/null)
  done

  echo "[INFO] [${lang}] compile+run ${#query_files[@]} query file(s)"
  for query_file in "${query_files[@]}"; do
    for file in "${examples[@]}"; do
      (cd "${clone_dir}" && run_with_timeout "${CMD_TIMEOUT_SECONDS}" tree-sitter query -q "${query_file}" "${file}" >/dev/null)
    done
  done
done

echo "[OK] grammar parse and language query checks passed"
