# Phase 8 — Absolute Anchors & Extended Escape Sequences

## Goal
Add `\A` `\Z` `\z` absolute string anchors and `\h` `\H` `\v` `\V` `\R`
whitespace-class escapes. These are all stateless single-character CPS blocks —
no new AST nodes, no parser state change. Lower complexity than Phases 6–7.

## Package
`Regex-Backtracking`

---

## Part A — Absolute Anchors

| Syntax | Meaning |
|--------|---------|
| `\A`   | Absolute start of string (pos = 1) regardless of multiline mode |
| `\z`   | Absolute end of string (pos > inputString size), no trailing newline exemption |
| `\Z`   | End of string OR immediately before a final `\n` at end of string |

Unlike `^` / `$`, these are unaffected by future multiline mode (Phase 9).

### New Context Condition Kinds

Extend `RxsContextCondition` by adding new `kind` symbols via extension methods.
`RxsContextCondition` already uses `kind` for `#any`, `#beginOfLine`, etc.
Add three new ones: `#beginOfString`, `#endOfString`, `#endOfStringZ`.

```smalltalk
"Extension methods on RxsContextCondition (in Regex-Backtracking category):"
RxsContextCondition compile: 'beBeginningOfString
    kind := #beginOfString' classified: 'backtracking'.
RxsContextCondition compile: 'beEndOfString
    kind := #endOfString' classified: 'backtracking'.
RxsContextCondition compile: 'beEndOfStringZ
    kind := #endOfStringZ' classified: 'backtracking'.
```

### Parser Changes

In `RxParser>>atom`, in the `\` handling section, before the digit check
(after `ifSpecial:then:`), add:

```smalltalk
lookahead = $A ifTrue: [self next. ^RxsContextCondition new beBeginningOfString].
lookahead = $z ifTrue: [self next. ^RxsContextCondition new beEndOfString].
lookahead = $Z ifTrue: [self next. ^RxsContextCondition new beEndOfStringZ].
```

These must come BEFORE the digit check to avoid conflict (digits 0–9 are already
handled; A/z/Z are letters and fall through `ifSpecial:` safely).

Also check that `\A`, `\z`, `\Z` are NOT in `BackslashSpecials` or `BackslashConstants`
before adding — they should not be, since the base engine does not support them.

### Compiler Methods

Extend `RxsContextCondition`'s dispatch via `syntaxContextCondition:kind:` if it
exists, or handle new kinds inside `syntaxContextConditionForKind:` (check how
the existing `#any`, `#beginOfLine` etc. are dispatched in `RxbtCompiler`):

Actually: looking at the current compiler, `RxsContextCondition` dispatches to
`aMatcher syntaxAny`, `aMatcher syntaxBeginningOfLine`, etc. via its own
`dispatchTo:` method, NOT via a single `syntaxContextCondition:` method.
So for the three new kinds, add extension methods to `RxsContextCondition`:

```smalltalk
"Extend RxsContextCondition to dispatch the three new kinds:"
"Check the existing dispatchTo: to understand what it does for known kinds,
 then add the three new cases to the dispatch."
```

Alternatively: add new `dispatchTo:` overrides in a subclass or patch the
existing `dispatchTo:` in `Regex-Backtracking` category.

The recommended approach: patch `RxsContextCondition>>dispatchTo:` in
`Regex-Backtracking` category to handle the new kinds, leaving the old ones intact:

```smalltalk
RxsContextCondition compile: 'dispatchTo: aMatcher
    kind = #beginOfString ifTrue: [^aMatcher syntaxBeginningOfString].
    kind = #endOfString   ifTrue: [^aMatcher syntaxEndOfString].
    kind = #endOfStringZ  ifTrue: [^aMatcher syntaxEndOfStringZ].
    ^super dispatchTo: aMatcher'
classified: 'backtracking'.
```

Then add compiler methods:

