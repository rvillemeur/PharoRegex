# Phase 5 — Possessive Quantifiers & Atomic Groups

## Goal
Add possessive quantifiers (`*+`, `++`, `?+`, `{n,m}+`) and atomic groups `(?>...)`.

Possessive quantifiers match greedily but **never give back** matched characters.
They prevent backtracking into the quantifier, which can improve performance and
enable patterns impossible with standard backtracking.

## Package
`Regex-Backtracking`

## Possessive Quantifiers

### Parser Changes

In `RxParser>>piece`, after each quantifier, check for trailing `+`:

```smalltalk
piece
    | atom lazy possessive |
    atom := self atom.
    
    lookahead = $*
        ifTrue: [
            self next.
            atom isNullable ifTrue: [self signalNullableClosureParserError].
            lazy       := lookahead = $?. lazy ifTrue: [self next].
            possessive := (lazy not and: [lookahead = $+]). possessive ifTrue: [self next].
            lazy       ifTrue: [^RxsPiece new initializeLazyStarAtom: atom].
            possessive ifTrue: [^RxsPiece new initializePossessiveStarAtom: atom].
            ^RxsPiece new initializeStarAtom: atom].
    "... similarly for + and ?"
```

Add `possessive` slot to `RxsPiece` (or add method returning false by default):
```smalltalk
RxsPiece compile: 'isPossessive ^possessive == true' classified: 'testing'.
RxsPiece compile: 'becomePossessive possessive := true' classified: 'initialize'.
RxsPiece compile: 'initializePossessiveStarAtom: anAtom
    self initializeStarAtom: anAtom. self becomePossessive' classified: 'initialize'.
RxsPiece compile: 'initializePossessivePlusAtom: anAtom
    self initializePlusAtom: anAtom. self becomePossessive' classified: 'initialize'.
RxsPiece compile: 'initializePossessiveOptionalAtom: anAtom
    self initializeOptionalAtom: anAtom. self becomePossessive' classified: 'initialize'.
```

### syntaxPiece: update

```smalltalk
syntaxPiece: pieceNode
    | atomBlock |
    atomBlock := pieceNode atom dispatchTo: self.
    pieceNode isSingular ifTrue: [^atomBlock].
    pieceNode isPossessive
        ifTrue: [
            pieceNode isStar     ifTrue: [^self possessiveStar: atomBlock].
            pieceNode isPlus     ifTrue: [^self possessivePlus: atomBlock].
            pieceNode isOptional ifTrue: [^self possessiveOptional: atomBlock].
            ^self possessiveRepeat: atomBlock min: pieceNode min max: pieceNode max].
    pieceNode isLazy
        ifTrue: [...].  "Phase 3 code"
    ...   "greedy — Phase 1 code"
```

### Possessive Matcher Methods

Possessive = match greedily to find the final position, then call cont with that
fixed position. If cont fails, return false immediately (no backtracking).

```smalltalk
possessiveStar: atomBlock
    ^[:pos :cont |
        | finalPos |
        finalPos := self consumeAll: atomBlock from: pos.
        cont value: finalPos]

consumeAll: atomBlock from: pos
    "Greedily consume as many matches as possible, return final position."
    | cur |
    cur := pos.
    [atomBlock value: cur value: [:newPos |
        newPos = cur ifTrue: [cur := newPos. false]  "epsilon: stop"
        ifFalse: [cur := newPos. true]]  "continue"
    ] whileTrue.
    ^cur

possessivePlus: atomBlock
    ^[:pos :cont |
        | firstPos |
        firstPos := nil.
        atomBlock value: pos value: [:p | firstPos := p. false].  "try first match"
        firstPos isNil ifTrue: [^false].
        | finalPos |
        finalPos := self consumeAll: atomBlock from: firstPos.
        cont value: finalPos]

possessiveOptional: atomBlock
    ^[:pos :cont |
        | result |
        atomBlock value: pos value: [:newPos |
            result := newPos. false].
        cont value: (result ifNil: [pos] ifNotNil: [:r | r])]

possessiveRepeat: atomBlock min: minN max: maxN
    ^[:pos :cont |
        | finalPos count |
        count := 0.
        finalPos := pos.
        [(maxN isNil or: [count < maxN]) and: [
            atomBlock value: finalPos value: [:newPos |
                newPos = finalPos ifTrue: [false]
                ifFalse: [count := count + 1. finalPos := newPos. true]]]]
            whileTrue.
        count < minN ifTrue: [^false].
        cont value: finalPos]
```

Note: `consumeAll:from:` uses a while loop — this avoids deep recursion for
long inputs. The possessive contract: position is fixed after matching, cont gets
one shot.

## Atomic Groups `(?>...)`

Atomic groups match their inner pattern and then "cut" — no backtracking into them.

