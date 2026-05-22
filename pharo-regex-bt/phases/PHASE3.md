# Phase 3 — Lazy Quantifiers

## Goal
Add lazy (non-greedy) quantifiers: `*?`, `+?`, `??`, `{n,m}?`.
Lazy quantifiers try FEWER matches first and expand only on backtracking.

## Package
`Regex-Backtracking` (parser extensions + matcher methods)
`Regex-Backtracking-Tests`

## Parser Changes

Extend `RxParser>>piece` to detect a trailing `?` after a quantifier:

```smalltalk
"Current piece method (simplified):"
piece
    | atom |
    atom := self atom.
    lookahead = $*
        ifTrue: [ self next. ^RxsPiece new initializeStarAtom: atom ].
    ...

"After change — check for lazy ? after each quantifier:"
piece
    | atom lazy |
    atom := self atom.
    lookahead = $*
        ifTrue: [
            self next.
            lazy := lookahead = $?.
            lazy ifTrue: [self next].
            atom isNullable ifTrue: [self signalNullableClosureParserError].
            ^lazy
                ifTrue:  [RxsPiece new initializeLazyStarAtom: atom]
                ifFalse: [RxsPiece new initializeStarAtom: atom]].
    lookahead = $+
        ifTrue: [
            self next.
            lazy := lookahead = $?.
            lazy ifTrue: [self next].
            atom isNullable ifTrue: [self signalNullableClosureParserError].
            ^lazy
                ifTrue:  [RxsPiece new initializeLazyPlusAtom: atom]
                ifFalse: [RxsPiece new initializePlusAtom: atom]].
    lookahead = $?
        ifTrue: [
            self next.
            atom isNullable ifTrue: [^self lookAround].
            lazy := lookahead = $?.
            lazy ifTrue: [self next].
            ^lazy
                ifTrue:  [RxsPiece new initializeLazyOptionalAtom: atom]
                ifFalse: [RxsPiece new initializeOptionalAtom: atom]].
    lookahead = ${
        ifTrue: [^self quantifiedAtom: atom].  "handle lazy inside quantifiedAtom:"
    ^RxsPiece new initializeAtom: atom
```

Add a `lazy` slot to `RxsPiece`:

```smalltalk
"Extend RxsPiece (add method, don't redefine class):"
RxsPiece compile: 'isLazy ^lazy' classified: 'testing'.
RxsPiece compile: 'becomeLazy lazy := true' classified: 'initialize'.

"New initializers:"
RxsPiece compile: 'initializeLazyStarAtom: anAtom
    self initializeStarAtom: anAtom.
    self becomeLazy' classified: 'initialize'.

RxsPiece compile: 'initializeLazyPlusAtom: anAtom
    self initializePlusAtom: anAtom.
    self becomeLazy' classified: 'initialize'.

RxsPiece compile: 'initializeLazyOptionalAtom: anAtom
    self initializeOptionalAtom: anAtom.
    self becomeLazy' classified: 'initialize'.
```

Also update `quantifiedAtom:` in `RxParser` to check for trailing `?`.

Also update `syntaxPiece:` in `RxbtMatcher` to check `pieceNode isLazy`:
```smalltalk
syntaxPiece: pieceNode
    | atomBlock |
    atomBlock := pieceNode atom dispatchTo: self.
    pieceNode isSingular ifTrue: [^atomBlock].
    pieceNode isLazy
        ifTrue: [
            pieceNode isStar     ifTrue: [^self lazyStar: atomBlock].
            pieceNode isPlus     ifTrue: [^self lazyPlus: atomBlock].
            pieceNode isOptional ifTrue: [^self lazyOptional: atomBlock].
            ^self lazyRepeat: atomBlock min: pieceNode min max: pieceNode max]
        ifFalse: [
            pieceNode isStar     ifTrue: [^self greedyStar: atomBlock].
            pieceNode isPlus     ifTrue: [^self greedyPlus: atomBlock].
            pieceNode isOptional ifTrue: [^self greedyOptional: atomBlock].
            ^self greedyRepeat: atomBlock min: pieceNode min max: pieceNode max]
```

## Lazy Matcher Methods (try FEWER first)

