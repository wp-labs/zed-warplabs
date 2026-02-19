# WarpLabs Zed Extension — Development Guide

## Overview

`zed-warplabs` is a Zed editor extension providing full language support for 5 WarpLabs DSLs:

| Language | Suffix | Description |
|----------|--------|-------------|
| WFL | `.wfl` | WarpFusion Language (fusion rules) |
| WFS | `.wfs` | Window Field Schema |
| WPL | `.wpl` | WarpLabs Parsing Language |
| OML | `.oml` | Output Mapping Language |
| WFG | `.wfg` | WarpFusion scenario Generator |

The extension has two components:

1. **Zed extension** (`tools/zed-warplabs/`) — syntax highlighting, bracket matching, code folding, indentation, outline, snippets, and LSP client integration
2. **Language server** (`tools/wplab-lsp/`) — diagnostics, completion, hover, go-to-definition, find references, rename, document symbols, formatting

## Directory Structure

```
tools/
├── zed-warplabs/                  # Zed extension
│   ├── extension.toml             # Manifest: grammars, language servers
│   ├── Cargo.toml                 # Rust cdylib for WASM (LSP integration)
│   ├── src/lib.rs                 # Extension trait: language_server_command
│   ├── languages/<lang>/          # Per-language Zed config
│   │   ├── config.toml
│   │   ├── highlights.scm
│   │   ├── brackets.scm
│   │   ├── indents.scm
│   │   ├── folds.scm
│   │   └── outline.scm
│   ├── grammars/                  # Pre-built .wasm + Zed-cloned grammar repos
│   ├── snippets/                  # Code snippets (oml.json)
│   └── examples/                  # Test files for all 5 languages
│
├── wplab-lsp/                     # Language server (Rust binary)
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs                # tokio + tower-lsp stdio transport
│       ├── server.rs              # LanguageServer trait implementation
│       ├── capabilities.rs        # ServerCapabilities declaration
│       ├── dispatch.rs            # Language dispatch by lang_id / extension
│       ├── document.rs            # DocumentState (text + tree-sitter Tree)
│       ├── util.rs                # tree-sitter ↔ LSP type helpers
│       ├── lang/                  # Per-language handlers
│       │   ├── mod.rs             # LangHandler trait definition
│       │   ├── wfl.rs             # WFL: rules, contracts, aggregates
│       │   ├── wfs.rs             # WFS: windows, fields, types
│       │   ├── wpl.rs             # WPL: packages, rules, parsing types
│       │   ├── oml.rs             # OML: targets, pipe functions
│       │   └── wfg.rs             # WFG: scenarios, streams, gen functions
│       └── features/              # LSP feature modules
│           ├── diagnostics.rs     # tree-sitter ERROR/MISSING → Diagnostic
│           ├── completion.rs      # Keywords + builtins + identifiers
│           ├── hover.rs           # Keyword/builtin/identifier docs
│           ├── definition.rs      # Go-to-definition
│           ├── references.rs      # Find references
│           ├── rename.rs          # Rename symbol
│           ├── symbols.rs         # Document symbols (outline)
│           └── formatting.rs      # Indent-based formatting
│
├── tree-sitter-wfl/               # Grammar repos (independent git repos)
├── tree-sitter-wfs/
├── tree-sitter-wpl/
├── tree-sitter-oml/
└── tree-sitter-wfg/
```

---

## Local Development

### Prerequisites

- Rust toolchain (stable)
- tree-sitter CLI: `brew install tree-sitter`
- emscripten (for WASM builds): `brew install emscripten`
- Zed editor

### Build & Install

```bash
# 1. Build the language server
cd tools/wplab-lsp
cargo build --release

# 2. Make it available in PATH
ln -sf "$(pwd)/target/release/wplab-lsp" /usr/local/bin/wplab-lsp

# 3. Install dev extension in Zed
#    Cmd+Shift+P → "zed: install dev extension" → select tools/zed-warplabs/
```

### Edit-Test Cycle

**For grammar changes:**

