# Phase 9 — Inline Modifiers

## Goal
Add inline flag modifiers `(?i)` `(?-i)` `(?s)` `(?m)` `(?x)` (and combinations
like `(?im)`) that change matching behaviour mid-pattern. Flags affect only the
sub-pattern to their right within the same group scope. This is the most
architecturally complex phase because it requires threading mutable flag state
through the compiler during AST traversal.

## Package
`Regex-Backtracking`

---

## Flag Reference

| Flag | Name       | Effect |
|------|------------|--------|
| `i`  | ignoreCase | Case-insensitive matching (`a` = `A`) |
| `s`  | dotall     | `.` matches any character including `\n` (newline) |
| `m`  | multiline  | `^` / `$` match at embedded newlines, not just string start/end |
| `x`  | extended   | Unescaped whitespace and `#...` comments ignored in pattern |

Modifiers may be combined: `(?im)`. Negation: `(?-i)` turns off `i`.
Mixed: `(?i-m)` turns on `i`, turns off `m`.

Scoping: `(?flags)` changes flags for the rest of the enclosing group.
`(?flags:...)` (non-capturing group with flags) scopes flags to the group only.

---

## Architecture

### Why a Flags Object

Currently `ignoreCase` is a single boolean closed over at compile time. Phase 9
requires four orthogonal flags that can change mid-compilation. The solution is
a `RxbtFlags` value object carried by `RxbtCompiler` and passed down the AST
traversal. Each `syntaxInlineModifier:` call returns a new `RxbtFlags` and the
compiler uses it for all subsequent nodes in scope.

Key constraint: `RxbtCompiler` must NOT become a god object. Flags are
encapsulated in `RxbtFlags`; the compiler holds one `flags` reference and
replaces it on scope entry/exit.

### Flag Scoping

`(?flags)` at the top level of a group resets flags for the remainder of that
group. To implement scope, `RxbtCompiler` uses a save/restore pattern:

```
enter scoped group:
    savedFlags := flags.
    flags := flags with: newFlagSettings.
    compile inner.
    flags := savedFlags.    "restore on exit"
```

This naturally handles nesting because each recursive compiler call sees the
correct `flags` for its scope depth.

---

## New Class: RxbtFlags

```smalltalk
(Object << #RxbtFlags
    slots: #(ignoreCase dotall multiline extended);
    package: 'Regex-Backtracking') install.

RxbtFlags comment: 'Immutable value object holding active regex flags during
compilation. Created by RxbtCompiler; passed down the AST to make each syntax*:
method flag-aware without adding flag parameters to every method.
Flags: ignoreCase (i), dotall (s), multiline (m), extended (x).'.

RxbtFlags compile: 'ignoreCase ^ignoreCase' classified: 'accessing'.
RxbtFlags compile: 'dotall     ^dotall'     classified: 'accessing'.
RxbtFlags compile: 'multiline  ^multiline'  classified: 'accessing'.
RxbtFlags compile: 'extended   ^extended'   classified: 'accessing'.

RxbtFlags compile: 'ignoreCase: i dotall: s multiline: m extended: x
    ignoreCase := i.
    dotall     := s.
    multiline  := m.
    extended   := x' classified: 'initialize'.

RxbtFlags compile: 'withIgnoreCase: i
    "Return a copy with ignoreCase changed."
    ^RxbtFlags new
        ignoreCase: i
        dotall:     dotall
        multiline:  multiline
        extended:   extended' classified: 'copying'.

RxbtFlags compile: 'withDotall: s
    ^RxbtFlags new
        ignoreCase: ignoreCase
        dotall:     s
        multiline:  multiline
        extended:   extended' classified: 'copying'.

RxbtFlags compile: 'withMultiline: m
    ^RxbtFlags new
        ignoreCase: ignoreCase
        dotall:     dotall
        multiline:  m
        extended:   extended' classified: 'copying'.

RxbtFlags compile: 'withExtended: x
    ^RxbtFlags new
        ignoreCase: ignoreCase
        dotall:     dotall
        multiline:  multiline
        extended:   x' classified: 'copying'.

RxbtFlags compile: 'applySet: setString clear: clearString
    "Return new flags after applying (?setString-clearString) modifier.
     setString and clearString are strings of flag letters."
    | f |
    f := self.
    setString do: [:ch |
        ch = $i ifTrue: [f := f withIgnoreCase: true].
        ch = $s ifTrue: [f := f withDotall: true].
        ch = $m ifTrue: [f := f withMultiline: true].
        ch = $x ifTrue: [f := f withExtended: true]].
    clearString do: [:ch |
        ch = $i ifTrue: [f := f withIgnoreCase: false].
        ch = $s ifTrue: [f := f withDotall: false].
        ch = $m ifTrue: [f := f withMultiline: false].
        ch = $x ifTrue: [f := f withExtended: false]].
    ^f' classified: 'operations'.
```

