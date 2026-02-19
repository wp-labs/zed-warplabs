#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ZED_DIR="$SCRIPT_DIR"
TOOLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXT_TOML="${ZED_DIR}/extension.toml"
ALL_LANGS=(gxl oml wfg wfl wfs wpl)

# ── Helpers ────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
Usage: sync-grammar.sh <lang|all> [--local]

  lang     One of: gxl oml wfg wfl wfs wpl
  all      Sync all languages
  --local  Skip push & rev update (dev/debug only)

Examples:
  ./tools/zed-warplabs/sync-grammar.sh oml            # push + update rev + build WASM
  ./tools/zed-warplabs/sync-grammar.sh all            # sync all languages
  ./tools/zed-warplabs/sync-grammar.sh oml --local    # local-only (no push, no rev update)
EOF
  exit 1
}

info()  { printf '  [INFO]  %s\n' "$*"; }
ok()    { printf '  [OK]    %s\n' "$*"; }
err()   { printf '  [ERROR] %s\n' "$*" >&2; }
fatal() { err "$@"; exit 1; }

# ── Step 1: Generate parser & validate examples ───────────────────────
step_generate() {
  local lang=$1
  local src="${TOOLS_DIR}/tree-sitter-${lang}"

  info "Generating parser in ${src}"
  (cd "$src" && tree-sitter generate)

  # Validate example files in source repo
  local has_examples=false
  shopt -s nullglob
  for f in "$src"/examples/*."$lang"; do
    has_examples=true
    info "Parsing (source) $(basename "$f")"
    (cd "$src" && tree-sitter parse "$f")
  done

  # Validate example files in zed-warplabs/examples/<lang>/
  for f in "${ZED_DIR}"/examples/"$lang"/*."$lang"; do
    has_examples=true
    info "Parsing (zed) $(basename "$f")"
    (cd "$src" && tree-sitter parse "$f")
  done
  shopt -u nullglob

  if [ "$has_examples" = false ]; then
    info "No .$lang example files found — skipping parse validation"
  fi
}

# ── Step 2: Push to GitHub ────────────────────────────────────────────
step_push() {
  local lang=$1
  local src="${TOOLS_DIR}/tree-sitter-${lang}"

  if [ -n "$(cd "$src" && git status --porcelain)" ]; then
    fatal "${src} has uncommitted changes. Commit first."
  fi

  info "Pushing tree-sitter-${lang} to origin"
  (cd "$src" && git push origin HEAD)
}

# ── Step 3: Update extension.toml rev ─────────────────────────────────
step_update_rev() {
  local lang=$1
  local src="${TOOLS_DIR}/tree-sitter-${lang}"
  local rev
  rev=$(cd "$src" && git rev-parse HEAD)

  info "Updating extension.toml: grammars.${lang} rev = ${rev}"
  # Match the [grammars.<lang>] section and replace the rev line within it
  sed -i '' "/\[grammars\.${lang}\]/,/^$/s/^rev = .*/rev = \"${rev}\"/" "$EXT_TOML"

  ok "extension.toml updated (${lang} → ${rev})"
}

# ── Step 4: Sync local grammars/<lang>/ clone ─────────────────────────
copy_source_files() {
  local src=$1 dst=$2
  info "Copying core files from ${src} to ${dst}"
  mkdir -p "$dst"
  cp "$src/grammar.js"   "$dst/grammar.js"
  cp "$src/package.json"  "$dst/package.json"
  if [ -d "$src/queries" ]; then
    rm -rf "$dst/queries"
    cp -r "$src/queries" "$dst/queries"
  fi
  [ -f "$src/tree-sitter.json" ] && cp "$src/tree-sitter.json" "$dst/"
}

step_sync_clone() {
  local lang=$1
  local local_only=$2
  local src="${TOOLS_DIR}/tree-sitter-${lang}"
  local dst="${ZED_DIR}/grammars/${lang}"

  if [ "$local_only" = false ] && [ -d "$dst/.git" ]; then
    # Remote mode: clone fetches the just-pushed commit from GitHub
    info "Fetching latest into ${dst}"
    (cd "$dst" && git fetch origin && git reset --hard FETCH_HEAD)
  else
    # Local mode or no git: copy files directly from source
    copy_source_files "$src" "$dst"
  fi
}

