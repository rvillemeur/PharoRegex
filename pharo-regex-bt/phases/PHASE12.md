# Phase 12 — Catastrophic Backtracking Guard

## Goal

Add a configurable step counter to `RxbtMatcher` that raises `RxbtMatchingError`
when a match attempt exceeds a threshold number of atom evaluations. This
prevents exponential-time patterns (e.g. `(a+)+b` on `'aaaaaa...'`) from
hanging the Pharo image indefinitely.

Pure safety net — zero behaviour change for patterns that complete within the
limit. The default limit (1 000 000 steps) terminates catastrophic cases in
under a second while comfortably passing all tests on normal input.

## Package

`Regex-Backtracking`

---

## What Counts as a Step

A "step" is any evaluation of an **atom-level** CPS block — the innermost blocks
that actually try to consume or assert against a character:

| Compiler method          | Counts a step? |
|--------------------------|----------------|
| `syntaxCharacter:`       | yes |
| `syntaxPredicate:`       | yes |
| `syntaxAny`              | yes |
| `syntaxCharSet:`         | yes |
| `syntaxMessagePredicate:`| yes |
| `syntaxGenericNewline`   | yes |
| `syntaxBeginningOfLine`  | yes |
| `syntaxEndOfLine`        | yes |
| `syntaxBeginningOfString`| yes |
| `syntaxEndOfString`      | yes |
| `syntaxEndOfStringZ`     | yes |
| `syntaxBeginningOfWord`  | yes |
| `syntaxEndOfWord`        | yes |
| `syntaxWordBoundary`     | yes |
| `syntaxNonWordBoundary`  | yes |
| `syntaxBackreference:`   | yes |
| `syntaxNamedBackreference:` | yes |
| `syntaxBranch:`          | **no** (structural) |
| `syntaxRegex:`           | **no** (structural) |
| `syntaxPiece:`           | **no** (structural) |
| `greedyStar:` etc.       | **no** (delegates to atom) |

Structural blocks are traversed at no cost — only attempts to match or assert
against the input string count. This gives a meaningful measure of work done
independent of pattern structure.

---

## RxbtMatcher Changes

### Add ivars

```smalltalk
(Object << #RxbtMatcher)
    slots: #(ignoreCase inputString captures markerCount rootBlock groupNames
             optimizer stepCount stepLimit);
    package: 'Regex-Backtracking';
    install.
```

### New methods

```smalltalk
stepLimit
    ^stepLimit ifNil: [1000000]

stepLimit: anInteger
    stepLimit := anInteger

resetStepCount
    stepCount := 0

incrementStep
    stepCount := stepCount + 1.
    stepCount > self stepLimit ifTrue: [
        RxbtMatchingError signal:
            'Regex step limit exceeded (', self stepLimit printString,
            ' steps) — possible catastrophic backtracking']
```

### Update initialize:ignoreCase:

Add `stepCount := 0` at the end:

```smalltalk
initialize: syntaxTreeRoot ignoreCase: aBoolean
    | compiler |
    ignoreCase  := aBoolean.
    groupNames  := nil.
    compiler    := RxbtCompiler for: self ignoreCase: aBoolean.
    rootBlock   := compiler compile: syntaxTreeRoot.
    markerCount := compiler markerCount.
    captures    := Array new: markerCount withAll: nil.
    optimizer   := RxbtMatchOptimizer new
                       initialize: syntaxTreeRoot
                       ignoreCase: aBoolean.
    stepCount   := 0
```

### Update search:

Reset step count before each fresh search:

```smalltalk
search: aString
    inputString := aString.
    self resetStepCount.
    1 to: aString size + 1 do: [:startPos |
        | lookahead |
        lookahead := startPos <= aString size
            ifTrue:  [aString at: startPos]
            ifFalse: [nil].
        (optimizer canStartMatch: lookahead at: startPos) ifTrue: [
            captures := Array new: markerCount withAll: nil.
            (rootBlock value: startPos value: [:endPos | true])
                ifTrue: [^true]]].
    ^false
```

### Update searchStream:

```smalltalk
searchStream: aStream
    | startPos |
    inputString := aStream contents.
    self resetStepCount.
    startPos := aStream position + 1.
    startPos to: inputString size + 1 do: [:pos |
        | lookahead |
        lookahead := pos <= inputString size
            ifTrue:  [inputString at: pos]
            ifFalse: [nil].
        (optimizer canStartMatch: lookahead at: pos) ifTrue: [
            captures := Array new: markerCount withAll: nil.
            (rootBlock value: pos value: [:endPos |
                aStream position: endPos - 1.
                true])
                ifTrue: [^true]]].
    ^false
```

---

## RxbtCompiler Changes

Each atom-level `syntax*:` method prepends `matcher incrementStep` inside the
returned CPS block. The `matcher` ivar is already closed over by all blocks.

### syntaxCharacter:

```smalltalk
syntaxCharacter: charNode
    | f ch |
    f  := flags.
    ch := charNode character.
    (f extended and: [ch isSeparator]) ifTrue: [^[:pos :cont | cont value: pos]].
    f ignoreCase
        ifTrue: [
            ^[:pos :cont |
                matcher incrementStep.
                (pos <= matcher inputString size and: [
                    (matcher inputString at: pos) sameAs: ch])
                    ifTrue:  [cont value: pos + 1]
                    ifFalse: [false]]]
        ifFalse: [
            ^[:pos :cont |
                matcher incrementStep.
                (pos <= matcher inputString size and: [
                    (matcher inputString at: pos) = ch])
                    ifTrue:  [cont value: pos + 1]
                    ifFalse: [false]]]
```

