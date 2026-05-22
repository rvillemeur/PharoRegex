# Pharo Image Exploration Notes

Captured from initial session exploring the existing `Regex-Core` package.
Pharo version: 12.0.0SNAPSHOT

---

## Existing Engine Structure

### Packages
- `Regex-Core` — main engine (DO NOT MODIFY)
- `Regex-Core-Tests` — existing tests

### Class Hierarchy

```
RxMatcher                          "NFA executor, public API"
RxParser                           "recursive descent parser"
RxMatchOptimizer                   "start-state optimization"

RxsNode                            "AST base"
  RxsRegex    { branch regex }     "alternation + outer group"
  RxsBranch   { piece branch }     "concatenation"
  RxsPiece    { atom min max }     "quantified atom"
  RxsCharacter { character }
  RxsEpsilon
  RxsContextCondition { kind }     ". ^ $ \b \B"
  RxsCharSet  { elements negated }
  RxsPredicate { predicate negation } "\d \w \s etc"
  RxsRange    { from to }
  RxsLookaround { piece positive } "(?=...) (?!...)"
  RxsMessagePredicate { message }  ":selector: syntax"

RxmLink                            "NFA node base"
  RxmBranch   { loopback alternative }
  RxmMarker   (captures group boundaries)
  RxmTerminator
  RxmSubstring { substring }
  RxmPredicate
  RxmSpecial
```

### Verified: 174 tests in RxMatcherTest, all pass

```smalltalk
RxMatcherTest suite run printString
"174 ran, 174 passed, 0 skipped, 0 expected failures, 0 failures, 0 errors"
```

### Subexpression numbering (verified)
```smalltalk
| m |
m := RxMatcher forString: '(a+)(b+)'.
m search: 'aaabbb'.
m subexpression: 1.  "→ 'aaabbb'  (whole match)"
m subexpression: 2.  "→ 'aaa'     (first explicit group)"
m subexpression: 3.  "→ 'bbb'     (second explicit group)"
```

Marker layout: group n → `captures at: 2n-1` (start), `captures at: 2n` (end).
`subexpressionCount = markerCount // 2`.

---

## Key Parser Behaviour

### Alternation traversal (CRITICAL)
`hookBranchOf:onto:` in `RxMatcher` walks alternation siblings via the `regex`
slot WITHOUT calling `dispatchTo:` on them. Only `branch` gets `dispatchTo:`.
`RxbtMatcher.syntaxRegex:` must do the same — manually walk `node regex` chain.

### Lookaround already in parser
`(?=...)` and `(?!...)` are parsed by `lookAround` in `RxParser`. 
Triggered when: nullable atom followed by `?` (the `(` produces epsilon,
then `?` after epsilon triggers `lookAround` which consumes `=` or `!`).

### Existing `piece` method flow
```
piece → atom → quantifier? → RxsPiece
```
For lazy (Phase 3): check trailing `?` after `*`, `+`, `?`, `{n,m}`.
For possessive (Phase 5): check trailing `+` after quantifier.

---

## MCP Tool Patterns (verified working)

### Define class
```smalltalk
Object subclass: #MyClass
    instanceVariableNames: 'slot1 slot2'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'My-Package'.
```

### Define instance method
```smalltalk
MyClass compile: 'methodName: arg
    ^arg + 1'
classified: 'protocol'.
```

### Define class-side method
```smalltalk
MyClass class compile: 'create ^self new'
classified: 'instance creation'.
```

### Add method to existing class (extension, no modification)
```smalltalk
ExistingClass compile: 'newMethod
    ^42'
classified: 'backtracking'.
```

### Run test suite
```smalltalk
| result |
result := MyTestClass suite run.
result printString.
```

### Remove class (cleanup)
```smalltalk
MyClass removeFromSystem.
```

---

## RxMatcher Public API (complete)

### Class side
```
forString: aString
forString: aString ignoreCase: aBoolean
for: aSyntaxTree
for: aSyntaxTree ignoreCase: aBoolean
```