Class-side constructor:

```smalltalk
RxbtFlags compile: 'default
    "All flags off."
    ^self new
        ignoreCase: false
        dotall:     false
        multiline:  false
        extended:   false' classified: 'instance creation'.

RxbtFlags compile: 'caseInsensitive
    "Convenience — only ignoreCase on."
    ^self new
        ignoreCase: true
        dotall:     false
        multiline:  false
        extended:   false' classified: 'instance creation'.
```

---

## New AST Node: RxsInlineModifier

```smalltalk
(RxsNode << #RxsInlineModifier
    slots: #(setFlags clearFlags inner);
    package: 'Regex-Backtracking') install.

RxsInlineModifier comment: 'AST node for inline flag modifiers.
setFlags and clearFlags are Strings of flag letters (e.g. ''im'' and ''s'').
inner is nil for bare (?flags) — changes flags for rest of enclosing group.
inner is an RxsRegex node for (?flags:...) — scoped non-capturing group.
RxbtCompiler applies flags to subsequent compilation or inner, then restores.'.

RxsInlineModifier compile: 'setFlags   ^setFlags'   classified: 'accessing'.
RxsInlineModifier compile: 'clearFlags ^clearFlags' classified: 'accessing'.
RxsInlineModifier compile: 'inner      ^inner'      classified: 'accessing'.
RxsInlineModifier compile: 'setFlags: s clearFlags: c
    setFlags   := s.
    clearFlags := c.
    inner      := nil' classified: 'initialize'.
RxsInlineModifier compile: 'inner: aNode
    inner := aNode' classified: 'initialize'.
RxsInlineModifier compile: 'isScoped
    "true if this modifier has a scoped inner pattern (?flags:...)"
    ^inner notNil' classified: 'testing'.
RxsInlineModifier compile: 'isNullable ^true' classified: 'testing'.
RxsInlineModifier compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxInlineModifier: self' classified: 'double dispatch'.
```

---

## RxbtCompiler Changes

### Add `flags` ivar

```smalltalk
(Object << #RxbtCompiler
    slots: #(matcher ignoreCase markerCount groupMap flags);
    package: 'Regex-Backtracking') install.
```

Update `initializeFor:ignoreCase:`:

```smalltalk
initializeFor: aMatcher ignoreCase: aBoolean
    matcher     := aMatcher.
    ignoreCase  := aBoolean.
    markerCount := 0.
    groupMap    := IdentityDictionary new.
    flags       := aBoolean
        ifTrue:  [RxbtFlags caseInsensitive]
        ifFalse: [RxbtFlags default]
```

Add accessor:

```smalltalk
flags ^flags
```

### Update Flag-Sensitive syntax Methods

All methods that currently check `ignoreCase` directly must now consult `flags`:

**`syntaxCharacter:`** — replace `ignoreCase` with `flags ignoreCase`:

```smalltalk
syntaxCharacter: charNode
    | flagsAtCompileTime |
    flagsAtCompileTime := flags.
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos <= str size and: [
            flagsAtCompileTime ignoreCase
                ifTrue:  [(str at: pos) asLowercase = charNode character asLowercase]
                ifFalse: [(str at: pos) = charNode character]])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
```