```smalltalk
"Lazy star: try 0 first, expand if continuation fails"
lazyStar: atomBlock
    ^[:pos :cont | self matchLazyStar: atomBlock from: pos continuation: cont]

matchLazyStar: atomBlock from: pos continuation: cont
    "Try 0 matches first (lazy). If cont fails, try 1 more."
    (cont value: pos) ifTrue: [^true].
    ^atomBlock value: pos value: [:newPos |
        newPos = pos ifTrue: [^false].  "epsilon guard"
        self matchLazyStar: atomBlock from: newPos continuation: cont]

"Lazy plus: must match at least 1, then lazy"
lazyPlus: atomBlock
    ^[:pos :cont |
        atomBlock value: pos value: [:pos2 |
            self matchLazyStar: atomBlock from: pos2 continuation: cont]]

"Lazy optional: try 0 first"
lazyOptional: atomBlock
    ^[:pos :cont |
        (cont value: pos) ifTrue: [^true].
        atomBlock value: pos value: cont]

"Lazy {n,m}"
lazyRepeat: atomBlock min: minN max: maxN
    ^[:pos :cont |
        self matchLazyRepeat: atomBlock from: pos count: 0
             min: minN max: maxN continuation: cont]

matchLazyRepeat: atomBlock from: pos count: n min: minN max: maxN continuation: cont
    n >= minN ifTrue: [
        (cont value: pos) ifTrue: [^true]].
    (maxN notNil and: [n >= maxN]) ifTrue: [^false].
    ^atomBlock value: pos value: [:newPos |
        newPos = pos ifTrue: [^false].
        self matchLazyRepeat: atomBlock from: newPos count: n+1
             min: minN max: maxN continuation: cont]
```

## Test Class

```smalltalk
TestCase subclass: #RxbtLazyTest
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking-Tests'.
```

Helper:
```smalltalk
matchFirst: pattern in: string
    | m |
    m := RxbtMatcher forString: pattern.
    (m search: string) ifFalse: [^nil].
    ^m subexpression: 1
```

## Test Cases

### testLazyStar
```smalltalk
testLazyStar
    "Greedy: .* takes everything, lazy: .* takes as little as possible"
    self assert: (self matchFirst: '.*?' in: 'abc') = ''.
    self assert: (self matchFirst: 'a.*?b' in: 'aXbYb') = 'aXb'.  "stops at first b"
```

### testLazyPlus
```smalltalk
testLazyPlus
    self assert: (self matchFirst: '.+?' in: 'abc') = 'a'.
    self assert: (self matchFirst: 'a.+?b' in: 'aXYb') = 'aXYb'
```

### testLazyOptional
```smallstalk
testLazyOptional
    | m |
    m := RxbtMatcher forString: 'a??b'.
    self assert: (m matches: 'b').    "a?? takes 0, b matches"
    self assert: (m matches: 'ab').   "a?? tries 0 first — cont 'b' at pos1 = 'a' fails; tries 1: a matches, b matches"
```

### testLazyVsGreedy
```smalltalk
testLazyVsGreedy
    | greedy lazy |
    greedy := RxbtMatcher forString: '<.+>'.
    lazy   := RxbtMatcher forString: '<.+?>'.
    
    greedy search: '<a><b>'.
    self assert: (greedy subexpression: 1) = '<a><b>'.  "greedy takes all"
    
    lazy search: '<a><b>'.
    self assert: (lazy subexpression: 1) = '<a>'.       "lazy stops at first >"
```

### testLazyQuantifiedAtom
```smalltalk
testLazyQuantifiedAtom
    | m |
    m := RxbtMatcher forString: 'a{2,4}?b'.
    self assert: (m matches: 'aab').    "lazy takes min=2"
    self assert: (m matches: 'aaab').   "lazy takes min=2, then b fails, expands to 3"
    self deny:   (m matches: 'b').
```

### testLazyNested
```smalltalk
testLazyNested
    "HTML-like: match content between tags (lazy)"
    | m |
    m := RxbtMatcher forString: '<[^>]+>.*?</[^>]+>'.
    self assert: (m search: '<b>hello</b> world <i>there</i>').
    self assert: (m subexpression: 1) = '<b>hello</b>'
```

## Acceptance Criteria

```smalltalk
RxbtLazyTest suite run printString
"All lazy tests pass."

RxbtMatcherTest suite run printString
"174 ran, 174 passed — no regression."
```

## Pitfalls

- `isLazy` must return `false` by default (when `lazy` slot is nil/unset in RxsPiece).
  Add: `RxsPiece compile: 'isLazy ^lazy == true' classified: 'testing'`.
- Lazy star epsilon guard is critical — same as greedy.
- `??` interacts with the lookaround detection in `piece`. The condition
  `atom isNullable ifTrue: [^self lookAround]` runs BEFORE checking for
  the second `?`. Make sure the lazy detection happens AFTER that check.
  (When atom is nullable, the `?` triggers lookaround, not a quantifier —
  no lazy variant needed there.)
