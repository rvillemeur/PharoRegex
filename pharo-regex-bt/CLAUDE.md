# Pharo Backtracking Regex Engine

## Project Goal

Implement `RxbtMatcher` — a drop-in backtracking replacement for Pharo's existing `RxMatcher`
in package `Regex-Core`. The new engine lives in package `Regex-Backtracking` and is 100%
API-compatible with `RxMatcher`, extending it with lazy quantifiers, backreferences, and
possessive quantifiers.

**Do not modify any existing `Regex-Core` class.** Use extension methods and new classes only.

---

## MCP Tool Reference

The Pharo image is accessed via MCP tools. Use them for ALL code operations.

### Define a class
```smalltalk
Object subclass: #RxbtMatcher
    instanceVariableNames: 'ast ignoreCase inputString captures groupMap markerCount'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking'.
```

### Define an instance method
```smalltalk
RxbtMatcher compile: 'matches: aString
    ^self matchesStream: aString readStream'
classified: 'matching'.
```

### Define a class-side method
```smalltalk
RxbtMatcher class compile: 'forString: aString
    ^self for: (RxParser safelyParse: aString)'
classified: 'instance creation'.
```

### Add extension method to existing class (new package, no modification)
```smalltalk
RxsCharacter compile: 'matchBT: matcher at: pos continuation: aBlock
    | ch |
    pos > matcher inputSize ifTrue: [^false].
    ch := matcher inputAt: pos.
    (matcher ignoreCase
        ifTrue: [ch asLowercase = self character asLowercase]
        ifFalse: [ch = self character])
        ifFalse: [^false].
    ^aBlock value: pos + 1'
classified: 'backtracking'.
```

### Run all tests in a class
```smalltalk
| result |
result := RxbtMatcherTest suite run.
result printString
```

### Run a specific test
```smalltalk
| result |
result := RxbtMatcherTest run: #testHenry001.
result printString
```

### Check if a class exists
```smalltalk
Smalltalk globals includesKey: #RxbtMatcher
```

### Remove a class (cleanup)
```smalltalk
RxbtMatcher removeFromSystem
```

---

## Existing Engine: Public API to Replicate

`RxbtMatcher` MUST implement every method below with identical semantics.

### Class-side (instance creation)
```smalltalk
RxMatcher forString: 'pattern'             "case-sensitive"
RxMatcher forString: 'pattern' ignoreCase: true
RxMatcher for: aSyntaxTreeRoot             "from pre-parsed AST"
RxMatcher for: aSyntaxTreeRoot ignoreCase: false
```

### Instance-side (matching)
```smalltalk
matcher matches: aString           "true iff full string matches"
matcher matchesPrefix: aString     "true iff prefix matches"
matcher search: aString            "true iff match anywhere in string"
matcher matchesStream: aStream     "full match on stream"
matcher matchesStreamPrefix: aStream
matcher searchStream: aStream      "search on stream"
```

### Capture groups (1-based; group 1 = whole match)
```smalltalk
matcher subexpression: n           "String or nil — last match of group n"
matcher subexpressionCount         "total groups including whole match"
matcher supportsSubexpressions     "always true for RxbtMatcher"
```

### Replace / collect
```smalltalk
matcher copy: aString replacingMatchesWith: replacement
matcher copy: aString translatingMatchesUsing: aBlock
matcher matchesIn: aString                          "OrderedCollection of strings"
matcher matchesIn: aString collect: aBlock
matcher matchesIn: aString do: aBlock
matcher matchingRangesIn: aString                   "OrderedCollection of Intervals"
matcher matchesOnStream: aStream
matcher matchesOnStream: aStream collect: aBlock
matcher matchesOnStream: aStream do: aBlock
matcher split: aString indicesDo: aBlock
```

---

## Existing Engine: AST Node Hierarchy

The parser produces these nodes (all in `Regex-Core`, DO NOT modify):

```
RxsNode
├── RxsRegex         slots: branch regex          "alternation + capture group"
├── RxsBranch        slots: piece branch           "concatenation chain"
├── RxsPiece         slots: atom min max           "quantified atom"
│     min=0,max=nil → *   min=1,max=nil → +
│     min=0,max=1   → ?   min=n,max=m   → {n,m}
├── RxsCharacter     slots: character              "literal char"
├── RxsEpsilon                                     "empty / always match"
├── RxsContextCondition  slots: kind               "., ^, $, \b, \B"
├── RxsCharSet       slots: elements negated       "character class [...]"
├── RxsPredicate     slots: predicate negation     "\d \w \s etc."
├── RxsRange         slots: from to                "range inside charclass"
├── RxsLookaround    slots: piece positive         "(?=...) (?!...)"
└── RxsMessagePredicate  slots: message            ":selector: syntax"
```

