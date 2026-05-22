# Phase 6 — Non-Capturing Groups & Lookbehind

## Goal
Add `(?:...)` non-capturing groups and `(?<=...)` / `(?<!...)` lookbehind assertions.
Both are zero-overhead for callers that do not need these features.

## Package
`Regex-Backtracking`

---

## Part A — Non-Capturing Groups `(?:...)`

### Why
Every `(...)` group currently allocates a capture marker pair. Patterns like
`(?:cat|dog)+` only need grouping for quantification, not capture. Unnecessary
markers waste memory and pollute `subexpressionCount`.

### New AST Node

```smalltalk
"RxsNonCapturingGroup wraps the inner RxsRegex tree without allocating markers."
(RxsNode << #RxsNonCapturingGroup
    slots: #(inner);
    package: 'Regex-Backtracking') install.

RxsNonCapturingGroup comment: 'AST node for a non-capturing group (?:...).
Wraps the inner alternation tree. RxbtCompiler compiles it like an alternation
but allocates no capture markers, so subexpressionCount is unaffected.'.

RxsNonCapturingGroup compile: 'inner ^inner' classified: 'accessing'.
RxsNonCapturingGroup compile: 'inner: aNode inner := aNode' classified: 'initialize'.
RxsNonCapturingGroup compile: 'isNullable ^inner isNullable' classified: 'testing'.
RxsNonCapturingGroup compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxNonCapturingGroup: self' classified: 'double dispatch'.
```

### Parser Change

Update `RxParser>>atom` (already in `Regex-Backtracking` category) to handle `(?:`:

```smalltalk
"In the lookahead = $? branch of the ( handler, add before the lookAround fallthrough:"
lookahead = $:
    ifTrue: [
        self next.          "consume :"
        atom := self regex.
        self match: $).
        ^RxsNonCapturingGroup new inner: atom].
```

Full `(?` dispatch order:
1. `>` → atomic group `(?>...)`
2. `:` → non-capturing group `(?:...)`
3. `<` → lookbehind `(?<=...)` / `(?<!...)` (Phase 6B)
4. `=` / `!` → lookahead via `lookAround`

### Compiler Method

```smalltalk
syntaxNonCapturingGroup: node
    "Compile alternation without allocating capture markers.
     Inner explicit groups still capture normally."
    | altBlocks inner |
    altBlocks := OrderedCollection new.
    inner := node inner.
    [inner notNil] whileTrue: [
        altBlocks add: (inner branch dispatchTo: self).
        inner := inner regex].
    altBlocks size = 1 ifTrue: [^altBlocks first].
    ^[:pos :cont |
        | result |
        result := false.
        altBlocks do: [:ab |
            result ifFalse: [
                result := ab value: pos value: cont]].
        result]
```

### Test Class

```smalltalk
(TestCase << #RxbtNonCapturingTest
    slots: #();
    package: 'Regex-Backtracking-Tests') install.

RxbtNonCapturingTest comment: 'Tests for non-capturing groups (?:...) in RxbtMatcher.
Verifies that grouping works for quantification without affecting subexpressionCount,
and that nested capturing groups inside (?:...) still capture correctly.'.
```

### Test Cases

```smalltalk
testBasicNonCapturing
    "(?:cat|dog) groups for alternation without capture."
    | m |
    m := RxbtMatcher forString: '(?:cat|dog)s'.
    self assert: (m matches: 'cats').
    self assert: (m matches: 'dogs').
    self deny:   (m matches: 'birds').
    "No extra subexpression allocated."
    self assert: m subexpressionCount = 1.

testNonCapturingWithQuantifier
    "(?:ab)+ repeats group without capturing each iteration."
    | m |
    m := RxbtMatcher forString: '(?:ab)+'.
    self assert: (m matches: 'ab').
    self assert: (m matches: 'ababab').
    self deny:   (m matches: 'a').

testNonCapturingVsCapturing
    "(?:...) does not add to subexpressionCount; (...) does."
    | nc c |
    nc := RxbtMatcher forString: '(?:a)(b)'.
    c  := RxbtMatcher forString: '(a)(b)'.
    nc search: 'ab'. c search: 'ab'.
    self assert: nc subexpressionCount = 2.   "whole + 1 explicit"
    self assert: c  subexpressionCount = 3.   "whole + 2 explicit"
    self assert: (nc subexpression: 2) = 'b'.
    self assert: (c  subexpression: 2) = 'a'.

testNestedCaptureInsideNonCapturing
    "Explicit groups inside (?:...) still capture."
    | m |
    m := RxbtMatcher forString: '(?:(a)|(b))'.
    m search: 'b'.
    self assert: (m subexpression: 2) isNil.   "first alt did not match"
    self assert: (m subexpression: 3) = 'b'.
```

---

## Part B — Lookbehind `(?<=...)` / `(?<!...)`

### New AST Node

```smalltalk
(RxsNode << #RxsLookbehind
    slots: #(inner positive);
    package: 'Regex-Backtracking') install.

RxsLookbehind comment: 'AST node for lookbehind assertions (?<=...) and (?<!...).
positive=true for positive lookbehind, false for negative.
At runtime the inner pattern is tried against all substrings ending at the current
position. Zero-width: does not advance pos on success.
Note: capture groups inside lookbehind are not preserved after the assertion.'.

RxsLookbehind compile: 'inner ^inner' classified: 'accessing'.
RxsLookbehind compile: 'positive ^positive' classified: 'accessing'.
RxsLookbehind compile: 'inner: aNode
    inner := aNode.
    positive := true' classified: 'initialize'.
RxsLookbehind compile: 'beNegative positive := false' classified: 'initialize'.
RxsLookbehind compile: 'isNullable ^true' classified: 'testing'.
RxsLookbehind compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxLookbehind: self' classified: 'double dispatch'.
```