```smalltalk
syntaxBeginningOfString
    "Match only at position 1, regardless of newlines."
    ^[:pos :cont |
        pos = 1
            ifTrue:  [cont value: pos]
            ifFalse: [false]]

syntaxEndOfString
    "Match only at absolute end (pos > size). No newline exemption."
    ^[:pos :cont |
        pos > matcher inputString size
            ifTrue:  [cont value: pos]
            ifFalse: [false]]

syntaxEndOfStringZ
    "Match at end OR immediately before a single trailing \n."
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos > str size or: [
            pos = str size and: [(str at: pos) = (Character value: 10)]])
                ifTrue:  [cont value: pos]
                ifFalse: [false]]
```

---

## Part B — Whitespace Escape Sequences

| Escape | Meaning |
|--------|---------|
| `\h`   | Horizontal whitespace: space, tab, non-breaking space (U+00A0), etc. |
| `\H`   | Not `\h` |
| `\v`   | Vertical whitespace: LF, VT, FF, CR, NEL, LS, PS |
| `\V`   | Not `\v` |
| `\R`   | Generic newline: CR, LF, CRLF, VT, FF, NEL, LS, PS |

These produce `RxsPredicate` nodes (same as `\d`, `\w`, `\s`) via the
existing `ifSpecial:then:` mechanism in `RxParser`.

### Add to BackslashSpecials

`BackslashSpecials` is a class variable on `RxParser`. Extend it via the
`Regex-Backtracking` class initialization:

```smalltalk
"In a class-side initialize or explicit setup method on RxParser
 (in Regex-Backtracking category):"

| hChars vChars |
hChars := CharacterSet new.
hChars add: (Character value: 9).    "tab"
hChars add: (Character value: 32).   "space"
hChars add: (Character value: 160).  "non-breaking space"

vChars := CharacterSet new.
#(10 11 12 13 133 8232 8233) do: [:v | vChars add: (Character value: v)].

BackslashSpecials
    at: $h put: (RxsPredicate new predicate: [:c | hChars includes: c] negation: false);
    at: $H put: (RxsPredicate new predicate: [:c | hChars includes: c] negation: true);
    at: $v put: (RxsPredicate new predicate: [:c | vChars includes: c] negation: false);
    at: $V put: (RxsPredicate new predicate: [:c | vChars includes: c] negation: true).
```

For `\R` (generic newline) — matches CRLF as ONE match (two-character), which
a simple predicate cannot handle. `\R` requires a new two-step matcher:
try CRLF first (two chars), then any single vertical whitespace.

Add `\R` as a new AST node `RxsGenericNewline`:

```smalltalk
(RxsNode << #RxsGenericNewline
    slots: #();
    package: 'Regex-Backtracking') install.

RxsGenericNewline comment: 'AST node for \R (generic newline). Matches CR+LF as a
unit, or any single vertical whitespace character (CR, LF, VT, FF, NEL). Two-char
CRLF takes priority — this cannot be modelled as a simple character predicate.'.

RxsGenericNewline compile: 'isNullable ^false' classified: 'testing'.
RxsGenericNewline compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxGenericNewline' classified: 'double dispatch'.
```

In `RxParser>>atom` (in the `\` section), after `\z`/`\Z`/`\A` handling:

```smalltalk
lookahead = $R ifTrue: [self next. ^RxsGenericNewline new].
```

Compiler method:

```smalltalk
syntaxGenericNewline
    "Match CRLF as a unit, or any single vertical whitespace."
    | vBytes |
    vBytes := #(10 11 12 13 133).   "LF VT FF CR NEL (BMP only)"
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        pos > str size
            ifTrue: [false]
            ifFalse: [
                (pos < str size
                    and: [(str at: pos) = (Character value: 13)
                    and: [(str at: pos + 1) = (Character value: 10)]])
                    ifTrue: [cont value: pos + 2]
                    ifFalse: [
                        (vBytes anySatisfy: [:b | (str at: pos) = (Character value: b)])
                            ifTrue:  [cont value: pos + 1]
                            ifFalse: [false]]]]