### Key methods on AST nodes

```smalltalk
aNode dispatchTo: aMatcher   "double-dispatch — calls aMatcher syntaxXxx: aNode"
aPiece isSingular / isStar / isPlus / isOptional  "quantifier kind"
aPiece min / aPiece max      "min always Integer; max is Integer or nil (= infinity)"
aPiece atom                  "the inner RxsNode"
aBranch piece / aBranch branch   "piece = current; branch = rest of concat (or nil)"
aRegex branch / aRegex regex     "branch = first alternative; regex = next alt (or nil)"
aContextCondition kind       "Symbol: #any #beginOfLine #endOfLine #wordBoundary etc."
aCharacter character         "the Character"
aCharSet predicates / aCharSet isNegated
aPredicate predicate         "a BlockClosure taking a Character, returning Boolean"
aLookaround piece / aLookaround positive  "positive=true → lookahead (?=), false → (?!)"
```

### How dispatchTo: works (double dispatch)
Each `RxsNode` subclass sends a specific message to the matcher:
- `RxsRegex`            → `aMatcher syntaxRegex: self`
- `RxsBranch`           → `aMatcher syntaxBranch: self`
- `RxsPiece`            → `aMatcher syntaxPiece: self`
- `RxsCharacter`        → `aMatcher syntaxCharacter: self`
- `RxsEpsilon`          → `aMatcher syntaxEpsilon`
- `RxsContextCondition` → `aMatcher syntaxXxx` (e.g. `syntaxAny`, `syntaxBeginningOfLine`)
- `RxsCharSet`          → `aMatcher syntaxCharSet: self`
- `RxsPredicate`        → `aMatcher syntaxPredicate: self`
- `RxsLookaround`       → `aMatcher syntaxLookaround: self`
- `RxsMessagePredicate` → `aMatcher syntaxMessagePredicate: self`

---

## Architecture: CPS Closure Engine

`RxbtMatcher` implements all `syntax*:` methods. Each returns a **matcher closure**:
```
[:pos :cont | Boolean]
```
- `pos` — Integer, 1-based position in `inputString`
- `cont` — `[:newPos | Boolean]` — continuation called on success
- Returns true if a complete match was found (continuation also succeeded)

### Build phase
```smalltalk
buildFrom: syntaxTreeRoot
    markerCount := 0.
    groupMap := IdentityDictionary new.
    rootBlock := syntaxTreeRoot dispatchTo: self.
    captures := Array new: markerCount withAll: nil.
```

### syntaxRegex: (alternation + capture group)
**Critical**: Walk alternation siblings via `regex` slot MANUALLY. Do NOT call
`dispatchTo:` on sibling `RxsRegex` nodes (that would allocate duplicate group markers).

```smalltalk
syntaxRegex: regexNode
    | startIdx endIdx altBlocks node |
    startIdx := self allocateMarker.
    endIdx   := self allocateMarker.
    groupMap at: regexNode put: startIdx.   "record for group lookup"
    altBlocks := OrderedCollection new.
    node := regexNode.
    [node notNil] whileTrue: [
        altBlocks add: (node branch dispatchTo: self).
        node := node regex].
    ^[:pos :cont |
        | savedStart savedEnd result |
        savedStart := captures at: startIdx.
        savedEnd   := captures at: endIdx.
        captures at: startIdx put: pos.
        result := false.
        altBlocks do: [:ab |
            result ifFalse: [
                result := ab value: pos value: [:endPos |
                    captures at: endIdx put: endPos.
                    cont value: endPos]]].
        result ifFalse: [
            captures at: startIdx put: savedStart.
            captures at: endIdx   put: savedEnd].
        result]
```

### syntaxBranch: (concatenation)
```smalltalk
syntaxBranch: branchNode
    | pieceBlock restBlock |
    pieceBlock := branchNode piece dispatchTo: self.
    restBlock := branchNode branch isNil
        ifTrue:  [nil]
        ifFalse: [branchNode branch dispatchTo: self].
    restBlock isNil ifTrue: [^pieceBlock].
    ^[:pos :cont |
        pieceBlock value: pos value: [:pos2 |
            restBlock value: pos2 value: cont]]
```

