; GXL Syntax Highlighting for Zed
; In Zed the LAST matching pattern wins.

; ── Plain identifier (lowest priority — must be FIRST) ──
(identifier) @variable

; ── Keywords ──
[
  "mod"
  "env"
  "flow"
  "fn"
  "activity"
  "extern"
] @keyword

; ── Keyword operators ──
"@" @keyword

; ── Property keywords in extern module ──
[
  "path"
  "git"
  "channel"
] @keyword

; ── Operators ──
["=" "|" ":" "*"] @operator

; ── Brackets ──
["(" ")" "{" "}"] @punctuation.bracket

; ── Annotation delimiters ──
"#[" @punctuation.special
"]" @punctuation.bracket

; ── Delimiters ──
["," ";"] @punctuation.delimiter

; ── Comments ──
(comment) @comment

; ── String literals ──
(string) @string

; ── Number literals ──
(number) @number

; ── Annotations ──
(annotation
  name: (identifier) @attribute)

(annotation_arg
  key: (identifier) @attribute)

(annotation_arg
  (string) @string)

; ── Module definition ──
(module
  name: (identifier) @type.definition)

; ── Module ref list ──
(module
  (ref_list (identifier) @type))

; ── Extern module name ──
(extern_module
  name: (identifier) @type)

; ── Environment name ──
(environment
  name: (identifier) @type.definition)

(environment
  (ref_list (identifier) @type))

; ── Flow definition name ──
(flow_definition
  name: (identifier) @function.definition)

(flow_definition
  (ref_list (identifier) @function))

; ── Flow reference name ──
(flow_reference
  name: (identifier) @function)

(flow_reference
  (ref_list (identifier) @function))

; ── Function definition name ──
(function_def
  name: (identifier) @function.definition)

; ── Function parameter ──
(function_param
  name: (identifier) @variable.parameter)

(function_param
  default: (string) @string)

; ── Activity name ──
(activity
  name: (identifier) @type.definition)

; ── Built-in command name (gx.echo, gx.cmd, etc.) ──
(builtin_name) @function.builtin

; ── gx.vars block keyword ──
"gx.vars" @function.builtin

; ── Call expression target ──
(call_expression
  target: (dotted_name) @function)

(call_expression
  target: (identifier) @function)

; ── Command prop key ──
(command_prop
  key: (identifier) @property)

(command_prop
  value: (identifier) @variable)

; ── Property key/value ──
(property
  key: (identifier) @property)

; ── Path/git source ──
(path_source (string) @string)
(git_source (string) @string)
