# Phase 13 — Quick Wins: Comments, \K, POSIX Classes

## Goal

Three small, independent additions that cover common real-world patterns with
minimal implementation cost. No new quantifier logic, no backtracking changes.

| Feature | Syntax | Complexity |
|---------|--------|-----------|
| Inline comments | `(?#text)` | Trivial — parser skip, returns `RxbtEpsilon` |
| Keep-start reset | `\K` | One node, one compiler method |
| POSIX character classes | `[[:alpha:]]` etc. | Extend `RxbtCharSetParser` |

## Package

`Regex-Backtracking`

---

## Part A — Inline Comments `(?#...)`

### Behaviour

`(?#comment text)` is a zero-width no-op. The comment text is discarded at
parse time. The result is equivalent to an empty match — `RxbtEpsilon`.

### Parser Change

In `RxbtParser>>atom`, in the `(?` branch (where lookaheads and groups are
dispatched), add BEFORE the existing checks:

```smalltalk
"At the point where we have consumed ( and peeked ?"
lookahead = $# ifTrue: [
    [self atEnd or: [self peek = $)]] whileFalse: [self next].
    self atEnd ifFalse: [self next].   "consume )"
    ^RxbtEpsilon new].
```

Place this check immediately after `self next` consumes the `?` character,
before the `=`, `!`, `<`, `>`, `:`, `i`, `s`, `m`, `x` checks.

### No New Classes

`RxbtEpsilon` already exists and `syntaxEpsilon` is already implemented in
`RxbtCompiler` (returns `[:pos :cont | cont value: pos]`).

### Optimizer

`syntaxEpsilon` in `RxbtMatchOptimizer` already exists (no-op). No change.

---

## Part B — Keep-Start Reset `\K`

### Behaviour

`\K` is a zero-width assertion that resets the reported start of the match to
the current position. Everything matched before `\K` is consumed (advances the
engine) but excluded from the reported match string.

```
'foobar' =~ /foo\Kbar/   → matches, subexpression 1 = 'bar' (not 'foobar')
```

### How It Works in the CPS Model

`RxbtMatcher`'s capture array stores the root group's begin marker at index 1.
`subexpression: 1` returns `str copyFrom: (captures at: 1) to: (captures at: 2) - 1`.
`\K` simply overwrites `captures at: 1` with the current position:

```smalltalk
syntaxKeepStart
    ^[:pos :cont |
        matcher captures at: 1 put: pos.
        cont value: pos]
```

`syntaxRegex:` sets `captures at: startIdx put: startPos` at the entry of each
attempt, then does NOT overwrite it again on success — so `\K`'s write persists.

### New Node

```smalltalk
(RxbtNode << #RxbtKeepStart)
    slots: {};
    tag: 'Nodes';
    package: 'Regex-Backtracking';
    install.

RxbtKeepStart comment: 'AST node for \K (keep-start reset).
Zero-width — resets the reported match start to the current position.
Everything before \K is consumed but excluded from subexpression: 1.'.

RxbtKeepStart compile: 'isNullable ^true' classified: 'testing'.
RxbtKeepStart compile: 'dispatchTo: aCompiler ^aCompiler syntaxKeepStart'
    classified: 'double dispatch'.
```

### Parser Change

In `RxbtParser>>atom`, in the `\` section, after the `\A`, `\z`, `\Z`, `\R`
checks and BEFORE the digit backreference handler:

```smalltalk
lookahead = $K ifTrue: [self next. ^RxbtKeepStart new].
```

### Compiler Method

```smalltalk
syntaxKeepStart
    ^[:pos :cont |
        matcher captures at: 1 put: pos.
        cont value: pos]
```

No `matcher incrementStep` — `\K` is structural, not an atom check.

### Optimizer Method

```smalltalk
syntaxKeepStart
    "Zero-width — nothing to collect."
