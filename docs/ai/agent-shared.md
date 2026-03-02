# Agent Shared Playbook

This file contains repository rules intended to work for multiple AI coding assistants.

## Scope

- Repository: `zed-warplabs`
- Primary goals: keep grammar/language queries/LSP behavior in sync; avoid regressions.

## Required Workflow

1. Read `README.md` and `DEVELOPMENT.md` for current workflows.
2. Prefer minimal, focused diffs; do not touch unrelated files.
3. Before editing, check current changes with `git status --short`.
4. If unexpected external changes appear during your work, stop and ask the user.

## Grammar + Query Sync Rules (Important)

When changing any grammar under `grammars/<lang>/`:

1. Regenerate grammar artifacts (`tree-sitter generate`).
2. Parse examples under `examples/<lang>/*.<lang>`.
3. Manually sync query files under `languages/<lang>/`:
   - `highlights.scm`
   - `indents.scm`
   - `folds.scm`
   - `outline.scm` (if affected)
4. Keep examples in `examples/<lang>/` valid for the current grammar.
5. If grammar repo revision changed, update `[grammars.<lang>].rev` in `extension.toml`.
6. Run compatibility checks:
   - `CHECK_LANGS=<lang> bash scripts/check-grammar-highlights.sh`

## Validation Expectations

- Run the smallest relevant checks first.
- If full checks cannot run, clearly report what was not verified.

## Editing Guardrails

- Keep files ASCII unless the file already requires Unicode.
- Add comments only where they materially improve readability.
- Never revert user changes you did not make unless explicitly asked.