Note: `flagsAtCompileTime` is captured at compile time (not read from `flags`
ivar at match time). This is intentional — flags are scoped to their lexical
position in the pattern, not the match-time state.

**`syntaxAny`** — dotall mode makes `.` match `\n`:

```smalltalk
syntaxAny
    | dotallAtCompileTime |
    dotallAtCompileTime := flags dotall.
    ^[:pos :cont |
        | str ch |
        str := matcher inputString.
        pos <= str size
            ifTrue: [
                ch := str at: pos.
                (dotallAtCompileTime or: [(ch value) ~= 0 and: [(ch value) ~= 10]])
                    ifTrue: [cont value: pos + 1]
                    ifFalse: [false]]
            ifFalse: [false]]
```

(Original excluded only null (0); dotall also includes LF (10) in allowed chars.)

**`syntaxBeginningOfLine` / `syntaxEndOfLine`** — multiline mode:

```smalltalk
syntaxBeginningOfLine
    | multilineAtCompileTime |
    multilineAtCompileTime := flags multiline.
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos = 1 or: [
            multilineAtCompileTime and: [
                pos > 1 and: [(str at: pos - 1) = (Character value: 10)]]])
            ifTrue: [cont value: pos]
            ifFalse: [false]]

syntaxEndOfLine
    | multilineAtCompileTime |
    multilineAtCompileTime := flags multiline.
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos > str size or: [
            (str at: pos) = (Character value: 10) or: [
                multilineAtCompileTime and: [(str at: pos) = (Character value: 10)]]])
            ifTrue: [cont value: pos]
            ifFalse: [false]]
```

**`syntaxCharSet:`** — case-insensitive charset matching:

```smalltalk
syntaxCharSet: node
    | ignoreCaseAtCompileTime |
    ignoreCaseAtCompileTime := flags ignoreCase.
    ^[:pos :cont |
        | str ch |
        str := matcher inputString.
        pos <= str size
            ifTrue: [
                ch := str at: pos.
                (ignoreCaseAtCompileTime
                    ifTrue:  [node predicateIgnoringCase: ch]
                    ifFalse: [node predicate: ch])
                    ifTrue:  [cont value: pos + 1]
                    ifFalse: [false]]
            ifFalse: [false]]
```

### New Method: syntaxInlineModifier:

```smalltalk
syntaxInlineModifier: node
    "Compile inline flag modifier. Two forms:
     - Bare (?flags): affects rest of enclosing group — compiled as zero-width
       assertion that side-effects the compiler's flags state for subsequent nodes.
       Returns a block that always succeeds (zero-width).
     - Scoped (?flags:...): scopes flags to inner pattern, then restores."
    | savedFlags newFlags |
    savedFlags := flags.
    newFlags := flags applySet: node setFlags clear: node clearFlags.
    node isScoped
        ifTrue: [
            | innerBlock |
            flags := newFlags.
            innerBlock := node inner dispatchTo: self.
            flags := savedFlags.
            ^innerBlock]
        ifFalse: [
            "Bare modifier: side-effect flags for subsequent compilation.
             At runtime, zero-width success."
            flags := newFlags.
            ^[:pos :cont | cont value: pos]]
```

**Important:** For bare `(?flags)`, the side-effect on `flags` happens at
compile time (when `syntaxInlineModifier:` is called during AST traversal).
The runtime block is always zero-width. This is correct because flag effects
are baked into the closures of subsequent nodes at compile time.

---

## Parser Changes

### Extended Mode Preprocessing

For `(?x)`, whitespace and `#...` comments in the pattern should be stripped
before parsing. The cleanest approach: when `extended` is active, preprocess
the pattern in `RxParser` before the normal token stream.

Add `RxParser>>stripExtendedWhitespace:` (in `Regex-Backtracking` category):