```bash
cd tools/tree-sitter-<lang>
# Edit grammar.js
tree-sitter generate
tree-sitter parse ../zed-warplabs/examples/<lang>/example.<lang>
git add -A && git commit -m "Grammar change description"

# Update extension.toml rev
cd ../zed-warplabs
# Edit extension.toml: set rev to new commit hash

# Optionally rebuild WASM
tree-sitter build --wasm
cp tree-sitter-<lang>.wasm ../zed-warplabs/grammars/<lang>.wasm

# Reinstall dev extension in Zed
```

**For LSP changes:**

```bash
cd tools/wplab-lsp
# Edit source files
cargo build --release
# Restart LSP in Zed: Cmd+Shift+P → "lsp: restart server"
```

**For highlight/indent/fold changes:**

Edit the `.scm` files in `languages/<lang>/`, then reinstall the dev extension.

---

## Adding a New Language

### Step 1: Create Tree-Sitter Grammar

```bash
mkdir tools/tree-sitter-<lang>
cd tools/tree-sitter-<lang>
git init
```

Create `grammar.js`:

```javascript
/// <reference types="tree-sitter-cli/dsl" />

module.exports = grammar({
  name: "<lang>",              // CRITICAL: must match extension.toml grammar key
  extras: ($) => [/\s/, $.comment],
  word: ($) => $.identifier,
  rules: {
    source_file: ($) => repeat($._statement),
    // ... your rules
    comment: (_$) => token(seq("//", /.*/)),
    identifier: (_$) => /[a-zA-Z_][a-zA-Z0-9_]*/,
  },
});
```

Create `package.json`:

```json
{
  "name": "tree-sitter-<lang>",
  "version": "0.1.0",
  "description": "Tree-sitter grammar for <LANG>",
  "main": "bindings/node",
  "types": "bindings/node",
  "keywords": ["tree-sitter", "parser", "<lang>"],
  "files": ["grammar.js", "binding.gyp", "prebuilds/**", "bindings/node/*", "queries/*", "src/**"],
  "dependencies": {
    "node-addon-api": "^7.1.0",
    "node-gyp-build": "^4.8.0"
  },
  "peerDependencies": { "tree-sitter": "^0.21.0" },
  "peerDependenciesMeta": { "tree_sitter": { "optional": true } },
  "devDependencies": {
    "prebuildify": "^6.0.0",
    "tree-sitter-cli": "^0.22.6"
  },
  "tree-sitter": [
    {
      "scope": "source.<lang>",
      "file-types": ["<lang>"],
      "highlights": "queries/highlights.scm"
    }
  ]
}
```

Generate, test, commit:

```bash
tree-sitter generate
tree-sitter parse examples/test.<lang>
git add -A && git commit -m "Initial tree-sitter-<lang> grammar"
```

### Step 2: Build WASM

```bash
tree-sitter build --wasm
cp tree-sitter-<lang>.wasm ../zed-warplabs/grammars/<lang>.wasm
```

### Step 3: Create Zed Language Config

Create `tools/zed-warplabs/languages/<lang>/` with these files:

**config.toml:**

```toml
name = "<LANG>"
grammar = "<lang>"
path_suffixes = ["<lang>"]
line_comments = ["//"]
brackets = [
  { start = "{", end = "}", close = true, newline = true },
  { start = "(", end = ")", close = true, newline = false },
  { start = "[", end = "]", close = true, newline = false },
  { start = "\"", end = "\"", close = true, newline = false, not_in = ["string", "comment"] },
]
autoclose_before = ";:.,=}])> \n\t"
```

**highlights.scm** — Zed uses **last match wins** (opposite of tree-sitter). Generic first, specific last:

```scheme
(identifier) @variable
"keyword" @keyword
(func_call name: (identifier) @function.builtin)
```

**brackets.scm**, **indents.scm**, **folds.scm**, **outline.scm** — see existing languages for patterns.

### Step 4: Register in extension.toml

```toml
[grammars.<lang>]
repository = "https://github.com/wp-labs/tree-sitter-<lang>"
rev = "<git-commit-hash>"
```

### Step 5: Add Language Handler to wplab-lsp

Create `tools/wplab-lsp/src/lang/<lang>.rs`:

```rust
use crate::lang::{BuiltinInfo, LangHandler, SymbolInfo};

pub struct <Lang>Handler;

impl LangHandler for <Lang>Handler {
    fn language(&self) -> tree_sitter::Language {
        tree_sitter_<lang>::language()
    }
    fn lang_id(&self) -> &str { "<lang>" }
    fn extensions(&self) -> &[&str] { &["<lang>"] }
    fn keywords(&self) -> &[&str] { &[/* ... */] }
    fn builtins(&self) -> &[BuiltinInfo] { &[] }
    fn document_symbols(&self, tree: &Tree, src: &str) -> Vec<SymbolInfo> { vec![] }
    fn find_definitions(&self, tree: &Tree, src: &str, name: &str) -> Vec<Range> { vec![] }
    fn find_references(&self, tree: &Tree, src: &str, name: &str) -> Vec<Range> { vec![] }
    fn format_document(&self, _tree: &Tree, src: &str) -> Option<String> { None }
}
```

Register in `lang/mod.rs` and `dispatch.rs`.

Add `tree-sitter-<lang>` dependency to `wplab-lsp/Cargo.toml`.

### Step 6: Test

```bash
cd tools/wplab-lsp && cargo build --release
# Reinstall dev extension in Zed
# Open a .<lang> file → verify highlighting + LSP features
```

---

## LSP Architecture

### Design

