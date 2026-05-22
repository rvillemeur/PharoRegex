# Phase 1 — Core Backtracking Engine

## Goal
Implement `RxbtMatcher` with full API compatibility with `RxMatcher`.
All 174 `RxMatcherTest` tests must pass when run via `RxbtMatcherTest`.

## Package
`Regex-Backtracking` (classes), `Regex-Backtracking-Tests` (tests)

## Class Definition

```smalltalk
Object subclass: #RxbtMatcher
    instanceVariableNames: 'ignoreCase inputString captures markerCount rootBlock groupMap'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking'.
```

Slots:
- `ignoreCase` — Boolean
- `inputString` — String currently being matched (set at match time, not build time)
- `captures` — Array of Integer-or-nil, size = markerCount. Index 2n-1 = start of group n, 2n = end of group n. Values are 1-based string positions.
- `markerCount` — Integer, total marker count (= subexpressionCount * 2)
- `rootBlock` — the compiled `[:pos :cont | Boolean]` closure for the whole pattern
- `groupMap` — IdentityDictionary: RxsRegex node → startMarkerIndex (for subexpression lookup)

## Class-Side Methods

```smalltalk
"instance creation"
for: aSyntaxTree
for: aSyntaxTree ignoreCase: aBoolean
forString: aString
forString: aString ignoreCase: aBoolean
```

`forString:` calls `RxParser safelyParse:` then `for:`.

## Build Methods

```smalltalk
initialize: syntaxTreeRoot ignoreCase: aBoolean
    ignoreCase := aBoolean.
    markerCount := 0.
    groupMap := IdentityDictionary new.
    rootBlock := syntaxTreeRoot dispatchTo: self.
    captures := Array new: markerCount withAll: nil.

allocateMarker
    markerCount := markerCount + 1.
    ^markerCount
```

## Syntax Methods (the core of the engine)

See CLAUDE.md for full pseudocode. Implement ALL of:

```
syntaxRegex:            syntaxBranch:           syntaxPiece:
syntaxCharacter:        syntaxEpsilon           syntaxAny
syntaxBeginningOfLine   syntaxEndOfLine         syntaxBeginningOfWord
syntaxEndOfWord         syntaxWordBoundary      syntaxNonWordBoundary
syntaxCharSet:          syntaxPredicate:        syntaxLookaround:
syntaxMessagePredicate:
```

### syntaxBeginningOfWord / syntaxEndOfWord / word boundary

Use the same word-char definition as `RxMatcher`:
```smalltalk
isWordChar: aChar
    ^aChar isLetter or: [aChar isDigit or: [aChar = $_]]
```

```smalltalk
syntaxBeginningOfWord
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (atWord and: [prevWord not]) ifFalse: [^false].
        cont value: pos]

syntaxEndOfWord
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (prevWord and: [atWord not]) ifFalse: [^false].
        cont value: pos]

syntaxWordBoundary
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (atWord xor: prevWord) ifFalse: [^false].
        cont value: pos]

syntaxNonWordBoundary
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (atWord xor: prevWord) ifTrue: [^false].
        cont value: pos]
```

### syntaxLookaround:
```smalltalk
syntaxLookaround: node
    | innerBlock |
    innerBlock := node piece dispatchTo: self.
    node positive
        ifTrue: [
            ^[:pos :cont |
                (innerBlock value: pos value: [:_ | true])
                    ifTrue:  [cont value: pos]
                    ifFalse: [false]]]
        ifFalse: [
            ^[:pos :cont |
                (innerBlock value: pos value: [:_ | true])
                    ifTrue:  [false]
                    ifFalse: [cont value: pos]]]
```

### syntaxMessagePredicate:
```smalltalk
syntaxMessagePredicate: node
    ^[:pos :cont |
        pos > inputString size ifTrue: [^false].
        (inputString at: pos) perform: node message
            ifFalse: [^false].
        cont value: pos + 1]
```

## Matching API Methods