### syntaxPiece: (quantifiers — greedy by default)
```smalltalk
syntaxPiece: pieceNode
    | atomBlock |
    atomBlock := pieceNode atom dispatchTo: self.
    pieceNode isSingular ifTrue: [^atomBlock].
    pieceNode isStar     ifTrue: [^self greedyStar: atomBlock].
    pieceNode isPlus     ifTrue: [^self greedyPlus: atomBlock].
    pieceNode isOptional ifTrue: [^self greedyOptional: atomBlock].
    ^self greedyRepeat: atomBlock min: pieceNode min max: pieceNode max
```

### Greedy star (backtracking)
```smalltalk
greedyStar: atomBlock
    ^[:pos :cont | self matchStar: atomBlock from: pos continuation: cont]

matchStar: atomBlock from: pos continuation: cont
    | result |
    result := atomBlock value: pos value: [:newPos |
        newPos = pos  "epsilon guard — prevent infinite loop"
            ifTrue:  [cont value: newPos]
            ifFalse: [self matchStar: atomBlock from: newPos continuation: cont]].
    result ifFalse: [^cont value: pos].   "backtrack: try zero matches"
    ^result
```

### Greedy plus (+)
```smalltalk
greedyPlus: atomBlock
    ^[:pos :cont |
        atomBlock value: pos value: [:pos2 |
            self matchStar: atomBlock from: pos2 continuation: cont]]
```

### Greedy optional (?)
```smalltalk
greedyOptional: atomBlock
    ^[:pos :cont |
        | result |
        result := atomBlock value: pos value: cont.
        result ifFalse: [cont value: pos].
        result]
```

### Greedy {min,max}
```smalltalk
greedyRepeat: atomBlock min: minN max: maxN
    ^[:pos :cont |
        self matchRepeat: atomBlock from: pos count: 0 min: minN max: maxN continuation: cont]

matchRepeat: atomBlock from: pos count: n min: minN max: maxN continuation: cont
    (maxN notNil and: [n >= maxN]) ifTrue: [
        ^n >= minN ifTrue: [cont value: pos] ifFalse: [false]].
    | result |
    result := atomBlock value: pos value: [:newPos |
        newPos = pos
            ifTrue:  [n >= minN ifTrue: [cont value: newPos] ifFalse: [false]]
            ifFalse: [self matchRepeat: atomBlock from: newPos count: n+1
                          min: minN max: maxN continuation: cont]].
    (result not and: [n >= minN]) ifTrue: [^cont value: pos].
    ^result
```

### Character matchers
```smalltalk
syntaxCharacter: charNode
    ^[:pos :cont |
        pos > inputString size ifTrue: [^false].
        (ignoreCase
            ifTrue:  [(inputString at: pos) asLowercase = charNode character asLowercase]
            ifFalse: [(inputString at: pos) = charNode character])
            ifFalse: [^false].
        cont value: pos + 1]

syntaxEpsilon
    ^[:pos :cont | cont value: pos]

syntaxAny
    ^[:pos :cont |
        (pos <= inputString size and: [
            (inputString at: pos) ~= (Character value: 10) and: [
            (inputString at: pos) ~= (Character value: 13)]])
            ifTrue:  [cont value: pos + 1]
            ifFalse: [false]]
```

### Anchor matchers
```smalltalk
syntaxBeginningOfLine
    ^[:pos :cont |
        (pos = 1 or: [(inputString at: pos - 1) = (Character value: 10)])
            ifTrue: [cont value: pos] ifFalse: [false]]

syntaxEndOfLine
    ^[:pos :cont |
        (pos > inputString size or: [(inputString at: pos) = (Character value: 10)])
            ifTrue: [cont value: pos] ifFalse: [false]]
```

### CharSet matcher
```smalltalk
syntaxCharSet: charSetNode
    ^[:pos :cont |
        pos > inputString size ifTrue: [^false].
        | ch matches |
        ch := inputString at: pos.
        matches := charSetNode predicates anySatisfy: [:pred | pred value: ch].
        charSetNode isNegated ifTrue: [matches := matches not].
        matches ifFalse: [^false].
        cont value: pos + 1]
```

