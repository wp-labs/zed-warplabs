# WarpLabs Zed Extension

Zed editor extension for WarpLabs DSLs — syntax highlighting, diagnostics, completion, hover, go-to-definition, find references, rename, document symbols, and formatting.

## Supported Languages

| Language | Suffix | Description |
|----------|--------|-------------|
| WFL | `.wfl` | WarpFusion Language — fusion rules, pattern detection, scoring |
| WFS | `.wfs` | Window Field Schema — event stream window and field definitions |
| WPL | `.wpl` | WarpLabs Parsing Language — log parsing with transformation pipelines |
| OML | `.oml` | Output Mapping Language — output mapping and transformations |
| WFG | `.wfg` | WarpFusion scenario Generator — test scenario generation and fault injection |

## Features

### Syntax Highlighting

Tree-sitter-based highlighting for all 5 languages, including keywords, types, strings, numbers, comments, operators, and built-in functions.

### Language Server (wplabs-lsp)

The extension integrates with `wplabs-lsp`, a Language Server Protocol server that provides:

| Feature | Description |
|---------|-------------|
| **Diagnostics** | Real-time syntax error detection from tree-sitter ERROR/MISSING nodes |
| **Completion** | Keywords, built-in functions/types, document identifiers |
| **Hover** | Documentation for keywords, built-in function signatures, identifier context |
| **Go to Definition** | Jump to rule, window, scenario, package declarations (`Cmd+Click` / `F12`) |
| **Find References** | Find all usages of a symbol (`Shift+F12`) |
| **Rename** | Rename symbol across all definition and reference sites (`F2`) |
| **Document Symbols** | Outline view of rules, windows, contracts, scenarios (`Cmd+Shift+O`) |
| **Formatting** | Indent-based document formatting (`Cmd+Shift+I`) |

### Other

- Bracket matching and auto-close
- Auto-indentation
- Code folding
- Code snippets (OML)

## Installation

### 1. Install wplabs-lsp

The LSP binary must be in your `PATH`.

**From source:**

```bash
cd tools/wplabs-lsp
cargo build --release
# Copy or symlink to a directory in your PATH
cp target/release/wplabs-lsp /usr/local/bin/
# or
ln -s "$(pwd)/target/release/wplabs-lsp" /usr/local/bin/wplabs-lsp
```

**Via cargo install** (after publishing to crates.io):

```bash
cargo install wplabs-lsp
```

Verify:

```bash
wplabs-lsp --version  # or just: which wplabs-lsp
```

### 2. Install the Zed Extension

**From Zed Extension Marketplace** (after publishing):

`Cmd+Shift+X` → search "WarpLabs" → Install

**As Dev Extension** (for development):

`Cmd+Shift+P` → "zed: install dev extension" → select `tools/zed-warplabs/`

### 3. Verify

Open any `.wfl`, `.wfs`, `.wpl`, `.oml`, or `.wfg` file. You should see:

- Syntax highlighting immediately
- LSP status "WarpLabs LSP" in the status bar
- Diagnostics (red underlines) for syntax errors
- Completions when typing

## Language Reference

### WFL — Keywords & Built-ins

**Keywords:** `use`, `rule`, `meta`, `events`, `match`, `keys`, `duration`, `on`, `event`, `close`, `score`, `entity`, `yield`, `contract`, `given`, `expect`, `derive`, `stage`, `and`, `or`, `not`, `in`, `true`, `false`, `if`, `then`, `else`, `join`, `conv`

**Aggregates:** `count`, `sum`, `avg`, `min`, `max`, `distinct`

**Functions:** `fmt`, `has`, `Now::time`, `Now::date`, `Now::hour`

**Types:** `chars`, `digit`, `float`, `bool`, `time`, `ip`, `hex`

### WFS — Keywords & Types

**Keywords:** `window`, `stream`, `time`, `over`, `fields`, `array`

**Types:** `chars`, `digit`, `float`, `bool`, `time`, `ip`, `hex`

### WPL — Keywords & Types

**Keywords:** `package`, `rule`, `field`, `metadata`, `length`, `format`, `pipe`, `separator`, `target`, `type`, `tag`, `copy_raw`, `alt`, `opt`, `some_of`, `seq`, `not`