```smalltalk
stripExtendedWhitespace: aString
    "Remove unescaped whitespace and # comments from aString.
     Called when the (?x) flag is active for a pattern segment."
    | result i ch |
    result := WriteStream on: String new.
    i := 1.
    [i <= aString size] whileTrue: [
        ch := aString at: i.
        ch = $\
            ifTrue: [
                result nextPut: ch.
                i := i + 1.
                i <= aString size ifTrue: [
                    result nextPut: (aString at: i).
                    i := i + 1]]
            ifFalse: [
                (ch = $# )
                    ifTrue: [
                        [i <= aString size and: [(aString at: i) ~= (Character value: 10)]]
                            whileTrue: [i := i + 1]]
                    ifFalse: [
                        (ch isSeparator)
                            ifFalse: [result nextPut: ch].
                        i := i + 1]]].
    ^result contents
```

Note: full `(?x)` preprocessing on the entire pattern string is complex
(flags are not known until parsing). A pragmatic approach for Phase 9:
parse `(?x)` as a modifier node; in `RxbtCompiler`, when `extended` is on,
skip whitespace and `#` comments in `syntaxCharacter:` (reject space/tab/`#`
as literals). The alternative — full preprocessing — requires a two-pass parser.

Recommended: implement extended mode as a compile-time filter. Add a flag-check
in `syntaxCharacter:` that rejects whitespace as zero-width match:

```smalltalk
syntaxCharacter: charNode
    | flagsAtCompileTime ch |
    flagsAtCompileTime := flags.
    ch := charNode character.
    (flagsAtCompileTime extended and: [ch isSeparator]) ifTrue: [
        ^[:pos :cont | cont value: pos]].   "whitespace = zero-width in extended mode"
    ^[:pos :cont |
        ...rest of syntaxCharacter:...]
```

This is a simplification — full `(?x)` with `#` comments requires parser-level
changes. Document the limitation.

### New `inlineModifier` Parser Method

Add to `RxParser` (in `Regex-Backtracking` category):

```smalltalk
inlineModifier
    "Parse (?flags) or (?flags:...) after ( and ? have been consumed.
     Returns RxsInlineModifier. lookahead is currently a flag letter or -."
    | setFlags clearFlags node |
    setFlags   := WriteStream on: String new.
    clearFlags := WriteStream on: String new.
    "Collect set-flags (before optional -)"
    [lookahead notNil and: ['imsxIMSX' includes: lookahead]] whileTrue: [
        setFlags nextPut: lookahead asLowercase.
        self next].
    "Optional - followed by clear-flags"
    lookahead = $-
        ifTrue: [
            self next.    "consume -"
            [lookahead notNil and: ['imsxIMSX' includes: lookahead]] whileTrue: [
                clearFlags nextPut: lookahead asLowercase.
                self next]].
    node := RxsInlineModifier new
        setFlags:   setFlags contents
        clearFlags: clearFlags contents.
    "Check for scoped form (?flags:...)"
    lookahead = $:
        ifTrue: [
            self next.    "consume :"
            node inner: self regex].
    ^node
```

### Update `atom` `(?` Dispatch

In the `RxParser>>atom` monkey-patch, inside the `(?` branch, add `inlineModifier`
detection. The dispatch order becomes:

```
1. lookahead = $>    → atomic group (?>...)
2. lookahead = $:    → non-capturing group (?:...)
3. lookahead = $<    → lookbehind (?<=...) / (?<!...) or named capture (?<name>...)
4. lookahead = $=    → lookahead (?=...)
5. lookahead = $!    → negative lookahead (?!...)
6. lookahead is flag letter ($i $m $s $x $I $M $S $X) or $-  → inlineModifier
7. otherwise → signalParseError: 'unknown (? sequence'
```

Add case 6 to the `(?` dispatch:

```smalltalk
(('imsxIMSX' includes: lookahead) or: [lookahead = $-])
    ifTrue: [
        atom := self inlineModifier.
        (lookahead = $)) ifTrue: [self next].   "consume ) if bare (?flags)"
        ^atom].
```