Apply the same `matcher incrementStep` insertion to: `syntaxAny`,
`syntaxPredicate:`, `syntaxCharSet:`, `syntaxMessagePredicate:`,
`syntaxGenericNewline`, and all anchor/boundary methods
(`syntaxBeginningOfLine`, `syntaxEndOfLine`, `syntaxBeginningOfString`,
`syntaxEndOfString`, `syntaxEndOfStringZ`, `syntaxBeginningOfWord`,
`syntaxEndOfWord`, `syntaxWordBoundary`, `syntaxNonWordBoundary`,
`syntaxBackreference:`, `syntaxNamedBackreference:`).

The `matcher incrementStep` call goes at the **start** of the block body,
before any character reads. This ensures every attempt is counted even if
it immediately fails.

---

## Test Class

```smalltalk
(TestCase << #RxbtBacktrackingGuardTest)
    slots: #();
    package: 'Regex-Backtracking-Tests';
    install.

RxbtBacktrackingGuardTest comment: 'Tests for the catastrophic backtracking guard.
Verifies that pathological patterns raise RxbtMatchingError within the step limit,
and that normal patterns complete unaffected.'.
```

## Test Cases

```smalltalk
testCatastrophicPattern
    "Classic catastrophic: (a+)+b on all-a string — exponential without guard."
    | m |
    m := RxbtMatcher forString: '(a+)+b'.
    m stepLimit: 10000.
    self should: [m search: 'aaaaaaaaaaaaaaaa']
         raise:  RxbtMatchingError.

testExponentialAlternation
    "(a|aa)+ on all-a string — another classic catastrophic pattern."
    | m |
    m := RxbtMatcher forString: '(a|aa)+b'.
    m stepLimit: 10000.
    self should: [m search: 'aaaaaaaaaaaaaaaa']
         raise:  RxbtMatchingError.

testNormalPatternUnaffected
    "Simple literal search must not raise — step count stays low."
    | m |
    m := RxbtMatcher forString: 'foo'.
    m stepLimit: 10000.
    self assert: (m search: 'xxxfooyyy').

testLongButLinearPattern
    "a* on long string is O(n) steps — must NOT trigger the guard."
    | m input |
    input := String new: 5000 withAll: $a.
    m := RxbtMatcher forString: 'a*'.
    m stepLimit: 1000000.
    self assert: (m matches: input).

testCustomLimit
    "stepLimit: is respected per-instance."
    | m |
    m := RxbtMatcher forString: '(a+)+b'.
    m stepLimit: 500.
    self should: [m search: 'aaaaaaa'] raise: RxbtMatchingError.
    m stepLimit: 1000000.
    "With a generous limit the (short) match attempt completes or fails cleanly."
    self shouldnt: [m search: 'ab'] raise: RxbtMatchingError.

testErrorMessageContent
    "Error message includes the step limit for diagnostics."
    | m ex |
    m := RxbtMatcher forString: '(a+)+b'.
    m stepLimit: 100.
    ex := nil.
    [m search: 'aaaaaaaaaa'] on: RxbtMatchingError do: [:e | ex := e].
    self assert: ex notNil.
    self assert: (ex messageText includesSubString: '100').

testStepCountResetBetweenSearches
    "stepCount resets on each search: call — no cross-contamination."
    | m |
    m := RxbtMatcher forString: 'a+'.
    m stepLimit: 1000.
    self assert: (m search: 'aaa').
    self assert: (m search: 'aaa').   "second call must not see accumulated steps"

testRegressionFull
    "All existing tests must pass with default limit."
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty.
```

---

## Acceptance Criteria

```smalltalk
RxbtBacktrackingGuardTest suite run printString.   "all pass"
RxbtMatcherTest            suite run printString.   "176/176 — no regression"
```

---

## Pitfalls

- **`stepCount` scope across `search:` calls:** `search:` is called once per
  `RxbtMatcher` instance for a match, but the same instance may be reused.
  `resetStepCount` at the start of `search:` and `searchStream:` ensures the
  count is per-search, not cumulative.

- **`matches:` delegates to `search:`:** `matches:` and `matchStream:` both
  ultimately call `search:` or `searchStream:`, so no separate reset needed.

- **Anchor blocks counting steps:** Anchors like `syntaxBeginningOfLine` are
  called at every candidate start position during `search:`. On a large string,
  a pattern like `^a+b` will count one anchor step per candidate. This is
  expected and bounded by `O(n)` so it does not falsely trigger the guard.

- **`matchRepeat:` with large `{n,}` bounds:** Bounded repetition like `a{1000}`
  consumes 1000 steps. This is linear and expected. Only exponential/combinatorial
  explosion triggers the guard. Do not set the limit below the input size.

- **`RxbtMatchingError` hierarchy:** `RxbtMatchingError` is already defined in
  the exception independence refactor (subclass of `RxbtError < Error`). Use it
  directly — no new exception class needed.

- **Phase 11 interaction:** If Phase 11 is implemented, the iterative quantifier
  helpers no longer recurse. They still call `atomBlock` once per position, so
  the step counter in `syntaxCharacter:` etc. accumulates correctly. The guard
  fires based on atom evaluations, not recursion depth — the two phases are
  orthogonal.

- **`matcher incrementStep` in `syntaxCharacter:` with `ignoreCase` branches:**
  Both branches of the `ignoreCase` test must call `incrementStep`. Copy the
  call into both block literals — do not try to factor it outside the `ifTrue:
  ifFalse:` since the entire block literal is what is returned.

- **Performance overhead:** Each matched character now calls `incrementStep`,
  which does an integer increment and comparison. On CPython-like VMs this would
  be 5–10% overhead; in a Pharo JIT image it is negligible. Profile before
  optimising. If needed, inline the check as `stepCount := stepCount + 1.
  stepCount > stepLimit ifTrue: [...]` (after resolving `stepLimit` once at
  compile time rather than per-call).