### New AST Node

```smalltalk
RxsNode subclass: #RxsAtomicGroup
    instanceVariableNames: 'inner'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking'.

RxsAtomicGroup compile: 'inner ^inner' classified: 'accessing'.
RxsAtomicGroup compile: 'inner: aNode inner := aNode' classified: 'initialize'.
RxsAtomicGroup compile: 'isNullable ^inner isNullable' classified: 'testing'.
RxsAtomicGroup compile: 'isAtomic ^true' classified: 'testing'.
RxsAtomicGroup compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxAtomicGroup: self' classified: 'double dispatch'.
```

### Parser Changes

In `RxParser>>atom`, handle `(?>...)`:

```smalltalk
"When atom sees '(' and peek is '?':"
lookahead = $(
    ifTrue: [
        self match: $(.
        "Check for special (?...) forms"
        lookahead = $?
            ifTrue: [
                "Look at character after ?"
                "(?> ... ) = atomic group"
                "This requires peeking TWO chars ahead."
                "Strategy: use input stream position."
                ...
            ].
        atom := self regex.
        self match: $).
        ^atom]
```

The challenge: the parser is a 1-character lookahead parser. For `(?>...)`,
after seeing `(?`, we need to see `>`.

Current lookahead after `(` is `?`. After consuming `?`, lookahead becomes `>`.

In the existing `piece` method, `?` after an epsilon atom triggers `lookAround`.
But `(?>` comes from INSIDE the atom parsing of `(`. Here's the sequence:
1. `atom` sees `(`
2. Calls `self match: $(` — lookahead advances to `?`
3. `?` is in the atom-epsilon list, so a simple call to `self regex` inside `(`
   would parse `?` as epsilon, then `>` as a regular char...

Better approach: before calling `self regex` inside `(`, check if lookahead is `?`:

```smalltalk
lookahead = $(
    ifTrue: [
        self match: $(.
        lookahead = $?
            ifTrue: [
                self next.  "consume ?"
                lookahead = $>
                    ifTrue: [
                        self next.  "consume >"
                        atom := self regex.
                        self match: $).
                        ^RxsAtomicGroup new inner: atom].
                "Otherwise: existing lookaround handling — but we already consumed ?"
                "Must handle (?= and (?! here"
                ^self lookAround].  "lookahead is now = or !"
        atom := self regex.
        self match: $).
        ^atom]
```

This requires moving the `(?` special form detection INTO `atom` rather than
having it triggered by `piece` via the nullable-epsilon trick.

Verify against existing `(?=...)` parsing to avoid breaking it.

### Matcher Method

```smalltalk
syntaxAtomicGroup: node
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    ^[:pos :cont |
        | endPos found |
        found := false.
        innerBlock value: pos value: [:ep | endPos := ep. found := true. false].
        "false returned from inner cont means: record pos, stop matching inner"
        found ifFalse: [^false].
        cont value: endPos]
```

Wait — `innerBlock` needs to run to COMPLETION (find the greedy end position).
But the closure structure means the inner block's continuation controls when to stop.

Simpler: run the inner block with a continuation that records the end position
and immediately returns false to prevent inner backtracking:

```smalltalk
syntaxAtomicGroup: node
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    ^[:pos :cont |
        | endPos |
        endPos := nil.
        innerBlock value: pos value: [:ep | endPos := ep. false].
        "The false return causes innerBlock to try all alternatives and settle on
         the FIRST one that works (greedy inner matching, no inner backtracking).
         Actually this records the last successful inner pos... need rethinking."
```