**Types:** `chars`, `digit`, `float`, `bool`, `time`, `ip`, `hex`, `json`, `kvarr`, `http/request`, `http/status`, `http/agent`

### OML — Keywords & Pipe Functions

**Keywords:** `name`, `rule`, `read`, `take`, `pipe`, `fmt`, `object`, `collect`, `match`, `select`, `from`, `where`, `and`, `or`, `not`, `in`, `auto`, `ip`, `chars`, `digit`, `float`, `time`, `bool`, `obj`, `array`

**Pipe functions:** `to_json`, `base64_decode`, `base64_encode`, `url`, `nth`, `get`, `path`, `json_escape`, `json_unescape`, `html_unescape`, `html_escape`, `str_escape`, `to_str`, `skip_empty`, `ip4_to_int`, `Time::to_ts_ms`

### WFG — Keywords & Generator Functions

**Keywords:** `use`, `scenario`, `seed`, `time`, `duration`, `total`, `stream`, `inject`, `for`, `on`, `faults`, `oracle`, `hit`, `near_miss`, `non_hit`, `true`, `false`, `out_of_order`, `late`, `duplicate`, `drop`

**Generator functions:** `ipv4`, `pattern`, `uniform`, `choice`, `counter`, `normal`, `zipf`

## Troubleshooting

### LSP not starting

Check that `wplabs-lsp` is in your PATH:

```bash
which wplabs-lsp
```

Check Zed logs for errors: `Cmd+Shift+P` → "zed: open log"

### LSP running but no diagnostics

The LSP only reports tree-sitter parse errors (ERROR/MISSING nodes). If the file parses correctly, there will be no diagnostics — this is expected.

### Debug LSP

Run with logging enabled:

```bash
RUST_LOG=debug wplabs-lsp
```

Manual protocol test:

```bash
printf 'Content-Length: 80\r\n\r\n{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}' \
  | wplabs-lsp
```

### Grammar changes not reflected

After modifying a tree-sitter grammar:

1. `tree-sitter generate` in the grammar repo
2. `git commit` the changes
3. Update `rev` in `extension.toml` to the new commit hash
4. Reinstall the dev extension in Zed

## Project Structure

```
tools/
├── zed-warplabs/                # This Zed extension
│   ├── extension.toml           # Extension manifest
│   ├── Cargo.toml               # Rust WASM extension (for LSP integration)
│   ├── src/lib.rs               # Extension trait implementation
│   ├── languages/               # Per-language Zed configs
│   │   ├── wfl/                 # config.toml + highlights/brackets/indents/folds/outline .scm
│   │   ├── wfs/
│   │   ├── wpl/
│   │   ├── oml/
│   │   └── wfg/
│   ├── grammars/                # Pre-built WASM parsers
│   ├── snippets/                # Code snippets
│   └── examples/                # Example files for testing
│
├── wplabs-lsp/                   # Language Server binary
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs              # Stdio transport entry point
│       ├── server.rs            # tower-lsp LanguageServer implementation
│       ├── capabilities.rs      # LSP capability declarations
│       ├── dispatch.rs          # Route requests by language
│       ├── document.rs          # Document state (text + tree-sitter tree)
│       ├── util.rs              # tree-sitter ↔ LSP type helpers
│       ├── lang/                # Per-language handlers
│       │   ├── mod.rs           # LangHandler trait
│       │   ├── wfl.rs
│       │   ├── wfs.rs
│       │   ├── wpl.rs
│       │   ├── oml.rs
│       │   └── wfg.rs
│       └── features/            # LSP feature implementations
│           ├── diagnostics.rs
│           ├── completion.rs
│           ├── hover.rs
│           ├── definition.rs
│           ├── references.rs
│           ├── rename.rs
│           ├── symbols.rs
│           └── formatting.rs
│
├── tree-sitter-wfl/             # Tree-sitter grammars
├── tree-sitter-wfs/
├── tree-sitter-wpl/
├── tree-sitter-oml/
└── tree-sitter-wfg/
```

## License

Apache-2.0