Note: scoped `(?flags:...)` consumes its own `)` via `self match: $)` inside `inlineModifier`.
Bare `(?flags)` needs the `)` consumed after returning.

---

## RxbtMatcher API Change

Add `forString:ignoreCase:` and a dotall/multiline constructor for completeness.
The primary entry point stays `forString:` and `forString:ignoreCase:`, but
`(?flags)` inline modifiers now override the initial setting mid-pattern:

```smalltalk
RxbtMatcher compile: 'forString: aString withFlags: aFlagsString
    "Convenience — parse flag string (e.g. ''im'') and compile."
    | flags ignCase dotall multiline |
    ignCase   := aFlagsString includes: $i.
    dotall    := aFlagsString includes: $s.
    multiline := aFlagsString includes: $m.
    ^self new
        compileRegex: aString
        ignoreCase: ignCase
        dotall: dotall
        multiline: multiline' classified: 'instance creation'.
```

Update `RxbtMatcher>>initialize:ignoreCase:` to accept a flags object or
extend to `initialize:flags:`:

```smalltalk
initialize: syntaxTreeRoot flags: aRxbtFlags
    | compiler |
    ignoreCase := aRxbtFlags ignoreCase.
    groupNames := nil.
    compiler := RxbtCompiler for: self flags: aRxbtFlags.
    rootBlock := compiler compile: syntaxTreeRoot.
    markerCount := compiler markerCount.
    captures := Array new: markerCount withAll: nil
```

Add `RxbtCompiler class>>for:flags:`:

```smalltalk
for: aMatcher flags: aRxbtFlags
    ^self new initializeFor: aMatcher flags: aRxbtFlags

initializeFor: aMatcher flags: aRxbtFlags
    matcher     := aMatcher.
    ignoreCase  := aRxbtFlags ignoreCase.
    markerCount := 0.
    groupMap    := IdentityDictionary new.
    flags       := aRxbtFlags
```

Keep `for:ignoreCase:` as a compatibility wrapper:

```smalltalk
for: aMatcher ignoreCase: aBoolean
    ^self for: aMatcher flags: (aBoolean
        ifTrue:  [RxbtFlags caseInsensitive]
        ifFalse: [RxbtFlags default])
```

---

## Test Class

```smalltalk
(TestCase << #RxbtInlineModifierTest
    slots: #();
    package: 'Regex-Backtracking-Tests') install.

RxbtInlineModifierTest comment: 'Tests for inline flag modifiers (?i), (?s), (?m), (?x)
in RxbtMatcher. Flags are lexically scoped: (?flags) affects the rest of the enclosing
group; (?flags:...) scopes flags to the inner pattern only.
Note: (?x) extended mode strips unescaped whitespace — tested via compile-time filter.'.
```

## Test Cases

```smalltalk
testIgnoreCaseModifier
    "(?i) makes subsequent pattern case-insensitive."
    | m |
    m := RxbtMatcher forString: '(?i)hello'.
    self assert: (m matches: 'Hello').
    self assert: (m matches: 'HELLO').
    self deny:   (m matches: 'world').

testIgnoreCaseScoped
    "(?i:...) scopes case-insensitivity to inner pattern."
    | m |
    m := RxbtMatcher forString: '(?i:foo)bar'.
    self assert: (m matches: 'FOObar').
    self deny:   (m matches: 'FOOBAR').

testIgnoreCaseTurnOff
    "(?-i) turns off case-insensitive matching."
    | m |
    m := RxbtMatcher forString: '(?i)FOO(?-i)bar'.
    self assert: (m matches: 'foobar').
    self deny:   (m matches: 'fooBAR').

testDotallModifier
    "(?s) makes . match newlines."
    | m |
    m := RxbtMatcher forString: '(?s)a.b'.
    self assert: (m matches: 'a' , (String with: (Character value: 10)) , 'b').
    self deny:   ((RxbtMatcher forString: 'a.b') matches:
        'a' , (String with: (Character value: 10)) , 'b').

testMultilineModifier
    "(?m) makes ^ and $ match at embedded newlines."
    | m str |
    str := 'line1' , (String with: (Character value: 10)) , 'line2'.
    m := RxbtMatcher forString: '(?m)^line2'.
    self assert: (m search: str).

testMultilineCaretAtStart
    "Without (?m), ^ matches only at absolute start."
    | m str |
    str := 'line1' , (String with: (Character value: 10)) , 'line2'.
    m := RxbtMatcher forString: '^line2'.
    self deny: (m search: str).

testExtendedModeWhitespace
    "(?x) — unescaped spaces ignored in pattern."
    | m |
    m := RxbtMatcher forString: '(?x) h e l l o'.
    self assert: (m matches: 'hello').

testCombinedModifiers
    "(?im) combines ignoreCase and multiline."
    | m str |
    str := 'Line1' , (String with: (Character value: 10)) , 'LINE2'.
    m := RxbtMatcher forString: '(?im)^line2'.
    self assert: (m search: str).

testModifierDoesNotLeakOutOfGroup
    "(?i) inside a group does not affect outer pattern."
    | m |
    m := RxbtMatcher forString: '((?i)foo)bar'.
    self assert: (m matches: 'FOObar').
    "Bar still case-sensitive (modifier scoped to group)"
    self deny:   (m matches: 'FOOBAR').
```