### Predicate matcher (\d \w \s etc.)
```smalltalk
syntaxPredicate: predNode
    ^[:pos :cont |
        pos > inputString size ifTrue: [^false].
        (predNode value: (inputString at: pos))
            ifFalse: [^false].
        cont value: pos + 1]
```

---

## Capture Group Numbering

Marker indices follow the existing convention exactly:
- Group n: start position = `captures at: 2n-1`, end position = `captures at: 2n`
- Group 1 = whole match (outermost `RxsRegex` from `parse:`)
- Group 2 = first explicit `(...)`, group 3 = second, etc.
- `subexpressionCount = markerCount // 2`

`subexpression: n` returns the substring of `inputString` from
`captures at: 2n-1` to `captures at: 2n - 1` (exclusive end).

---

## Matching Protocol

### matches: (full string match)
```smalltalk
matches: aString
    inputString := aString.
    captures := Array new: markerCount withAll: nil.
    ^rootBlock value: 1 value: [:endPos | endPos = aString size + 1]
```

### search: (search anywhere)
```smalltalk
search: aString
    inputString := aString.
    1 to: aString size + 1 do: [:startPos |
        captures := Array new: markerCount withAll: nil.
        (rootBlock value: startPos value: [:endPos | true]) ifTrue: [^true]].
    ^false
```

### matchesPrefix: (match from start)
```smalltalk
matchesPrefix: aString
    inputString := aString.
    captures := Array new: markerCount withAll: nil.
    ^rootBlock value: 1 value: [:endPos | true]
```

---

## Test Strategy

### Phase 1: Compatibility
Subclass `RxMatcherTest`, override `matcherClass` only. All 174 existing tests must pass.

```smalltalk
TestCase subclass: #RxbtMatcherTest
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking-Tests'.

"Inherit everything from RxMatcherTest — just change the matcher class"
RxbtMatcherTest compile: 'matcherClass ^RxbtMatcher' classified: 'accessing'.
```

But `RxMatcherTest` is in a different class hierarchy. Use delegation or copy
the test infrastructure instead:

```smalltalk
RxbtMatcherTest compile: 'compileRegex: aString
    | syntaxTree |
    syntaxTree := RxParser safelyParse: aString.
    ^syntaxTree ifNotNil: [RxbtMatcher for: syntaxTree]'
classified: 'private'.
```

Then copy `runRegex:` and `runMatcher:with:expect:withSubexpressions:` from
`RxMatcherTest` verbatim, and add `testHenry001` through the full suite.

**Simpler**: just subclass `RxMatcherTest` and override `matcherClass`:
```smalltalk
RxMatcherTest subclass: #RxbtMatcherTest
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking-Tests'.

RxbtMatcherTest compile: 'matcherClass ^RxbtMatcher' classified: 'accessing'.
```
This inherits ALL test methods automatically. Run with:
```smalltalk
RxbtMatcherTest suite run printString
```

### Phases 2-5: New tests in dedicated classes
- `RxbtLazyTest` — lazy quantifiers
- `RxbtBackreferenceTest` — backreferences
- `RxbtPossessiveTest` — possessive quantifiers + atomic groups

---

## Common Pitfalls

1. **Epsilon loops**: `a*` where `a` matches empty → infinite recursion.
   Guard: `newPos = pos ifTrue: [cont value: pos]` in star/repeat.

2. **Capture restore on failure**: when all alternatives of a group fail,
   restore `captures` to pre-attempt values.

3. **Greedy vs lazy**: greedy tries MORE first, lazy tries LESS first.
   Implement as separate `lazyStar:`, `lazyPlus:` etc. methods.

4. **`syntaxRegex:` alternation traversal**: walk via `regex` slot manually.
   Never call `dispatchTo:` on alternation siblings (allocates duplicate markers).

5. **`subexpression:` stream vs position**: existing API uses stream position
   (0-based). `captures` uses 1-based string indices. Conversion:
   `inputString copyFrom: start to: end - 1`.

6. **`markerCount` initialization**: must be 0 BEFORE `dispatchTo:` traversal.

7. **`inputString` is nil during build**: set only during match calls.

8. **Word boundary in Pharo**: `RxMatcher >> isWordChar:` checks if a character
   is alphanumeric or `_`. Replicate this logic exactly.

9. **`syntaxLookaround:`**: `RxsLookaround` has `piece` (the inner regex node)
   and `positive` (boolean). Lookahead does NOT consume input.