```

### Pitfall: Interaction with `searchStream:`

`searchStream:` resets `captures := Array new: markerCount withAll: nil` before
each `rootBlock` call. The `syntaxRegex:` closure then writes `captures at: 1
put: pos` (the candidate start). `\K` overwrites this mid-match. On match
success, `captures at: 1` = the `\K` position. `subexpression: 1` then reports
from the `\K` position. This is correct.

If the match fails (cont returns false), `syntaxRegex:` restores `captures at:
1` to its saved value — the `\K` write is undone correctly.

---

## Part C — POSIX Character Classes `[[:alpha:]]`

### Behaviour

Inside `[...]`, `[:name:]` denotes a POSIX character class:

| Class | Meaning |
|-------|---------|
| `[:alpha:]` | Letters (`isLetter`) |
| `[:digit:]` | Decimal digits (`isDigit`) |
| `[:alnum:]` | Letters or digits |
| `[:space:]` | Whitespace (`isSeparator`) |
| `[:blank:]` | Space and tab only |
| `[:upper:]` | Uppercase letters |
| `[:lower:]` | Lowercase letters |
| `[:punct:]` | Punctuation (printing, non-alnum, non-space) |
| `[:print:]` | Printable characters (including space) |
| `[:graph:]` | Visible characters (printing, excluding space) |
| `[:cntrl:]` | Control characters (value < 32 or = 127) |
| `[:xdigit:]` | Hexadecimal digits (`0-9 A-F a-f`) |
| `[:word:]` | Word chars: letters, digits, underscore (non-POSIX extension) |

### Implementation

`RxbtCharSetParser` parses the content of `[...]`. When it encounters `[` followed
by `:`, it reads a POSIX class name until `:]`.

Check the existing `RxbtCharSetParser` source for where single characters and
ranges are parsed, then add POSIX class detection there:

```smalltalk
"In RxbtCharSetParser — where elements are parsed:"
self peek = $[ ifTrue: [
    "Possible POSIX class [:name:]"
    self next.   "consume ["
    self peek = $: ifTrue: [
        self next.   "consume :"
        | name |
        name := self readPosixClassName.
        ^self posixPredicateFor: name]
    ifFalse: [
        "Literal [ — treat as character"
        ^RxbtCharacter new initializeCharacter: $[]].
```

Add two helper methods on `RxbtCharSetParser`:

```smalltalk
readPosixClassName
    | name |
    name := String new.
    [self atEnd or: [self peek = $:]] whileFalse: [
        name := name , (String with: self next)].
    (self atEnd not and: [self peek = $:]) ifTrue: [self next].  "consume :"
    (self atEnd not and: [self peek = $]]) ifTrue: [self next].  "consume ]"
    ^name

posixPredicateFor: name
    | pred |
    pred := RxbtPredicate new.
    name = 'alpha'  ifTrue: [pred beAlphabetic.   ^pred].
    name = 'digit'  ifTrue: [pred beDigit.        ^pred].
    name = 'alnum'  ifTrue: [pred beAlphaNumeric. ^pred].
    name = 'space'  ifTrue: [pred beSpace.        ^pred].
    name = 'blank'  ifTrue: [
        pred predicate: [:c | c = (Character value: 32) or: [c = (Character value: 9)]].
        ^pred].
    name = 'upper'  ifTrue: [pred beUppercase.    ^pred].
    name = 'lower'  ifTrue: [pred beLowercase.    ^pred].
    name = 'punct'  ifTrue: [pred bePunctuation.  ^pred].
    name = 'print'  ifTrue: [pred bePrintable.    ^pred].
    name = 'graph'  ifTrue: [pred beGraphics.     ^pred].
    name = 'cntrl'  ifTrue: [pred beControl.      ^pred].
    name = 'xdigit' ifTrue: [pred beHexDigit.     ^pred].
    name = 'word'   ifTrue: [pred beWordConstituent. ^pred].
    "Unknown class — treat as empty predicate (never matches)"
    pred predicate: [:c | false].
    ^pred
```

`RxbtPredicate` already has all of these `be*` methods. `predicate:` may need
to be added as a simple setter if not present:

```smalltalk
RxbtPredicate compile: 'predicate: aBlock
    predicate := aBlock.
    negation  := [:c | (aBlock value: c) not]'
classified: 'initialization'.
```

The `RxbtPredicate` returned by `posixPredicateFor:` is added to the charset
elements collection in `RxbtCharSetParser`, and `RxbtCharSet>>predicateIgnoringCase:`
already handles predicates within the element list — so charset compilation
requires no further changes.

---

## Test Class

```smalltalk
(TestCase << #RxbtQuickWinsTest)
    slots: {};
    tag: 'Tests';
    package: 'Regex-Backtracking-Tests';
    install.

RxbtQuickWinsTest comment: 'Tests for Phase 13 quick wins:
(?#comment) inline comments, \K keep-start, and POSIX character classes.'.
```

## Test Cases

```smalltalk
"--- (?#comment) ---"

testInlineCommentIgnored
    | m |
    m := RxbtMatcher forString: 'foo(?#this is a comment)bar'.
    self assert: (m matches: 'foobar').

testInlineCommentInAlternation
    | m |
    m := RxbtMatcher forString: 'foo(?#note)|baz'.
    self assert: (m search: 'baz').

"--- \K keep-start ---"

testKeepStartBasic
    | m |
    m := RxbtMatcher forString: 'foo\Kbar'.
    self assert: (m search: 'foobar').
    self assert: (m subexpression: 1) = 'bar'.

testKeepStartWithSearch
    "Match advances past 'prefix' but reports only 'bar'."
    | m |
    m := RxbtMatcher forString: '\w+\K\d+'.
    self assert: (m search: 'abc123').
    self assert: (m subexpression: 1) = '123'.

testKeepStartNoMatch
    | m |
    m := RxbtMatcher forString: 'foo\Kbar'.
    self deny: (m search: 'foobaz').

"--- POSIX classes ---"

testPosixAlpha
    | m |
    m := RxbtMatcher forString: '[[:alpha:]]+'.
    self assert: (m matches: 'hello').
    self deny:   (m matches: '123').

testPosixDigit
    | m |
    m := RxbtMatcher forString: '[[:digit:]]+'.
    self assert: (m matches: '42').
    self deny:   (m matches: 'abc').

testPosixAlnum
    | m |
    m := RxbtMatcher forString: '[[:alnum:]]+'.
    self assert: (m matches: 'abc123').
    self deny:   (m matches: '!@#').

testPosixSpace
    | m |
    m := RxbtMatcher forString: '[[:space:]]+'.
    self assert: (m matches: ' ').
    self assert: (m matches: (String with: (Character value: 9))).  "tab"
    self deny:   (m matches: 'a').

testPosixUpper
    | m |
    m := RxbtMatcher forString: '[[:upper:]]+'.
    self assert: (m matches: 'ABC').
    self deny:   (m matches: 'abc').

testPosixNegated
    "[^[:digit:]] — non-digit"
    | m |
    m := RxbtMatcher forString: '[^[:digit:]]+'.
    self assert: (m matches: 'abc').
    self deny:   (m matches: '123').

testPosixMixedWithLiteral
    "[[:alpha:]0-9] combines POSIX class with explicit range"
    | m |
    m := RxbtMatcher forString: '[[:alpha:]0-9]+'.
    self assert: (m matches: 'abc123').

testRegressionFull
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty.
```

---

## Acceptance Criteria

```smalltalk
RxbtQuickWinsTest suite run printString.   "all pass"
RxbtMatcherTest   suite run printString.   "176/176 — no regression"
```

---

## Pitfalls

- **`(?#` vs `(?=` etc.:** The `#` check must come BEFORE the lookahead/lookbehind
  dispatch. Otherwise `(?#...)` could be misread as a failed `(?` start.

- **POSIX `[:` parsing inside `[...]`:** Inside a charset, `[` normally means a
  literal `[` in PCRE (only `[:` triggers a POSIX class). Ensure the parser only
  activates POSIX mode when `[` is immediately followed by `:`, otherwise treat `[`
  as a literal character.

- **`RxbtCharSetParser` access to `RxbtPredicate`:** The parser must be able to
  instantiate `RxbtPredicate` directly. No dependency issues since both are in
  `Regex-Backtracking`.

- **`\K` and `(?|...)` interaction:** `\K` writes to `captures at: 1` directly.
  If branch-reset groups are added later (Phase beyond 13), the marker numbering
  may shift — review then.

- **`\K` before any content:** `foo\K` with no trailing content is valid — `\K`
  at the end of the pattern means the whole match is reported as empty from the
  position after `foo`. This works correctly since `cont value: pos` just
  propagates to the continuation.

- **Unknown POSIX class name:** Should degrade gracefully (predicate that never
  matches). Consider raising `RxbtSyntaxError` signal: `'Unknown POSIX class: ' , name`
  instead for stricter behaviour — either is acceptable. The spec above uses
  silent-fail; choose based on project preference.