# ── Step 5: Generate + build WASM in clone ────────────────────────────
step_build_wasm() {
  local lang=$1
  local dst="${ZED_DIR}/grammars/${lang}"

  info "Generating parser in ${dst}"
  (cd "$dst" && tree-sitter generate)

  info "Building WASM for ${lang}"
  (cd "$dst" && tree-sitter build --wasm)

  local wasm_file="${dst}/tree-sitter-${lang}.wasm"
  if [ ! -f "$wasm_file" ]; then
    fatal "WASM build did not produce ${wasm_file}"
  fi

  cp "$wasm_file" "${ZED_DIR}/grammars/${lang}.wasm"
  ok "grammars/${lang}.wasm updated"
}

# ── Rebuild extension.wasm ────────────────────────────────────────────
rebuild_extension() {
  if [ ! -f "${ZED_DIR}/Cargo.toml" ]; then
    info "No Cargo.toml in zed-warplabs — skipping extension.wasm rebuild"
    return
  fi

  info "Rebuilding extension.wasm"
  (cd "$ZED_DIR" && cargo build --release --target wasm32-wasip1)
  cp "${ZED_DIR}/target/wasm32-wasip1/release/warplabs_zed_extension.wasm" \
     "${ZED_DIR}/extension.wasm"
  ok "extension.wasm rebuilt"
}

# ── Sync one language ─────────────────────────────────────────────────
sync_grammar() {
  local lang=$1
  local local_only=$2

  local src="${TOOLS_DIR}/tree-sitter-${lang}"
  [ -d "$src" ] || fatal "Source directory not found: ${src}"

  printf '\n━━ Syncing %s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$lang"

  # Step 1: Generate & validate
  step_generate "$lang"

  if [ "$local_only" = false ]; then
    # Step 2: Push
    step_push "$lang"

    # Step 3: Update rev
    step_update_rev "$lang"
  else
    info "Local mode — skipping push & rev update"
  fi

  # Step 4: Sync clone
  step_sync_clone "$lang" "$local_only"

  # Step 5: Build WASM
  step_build_wasm "$lang"

  local rev
  rev=$(cd "$src" && git rev-parse --short HEAD)
  ok "${lang} synced (rev: ${rev})"
}

# ── Print version info ────────────────────────────────────────────────
print_versions() {
  local ext_ver toml_ver
  ext_ver=$(grep '^version' "$EXT_TOML" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
  printf '\n  extension.toml version: %s\n' "$ext_ver"

  if [ -f "${ZED_DIR}/Cargo.toml" ]; then
    toml_ver=$(grep '^version' "${ZED_DIR}/Cargo.toml" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
    printf '  Cargo.toml version:     %s\n' "$toml_ver"
  fi

  printf '  (version bumps are manual — update these before publishing)\n\n'
}

# ── Main ──────────────────────────────────────────────────────────────
[ $# -lt 1 ] && usage

TARGET="$1"
LOCAL_ONLY=false
if [ "${2:-}" = "--local" ]; then
  LOCAL_ONLY=true
fi

# Resolve language list
if [ "$TARGET" = "all" ]; then
  LANGS=("${ALL_LANGS[@]}")
else
  # Validate language name
  valid=false
  for l in "${ALL_LANGS[@]}"; do
    [ "$l" = "$TARGET" ] && valid=true
  done
  [ "$valid" = true ] || fatal "Unknown language: ${TARGET}. Must be one of: ${ALL_LANGS[*]}"
  LANGS=("$TARGET")
fi

# Sync each language
for lang in "${LANGS[@]}"; do
  sync_grammar "$lang" "$LOCAL_ONLY"
done

# Rebuild extension WASM
rebuild_extension

# Print version reminder
print_versions

printf '━━ Done ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