---

## Acceptance Criteria

```smalltalk
RxbtInlineModifierTest suite run printString.   "all pass"
RxbtMatcherTest        suite run printString.   "176/176 — no regression"
```

---

## Pitfalls

- **Flags captured at compile time, not match time.** `syntaxCharacter:` and
  other flag-sensitive methods must snapshot `flags` into a local before building
  the closure: `| f | f := flags. ^[:pos :cont | f ignoreCase ifTrue: [...]]`.
  If they close over the `flags` ivar directly, every closure will see the
  *current* (post-compilation) flag state — always the last modifier encountered.

- **Bare `(?flags)` vs scoped `(?flags:...)`**: The parser returns the same node
  type; the distinction is `inner notNil`. In `atom`, bare form consumes `)` after
  `inlineModifier` returns. Scoped form consumes `)` inside `inlineModifier` via
  `self regex` + implicit `match: $)`. Guard against double-consuming `)`.

- **`(?x)` full implementation requires two-pass parsing.** Pattern like
  `(?x)  \d + \s*` has meaningful characters interleaved with spaces. A full
  implementation strips whitespace from the token stream before atomization.
  The simplified compile-time filter (whitespace chars become zero-width) handles
  simple cases but will mishandle `\  ` (escaped space). Document: `(?x)` in
  Phase 9 strips unescaped whitespace at compile time; escaped spaces `\ ` still
  match literal space.

- **`(?x)` and `#` comments.** `stripExtendedWhitespace:` is provided but not
  automatically invoked since the parser does not know flags before parsing. Two
  approaches: (1) require user to pre-strip via `stripExtendedWhitespace:`, or
  (2) implement a two-pass: parse once to collect flag positions, then re-parse
  with whitespace stripped in extended regions. Phase 9 implements approach (1)
  for simplicity; approach (2) is left as a future enhancement.

- **`RxbtFlags` is immutable (value object).** `applySet:clear:` returns a NEW
  instance. Never mutate an existing `RxbtFlags` — other closures may hold references
  to it. The save/restore pattern in `syntaxInlineModifier:` works correctly only
  because `savedFlags` holds the original immutable instance.

- **`RxbtCompiler` backward compatibility.** The `for:ignoreCase:` factory is kept
  as a wrapper around `for:flags:`. All existing call sites (`RxbtMatcher>>initialize:ignoreCase:`)
  continue to work without change.

- **`(?m)` multiline and `\A`/`\Z`/`\z` (Phase 8).** Absolute anchors are explicitly
  NOT affected by `(?m)`. `\A` always matches only at position 1; `(?m)` affects only
  `^` and `$`. Ensure the multiline check in `syntaxBeginningOfLine` does not bleed
  into `syntaxBeginningOfString`.
