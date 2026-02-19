; WFG Syntax Highlighting for Zed
; In Zed the LAST matching pattern wins.

; ── Plain identifier (lowest priority — must be FIRST) ──
(identifier) @variable

; ── Import keyword ──
"use" @keyword.import

; ── Definition keyword ──
"scenario" @keyword

; ── Structural keywords ──
[
  "seed"
  "time"
  "duration"
  "total"
  "stream"
  "inject"
  "for"
  "on"
  "faults"
  "oracle"
] @keyword

; ── Mode keywords (hit / near_miss / non_hit) ──
(mode_keyword) @keyword.modifier

; ── Boolean literals ──
(boolean) @constant.builtin

; ── Operators ──
"=" @operator

; ── Brackets ──
[ "(" ")" "{" "}" "[" "]" ] @punctuation.bracket

; ── Delimiters ──
[ "," ";" ":" ] @punctuation.delimiter

; ── Comments ──
(comment) @comment

; ── String literals ──
(string) @string

; ── Number literals ──
(number) @number

; ── Duration literals ──
(duration) @number

; ── Rate literals (e.g. 200/s) ──
(rate) @number

; ── Percent literals (e.g. 5%) ──
(percent) @number

; ── Scenario name ──
(scenario_declaration name: (identifier) @function.definition)

; ── Scenario seed value ──
(scenario_declaration seed: (number) @number)

; ── Time clause start value ──
(time_clause start: (string) @string)
(time_clause dur: (duration) @number)

; ── Total count ──
(total_clause count: (number) @number)

; ── Stream alias and window ──
(stream_block
  alias: (identifier) @variable
  window: (identifier) @type)

; ── Stream rate ──
(stream_block rate: (rate) @number)

; ── Field override name ──
(field_override name: (field_name (identifier) @property))
(field_override name: (field_name (quoted_identifier) @property))

; ── Gen function name ──
(gen_func function: (identifier) @function.builtin)

; ── Named argument key ──
(named_arg key: (identifier) @property)

; ── Inject rule target ──
(inject_block rule: (identifier) @function)

; ── Stream list identifiers ──
(stream_list (identifier) @variable)

; ── Inject line percent ──
(inject_line percent: (percent) @number)

; ── Param assignment key ──
(param_assign key: (identifier) @property)

; ── Fault name ──
(fault_line name: (identifier) @variable)

; ── Fault percent ──
(fault_line percent: (percent) @number)