### Core match methods
```smalltalk
matches: aString
    "Full match — entire string must match"
    inputString := aString.
    captures := Array new: markerCount withAll: nil.
    ^rootBlock value: 1 value: [:endPos | endPos = aString size + 1]

matchesPrefix: aString
    "Match from start, any length"
    inputString := aString.
    captures := Array new: markerCount withAll: nil.
    ^rootBlock value: 1 value: [:endPos | true]

search: aString
    "Search anywhere in string"
    ^self searchStream: aString readStream

matchesStream: aStream
    inputString := aStream contents.
    captures := Array new: markerCount withAll: nil.
    (rootBlock value: aStream position + 1 value: [:endPos |
        endPos = inputString size + 1])
        ifTrue: [aStream position: inputString size. ^true].
    ^false

matchesStreamPrefix: aStream
    inputString := aStream contents.
    captures := Array new: markerCount withAll: nil.
    | result endPos |
    result := rootBlock value: aStream position + 1 value: [:ep | endPos := ep. true].
    result ifTrue: [aStream position: endPos - 1].
    ^result

searchStream: aStream
    | str startPos |
    str := aStream contents.
    inputString := str.
    startPos := aStream position + 1.
    startPos to: str size + 1 do: [:pos |
        captures := Array new: markerCount withAll: nil.
        (rootBlock value: pos value: [:endPos | true])
            ifTrue: [aStream position: (captures at: 2) - 1. ^true]].
    ^false
```

### Subexpression API
```smalltalk
supportsSubexpressions
    ^true

subexpressionCount
    ^markerCount // 2

subexpression: n
    "1-based: n=1 is whole match, n=2 is first explicit group, etc."
    | start end |
    start := captures at: 2 * n - 1.
    end   := captures at: 2 * n.
    (start isNil or: [end isNil]) ifTrue: [^nil].
    ^inputString copyFrom: start to: end - 1
```

### Replace / collect (delegate to searchStream: pattern)
Implement `copy:replacingMatchesWith:`, `copy:translatingMatchesUsing:`,
`matchesIn:`, `matchesIn:collect:`, `matchesIn:do:`, `matchingRangesIn:`,
`split:indicesDo:`.

These all follow the same pattern — repeatedly call `search:` or `searchStream:`,
collect results, advance past match. Copy the logic from `RxMatcher` source
(accessible via `mcp__pharo__method_source`). Adjust stream position tracking
using `captures at: 1` (match start) and `captures at: 2` (match end).

## Test Class

```smalltalk
RxMatcherTest subclass: #RxbtMatcherTest
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking-Tests'.

RxbtMatcherTest compile: 'matcherClass ^RxbtMatcher' classified: 'accessing'.
```

## Acceptance Criteria

```smalltalk
RxbtMatcherTest suite run printString
"Must output: '174 ran, 174 passed, 0 skipped, 0 expected failures, 0 failures, 0 errors'"
```

## Smoke Tests (run after each method group)

```smalltalk
"Literal"
(RxbtMatcher forString: 'abc') matches: 'abc'   "→ true"
(RxbtMatcher forString: 'abc') matches: 'xyz'   "→ false"

"Star"
(RxbtMatcher forString: 'a*') matches: ''       "→ true"
(RxbtMatcher forString: 'a*') matches: 'aaa'    "→ true"

"Backtracking star"
(RxbtMatcher forString: 'a*a') matches: 'aaa'   "→ true (greedy a* takes 2, then a matches last)"

"Alternation"
(RxbtMatcher forString: 'cat|dog') search: 'my dog'  "→ true"

"Groups"
| m |
m := RxbtMatcher forString: '(a+)(b+)'.
m search: 'aaabbb'.
m subexpression: 2.   "→ 'aaa'"
m subexpression: 3.   "→ 'bbb'"

"Case insensitive"
(RxbtMatcher forString: 'abc' ignoreCase: true) matches: 'ABC'  "→ true"
```