The LSP uses **tree-sitter as the parsing layer** (not wf-lang's winnow parser) because:

1. Tree-sitter supports **incremental parsing** — only re-parses changed regions on each keystroke
2. Tree-sitter provides **precise byte/row/column ranges** — maps directly to LSP Position
3. Tree-sitter is **error-tolerant** — produces partial ASTs for incomplete code
4. One **unified parsing interface** for all 5 languages

### Key Types

```
WfLsp (server.rs)
├── Client                        # tower-lsp client for sending notifications
├── DashMap<Url, DocumentState>   # Thread-safe document store
└── Dispatcher                    # Routes to per-language LangHandler
    ├── WflHandler
    ├── WfsHandler
    ├── WplHandler
    ├── OmlHandler
    └── WfgHandler

DocumentState (document.rs)
├── text: String                  # Current document content
├── tree: Tree                    # tree-sitter parse tree (updated incrementally)
├── version: i32                  # LSP document version
└── lang_id: String               # Language identifier

LangHandler trait (lang/mod.rs)
├── language() → tree_sitter::Language
├── keywords() → &[&str]
├── builtins() → &[BuiltinInfo]
├── document_symbols(tree, src) → Vec<SymbolInfo>
├── find_definitions(tree, src, name) → Vec<Range>
├── find_references(tree, src, name) → Vec<Range>
└── format_document(tree, src) → Option<String>
```

### Request Flow

```
Client                    Server
  |  did_open(text)         |
  |------------------------>|  parse → Tree, collect ERROR nodes → Diagnostics
  |  publishDiagnostics     |
  |<------------------------|
  |                         |
  |  did_change(text)       |
  |------------------------>|  re-parse (incremental) → update Tree → Diagnostics
  |  publishDiagnostics     |
  |<------------------------|
  |                         |
  |  completion(pos)        |
  |------------------------>|  keywords + builtins + identifiers at cursor
  |  CompletionList         |
  |<------------------------|
  |                         |
  |  hover(pos)             |
  |------------------------>|  find node at pos → keyword doc / builtin sig / context
  |  Hover                  |
  |<------------------------|
```

### Adding a New LSP Feature

1. Create `features/<feature>.rs` with the feature logic
2. Add `pub mod <feature>;` to `features/mod.rs`
3. Add the trait method to `LanguageServer` impl in `server.rs`
4. Declare the capability in `capabilities.rs`

---

## Publishing

### Prerequisites

1. All 5 tree-sitter grammar repos pushed to GitHub (`github.com/wp-labs/tree-sitter-*`)
2. The Zed extension repo pushed to GitHub (`github.com/wp-labs/zed-warplabs`)
3. `extension.toml` uses GitHub URLs (not `file:///`) for grammars
4. `extension.toml` has `repository` field pointing to the extension repo
5. `wplab-lsp` binary is distributable (published to crates.io or GitHub Releases)

### Publish wplab-lsp

**Option A — crates.io:**

```bash
cd tools/wplab-lsp
# Ensure Cargo.toml has: description, license, repository fields
cargo publish
```

Users install with: `cargo install wplab-lsp`

**Option B — GitHub Releases:**

Build for multiple targets and upload binaries to a GitHub Release. Users download and place in PATH.

### Publish Zed Extension

1. Ensure `tools/zed-warplabs/` is pushed to `https://github.com/wp-labs/zed-warplabs`
2. Fork [zed-industries/extensions](https://github.com/zed-industries/extensions)
3. Create `extensions/warplabs/extension.toml`:

   ```toml
   [extension]
   repository = "https://github.com/wp-labs/zed-warplabs"
   version = "0.9.0"
   ```

4. Submit a PR to `zed-industries/extensions` `main` branch
5. After merge, the extension appears in Zed's marketplace

### Version Bumping

When releasing a new version:

1. Bump `version` in `tools/zed-warplabs/extension.toml`
2. Update grammar `rev` values if grammars changed
3. Push to GitHub
4. Update `version` in the `zed-industries/extensions` entry
5. Submit PR

---

## Troubleshooting

### "grammar directory already exists, but is not a git clone"

The `grammars/<lang>/` directory was created manually.

**Fix:** `rm -rf tools/zed-warplabs/grammars/<lang>` and reinstall.

### "symbol exported via --export not found: tree_sitter_<lang>"

The `name` in `grammar.js` doesn't match the grammar key in `extension.toml`.

**Fix:** Ensure `grammar.js` has `name: "<lang>"` matching `[grammars.<lang>]`. Regenerate and recommit.

### "Query error: Invalid node type"

A `.scm` query references a nonexistent node type.

**Fix:** Run `tree-sitter parse <file>` to see actual node types, then fix the query.

### LSP not starting in Zed

Check Zed logs: `Cmd+Shift+P` → "zed: open log". Common causes:

- `wplab-lsp` not in PATH → install it
- Extension WASM build failed → check Rust compilation errors in the log
- Wrong `zed_extension_api` version → update `Cargo.toml`

### LSP running but no features

Verify the LSP responds to `initialize`:

```bash
printf 'Content-Length: 80\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}' \
  | wplab-lsp
```

Expected: JSON response with `completionProvider`, `hoverProvider`, etc.

---

## Key Constraints

| Rule | Details |
|------|---------|
| `grammar.js` name = extension.toml key | `name: "wfg"` ↔ `[grammars.wfg]` |
| `grammars/<lang>/` managed by Zed | Don't create manually |
| `grammars/<lang>.wasm` committed to git | Pre-built WASM avoids Zed build issues |
| Grammar `rev` must be valid commit | Update after every grammar change |
| Zed highlights: last match wins | Generic `@variable` first, specific `@function.builtin` last |
| tree-sitter highlights: first match wins | Opposite of Zed |
| `zed_extension_api` trait requires `fn new()` | Cannot use `#[derive(Default)]` |
| LSP binary must be in PATH | Extension uses `worktree.which("wplab-lsp")` |

## Checklist: Adding a Language

```
[ ] 1.  Create tools/tree-sitter-<lang>/ with grammar.js + package.json
[ ] 2.  tree-sitter generate && tree-sitter parse <example>
[ ] 3.  Write queries/highlights.scm
[ ] 4.  git init && git add -A && git commit && push to GitHub
[ ] 5.  tree-sitter build --wasm → copy .wasm to grammars/
[ ] 6.  Create languages/<lang>/ (config.toml + 5 .scm files)
[ ] 7.  Add [grammars.<lang>] to extension.toml with GitHub URL + rev
[ ] 8.  Create wplab-lsp/src/lang/<lang>.rs implementing LangHandler
[ ] 9.  Register in lang/mod.rs and dispatch.rs
[ ] 10. Add tree-sitter-<lang> dependency to wplab-lsp/Cargo.toml
[ ] 11. cargo build --release && reinstall dev extension
[ ] 12. Bump extension version
[ ] 13. Test all features with example files
```