Actually this is subtle. The atomic group should:
1. Try to match `inner` at `pos`
2. If it succeeds, record the end position
3. Call `cont` with that end position
4. If `cont` fails, return false (don't retry inner with shorter match)

The trick: use a separate "try match" that runs `inner` and returns the first
successful end position:

```smalltalk
syntaxAtomicGroup: node
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    ^[:pos :cont |
        | endPos |
        endPos := nil.
        innerBlock value: pos value: [:ep |
            endPos isNil ifTrue: [endPos := ep].
            true].  "stop at first success"
        endPos isNil ifTrue: [^false].  "inner didn't match"
        cont value: endPos]
```

But `true` as the continuation result means "matched" — so `innerBlock` returns true.
The issue is that `innerBlock` itself continues matching after calling the continuation.
With greedy inner matching and `true` return from cont, the innerBlock's greedy loop
would continue trying larger matches...

**Cleaner solution**: wrap in a non-local return escape:

```smalltalk
syntaxAtomicGroup: node
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    ^[:pos :cont |
        | endPos |
        endPos := nil.
        [innerBlock value: pos value: [:ep | endPos := ep. Error signal: 'cut']]
            on: Error do: [:e | e messageText = 'cut' ifFalse: [e return]].
        endPos isNil ifTrue: [^false].
        cont value: endPos]
```

This is hacky. The idiomatic Pharo approach: use a non-local return from a block.
But blocks don't support non-local returns from within `value:`.

**Best approach**: add a `findFirst: atomBlock from: pos` helper that returns the
first match position without running the full CPS chain:

```smalltalk
tryMatchFirst: innerBlock from: pos
    "Run innerBlock, return first successful end position or nil."
    | endPos |
    endPos := nil.
    innerBlock value: pos value: [:ep |
        endPos := ep.
        "Return false to simulate failure — causes innerBlock to not continue"
        false].
    "If innerBlock tried alternatives and one set endPos, it may try more.
     We only want the FIRST. Use a flag:"
    ^endPos

"This works for the closure structure because:"
"When innerBlock calls its cont (our block) and gets false back,"
"it backtracks. But we recorded the FIRST successful ep already."
"However, with greedy quantifiers, the LAST recorded ep would be the greedy match."
"For atomic groups, we want the greedy match (first try by the inner block)."
"Since the CPS greedy star tries MOST first and falls back: the first ep we"
"get from the cont IS the greedy maximum."
```

Actually with the CPS greedy implementation: `greedyStar` tries max first (recursive).
The FIRST time the continuation is called is with the MAXIMUM match. So `endPos`
will be set to the greedy maximum first. Returning false makes it backtrack, but
we've already captured `endPos`. ✓

```smalltalk
syntaxAtomicGroup: node
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    ^[:pos :cont |
        | endPos |
        endPos := nil.
        innerBlock value: pos value: [:ep |
            endPos isNil ifTrue: [endPos := ep].
            false].   "reject all — capture first (=greedy max) and bail"
        endPos isNil ifTrue: [^false].
        cont value: endPos]
```

## Test Class

```smalltalk
TestCase subclass: #RxbtPossessiveTest
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking-Tests'.
```

## Test Cases

### testPossessiveStar
```smalltalk
testPossessiveStar
    "a*+a — possessive star takes all a's, then a fails (no backtrack)"
    self deny: (RxbtMatcher forString: 'a*+a') matches: 'aaa'.
    "Contrast with greedy:"
    self assert: (RxbtMatcher forString: 'a*a') matches: 'aaa'
```

### testPossessivePlus
```smalltalk
testPossessivePlus
    self deny: (RxbtMatcher forString: 'a++a') matches: 'aaa'.
    self assert: (RxbtMatcher forString: 'a++b') matches: 'aaab'
```

### testPossessiveOptional
```smalltalk
testPossessiveOptional
    "a?+a — possessive optional takes a (if present), then a fails"
    self deny: (RxbtMatcher forString: 'a?+a') matches: 'a'.
    self assert: (RxbtMatcher forString: 'a?+b') matches: 'ab'.
    self assert: (RxbtMatcher forString: 'a?+b') matches: 'b'
```

### testAtomicGroup
```smalltalk
testAtomicGroup
    "Atomic group: match then cut"
    self deny: (RxbtMatcher forString: '(?>a+)a') matches: 'aaa'.
    self assert: (RxbtMatcher forString: '(?>a+)b') matches: 'aaab'
```

### testAtomicGroupVsNormal
```smalltalk
testAtomicGroupVsNormal
    "(a+)a backtracks, (?>a+)a does not"
    self assert: (RxbtMatcher forString: '(a+)a') matches: 'aaa'.
    self deny:   (RxbtMatcher forString: '(?>a+)a') matches: 'aaa'
```

### testPossessivePerformance
```smalltalk
testPossessivePerformance
    "Possessive prevents catastrophic backtracking"
    | m bigString |
    bigString := String new: 100 withAll: $a.
    m := RxbtMatcher forString: 'a*+b'.
    "Should return quickly (no backtracking explosion)"
    self deny: (m matches: bigString)
```

## Acceptance Criteria

```smalltalk
RxbtPossessiveTest suite run printString.
"All possessive tests pass."

"Full regression:"
RxbtMatcherTest suite run printString.      "174 ran, 174 passed"
RxbtBacktrackingTest suite run printString. "all pass"
RxbtLazyTest suite run printString.         "all pass"
RxbtBackreferenceTest suite run printString. "all pass"
```

## Pitfalls

- `(?>...)` syntax interacts with the existing `(?=...)` / `(?!...)` lookaround parsing.
  The parser must correctly route `(?>` to atomic group and `(?=` / `(?!` to lookaround.
- The `consumeAll:from:` loop for possessive star must guard against epsilon matches
  (same as greedy star).
- Atomic group does NOT allocate a capture group. Its content is not capturable
  (though explicit `(...)` inside it do capture normally).
- Possessive and lazy are mutually exclusive — `*?+` is invalid. Add a parse error.