### Instance side — matching
```
matches: aString
matchesPrefix: aString
search: aString
matchesStream: aStream
matchesStreamPrefix: aStream
searchStream: aStream
```

### Instance side — captures
```
subexpression: n          "1-based; 1=whole, 2=first group"
subexpressionCount        "= markerCount // 2"
supportsSubexpressions    "true"
```

### Instance side — replace/collect
```
copy: aString replacingMatchesWith: replacement
copy: aString translatingMatchesUsing: aBlock
matchesIn: aString
matchesIn: aString collect: aBlock
matchesIn: aString do: aBlock
matchingRangesIn: aString
matchesOnStream: aStream
matchesOnStream: aStream collect: aBlock
matchesOnStream: aStream do: aBlock
split: aString indicesDo: aBlock
```

---

## Key Source Methods (for reference)

### RxMatcher >> makeStar:
```smalltalk
makeStar: aMatcher
    | dummy detour loopback |
    dummy := RxmLink new.
    detour := RxmBranch new next: aMatcher; alternative: dummy.
    loopback := (RxmBranch new beLoopback) next: aMatcher; alternative: dummy.
    aMatcher pointTailTo: loopback.
    ^detour
```
Note: greedy NFA star — tries longest first but NO backtracking if continuation fails.

### RxMatcher >> syntaxRegex:
```smalltalk
syntaxRegex: regexNode
    | startIndex endIndex endNode alternatives |
    startIndex := self allocateMarker.
    endIndex := self allocateMarker.
    endNode := RxmMarker new index: endIndex.
    alternatives := self hookBranchOf: regexNode onto: endNode.
    ^(RxmMarker new index: startIndex) pointTailTo: alternatives
```

### RxMatcherTest >> runRegex:
```smalltalk
runRegex: anArray
    "Array: [pattern, string1, bool1, subs1, string2, bool2, subs2, ...]"
    | source matcher |
    source := anArray first.
    matcher := self compileRegex: source.
    matcher
        ifNil: [(anArray at: 2) ifNotNil: [self signalFailure: '...']]
        ifNotNil: [
            (anArray at: 2) ifNil: [self signalFailure: '...']
            ifNotNil: [2 to: anArray size by: 3 do: [:index |
                self runMatcher: matcher
                     with: (anArray at: index)
                     expect: (anArray at: index+1)
                     withSubexpressions: (anArray at: index+2)]]]
```

### RxMatcherTest >> matcherClass
```smalltalk
matcherClass
    ^RxMatcher
```
Override this in `RxbtMatcherTest` to use `RxbtMatcher`.

---

## Phase 1 Gotcha: searchStream: and captures

`searchStream:` in `RxMatcher` uses `stream position` (0-based) internally.
`RxbtMatcher` uses 1-based string positions in `captures`.

In `searchStream:`, after a successful match:
- `captures at: 1` = 1-based start of match
- `captures at: 2` = 1-based position AFTER match end

To position stream after match: `aStream position: (captures at: 2) - 1`.

---

## Why Existing Engine Lacks True Backtracking

`RxmBranch >> matchAgainst:` in the NFA engine:
```smalltalk
matchAgainst: aMatcher
    | original firstMatch firstMatchPos |
    original := aMatcher currentState.
    (next matchAgainst: aMatcher) ifFalse: [
        ^alternative isNotNil and: [alternative matchAgainst: aMatcher]].
    alternative ifNil: [^true].
    firstMatch := aMatcher currentState.
    firstMatchPos := aMatcher position.
    aMatcher restoreState: original.
    (alternative matchAgainst: aMatcher) ifFalse: [
        aMatcher restoreState: firstMatch. ^true].
    firstMatchPos >= aMatcher position
        ifTrue: [aMatcher restoreState: firstMatch. ^true].
    ^true
```

This picks the LONGER of two alternatives — no propagation of failure back to
retry with a different match. So `(a|ab)c` fails on `abc` because it tries `a`
(first alternative), then `c` fails, but the engine doesn't retry with `ab`.