### Parser Changes

Add `lookBehind` method to `RxParser` (in `Regex-Backtracking` category):

```smalltalk
lookBehind
    "Parse (?<=...) or (?<!...) after the < has been consumed."
    | positive lookbehind |
    (lookahead = $= or: [lookahead = $!])
        ifFalse: [self signalParseError: 'invalid lookbehind — expected = or !'].
    positive := lookahead = $=.
    self next.   "consume = or !"
    lookbehind := RxsLookbehind new inner: self regex.
    positive ifFalse: [lookbehind beNegative].
    ^lookbehind
```

In `RxParser>>atom`, inside the `(?` branch, add `<` handling before the `lookAround` fallthrough:

```smalltalk
lookahead = $<
    ifTrue: [
        self next.     "consume <"
        atom := self lookBehind.
        self match: $).
        ^atom].
```

### Compiler Method

Strategy: try all start positions from 1 to pos−1; check if inner pattern matches
from that start and ends exactly at pos. O(n²) worst case, correct for all patterns.

Capture groups inside the lookbehind inner pattern are run in isolation — the outer
captures array is saved and restored so inner side-effects do not leak.

```smalltalk
syntaxLookbehind: node
    "Build a CPS block for lookbehind. Saves and restores captures to prevent
     inner match attempts from contaminating outer capture state."
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    node positive
        ifTrue: [
            ^[:pos :cont |
                | savedCaptures found |
                savedCaptures := matcher captures copy.
                found := false.
                1 to: pos - 1 do: [:start |
                    found ifFalse: [
                        found := innerBlock value: start value: [:endPos | endPos = pos]]].
                matcher captures: savedCaptures.
                found ifTrue: [cont value: pos] ifFalse: [false]]]
        ifFalse: [
            ^[:pos :cont |
                | savedCaptures found |
                savedCaptures := matcher captures copy.
                found := false.
                1 to: pos - 1 do: [:start |
                    found ifFalse: [
                        found := innerBlock value: start value: [:endPos | endPos = pos]]].
                matcher captures: savedCaptures.
                found ifTrue: [false] ifFalse: [cont value: pos]]]
```

Also add `captures:` setter to `RxbtMatcher`:

```smalltalk
RxbtMatcher compile: 'captures: anArray captures := anArray' classified: 'accessing'.
```

### Test Class

```smalltalk
(TestCase << #RxbtLookbehindTest
    slots: #();
    package: 'Regex-Backtracking-Tests') install.

RxbtLookbehindTest comment: 'Tests for lookbehind assertions in RxbtMatcher.
(?<=...) succeeds when the inner pattern matches just before the current position.
(?<!...) succeeds when it does not. Both are zero-width — they do not consume input.'.
```

### Test Cases

```smalltalk
testPositiveLookbehind
    "(?<=foo)bar matches bar only when preceded by foo."
    | m |
    m := RxbtMatcher forString: '(?<=foo)bar'.
    self assert: (m search: 'foobar').
    self deny:   (m search: 'xyzbar').

testNegativeLookbehind
    "(?<!foo)bar matches bar NOT preceded by foo."
    | m |
    m := RxbtMatcher forString: '(?<!foo)bar'.
    self deny:   (m search: 'foobar').
    self assert: (m search: 'xyzbar').

testLookbehindZeroWidth
    "Lookbehind does not consume characters."
    | m |
    m := RxbtMatcher forString: '(?<=\d)px'.
    m search: '12px'.
    self assert: (m subexpression: 1) = 'px'.

testLookbehindAtStart
    "Positive lookbehind at position 1 always fails (nothing before)."
    | m |
    m := RxbtMatcher forString: '(?<=a)b'.
    self deny: (m search: 'b').

testNegativeLookbehindAtStart
    "Negative lookbehind at position 1 always succeeds (nothing before to match)."
    | m |
    m := RxbtMatcher forString: '(?<!a)b'.
    self assert: (m search: 'b').

testVariableLengthLookbehind
    "Lookbehind with quantifier — tries all possible start positions."
    | m |
    m := RxbtMatcher forString: '(?<=a+)b'.
    self assert: (m search: 'aaab').
    self deny:   (m search: 'b').
```

## Acceptance Criteria

```smalltalk
RxbtNonCapturingTest suite run printString.   "all pass"
RxbtLookbehindTest   suite run printString.   "all pass"
RxbtMatcherTest      suite run printString.   "176/176 — no regression"
```

## Pitfalls

- `(?:` dispatch must come BEFORE the `lookAround` fallthrough in `atom`, otherwise `:` is
  treated as `=`/`!` and signals a parse error.
- `syntaxNonCapturingGroup:` walks `inner`'s regex/branch chain manually — same pattern as
  `syntaxRegex:` but without `allocateMarker` calls. Do NOT call `inner dispatchTo: self`
  directly (that would call `syntaxRegex:` and allocate markers).
- Lookbehind `captures:` restore must happen unconditionally (both found and not-found paths)
  so that a failed lookbehind attempt does not corrupt outer capture state.
- At pos=1 there are no start positions to try → `1 to: 0 do:` iterates zero times →
  positive lookbehind returns false, negative returns true. Correct.