```

---

## Test Class

```smalltalk
(TestCase << #RxbtAnchorEscapeTest
    slots: #();
    package: 'Regex-Backtracking-Tests') install.

RxbtAnchorEscapeTest comment: 'Tests for absolute anchors (\A \Z \z) and extended
whitespace escapes (\h \H \v \V \R) in RxbtMatcher. Absolute anchors are
unaffected by multiline mode. \R matches CRLF as a single logical newline unit.'.
```

## Test Cases

```smalltalk
testAbsoluteStart
    | m |
    m := RxbtMatcher forString: '\Afoo'.
    self assert: (m search: 'foobar').
    self deny:   (m search: 'barfoo').

testAbsoluteEndStrict
    "\\z matches only at absolute end, not before trailing newline."
    | m |
    m := RxbtMatcher forString: 'foo\z'.
    self assert: (m matches: 'foo').
    self deny:   (m matches: 'foo' , (String with: (Character value: 10))).

testAbsoluteEndZ
    "\\Z matches at end or before a single trailing newline."
    | m |
    m := RxbtMatcher forString: 'foo\Z'.
    self assert: (m matches: 'foo').
    self assert: (m matches: 'foo' , (String with: (Character value: 10))).
    self deny:   (m matches: 'foobar').

testHorizontalWhitespace
    | m |
    m := RxbtMatcher forString: '\h+'.
    self assert: (m matches: ' ').
    self assert: (m matches: (String with: (Character value: 9))).  "tab"
    self deny:   (m matches: (String with: (Character value: 10))).  "LF is not \h"

testVerticalWhitespace
    | m |
    m := RxbtMatcher forString: '\v'.
    self assert: (m matches: (String with: (Character value: 10))).  "LF"
    self assert: (m matches: (String with: (Character value: 13))).  "CR"
    self deny:   (m matches: ' ').

testGenericNewlineSingle
    | m |
    m := RxbtMatcher forString: '\R'.
    self assert: (m matches: (String with: (Character value: 10))).   "LF"
    self assert: (m matches: (String with: (Character value: 13))).   "CR alone"

testGenericNewlineCRLF
    "\\R matches CRLF as one unit."
    | m crlf |
    crlf := String with: (Character value: 13) with: (Character value: 10).
    m := RxbtMatcher forString: '\R'.
    self assert: (m matches: crlf).
    self assert: (m subexpression: 1) = crlf.

testNotVertical
    | m |
    m := RxbtMatcher forString: '\V+'.
    self assert: (m matches: 'hello world').
    self deny:   (m search: (String with: (Character value: 10))).
```

## Acceptance Criteria

```smalltalk
RxbtAnchorEscapeTest suite run printString.   "all pass"
RxbtMatcherTest       suite run printString.   "176/176 — no regression"
```

## Pitfalls

- `\A` `\Z` `\z` are letters, NOT digits. They must be checked BEFORE the digit
  backreference handler in `atom` to avoid falling through to the regular-char path.
- Patching `RxsContextCondition>>dispatchTo:` affects ALL matchers (RxMatcher too).
  Verify that `^super dispatchTo: aMatcher` correctly delegates the original cases.
- `BackslashSpecials` is a ClassVariable on `RxParser`. Adding to it at image load
  requires an `initialize` method (or explicit evaluation). Ensure the additions
  survive image saves by calling them from `BaselineOfRegexBacktracking>>baseline:`.
- `\R` matching CRLF as two characters must take priority over matching CR alone.
  The order in `syntaxGenericNewline` matters: check CRLF first.
- Unicode vertical whitespace (LS U+2028, PS U+2029, NEL U+0085) are above 127.
  Pharo's `Character value: n` supports these, but the test strings must be
  constructed carefully. Keep BMP-only for initial implementation.
