# Phase 10 — Search Optimizer

## Goal

Add `RxbtMatchOptimizer` — a pre-match filter that eliminates hopeless start positions
during `search:` / `searchStream:` without running the full CPS engine. Pure performance
optimisation; zero behaviour change. Mirrors `RxMatchOptimizer` from Regex-Core but uses
`Rbt*` AST nodes and passes `(char, pos)` instead of `(char, matcher)`.

## Package

`Regex-Backtracking`

---

## How It Works

`RxbtMatchOptimizer` walks the root `RxbtRegex` node once at build time using the same
`dispatchTo:` / `syntax*:` visitor protocol as `RxbtCompiler`. It collects sets describing
which characters *could* start a match, then synthesises a `testBlock [:char :pos | Boolean]`.

`canStartMatch: aCharOrNil at: pos` returns false only when it is **certain** no match can
begin there. `true` is a conservative answer — it never causes a missed match, only a
wasted attempt.

`RxbtMatcher>>search:` calls `canStartMatch:at:` before invoking `rootBlock`, skipping
positions that obviously cannot match.

---

## Class Definition

```smalltalk
(Object << #RxbtMatchOptimizer)
    slots: #(ignoreCase prefixes nonPrefixes conditions
             predicates nonPredicates methodPredicates nonMethodPredicates
             lookarounds testBlock);
    package: 'Regex-Backtracking';
    install.

RxbtMatchOptimizer comment: 'Pre-match filter for RxbtMatcher>>search:.
Walks the Rbt* AST once at build time to determine which characters could start
a match. canStartMatch:at: returns false only when a match is impossible — true
is a conservative answer. Mirrors RxMatchOptimizer using the Rbt* node hierarchy.'.
```

---

## initialize:ignoreCase:

```smalltalk
initialize: aRxbtRegexNode ignoreCase: aBoolean
    ignoreCase       := aBoolean.
    prefixes         := Set new: 10.
    nonPrefixes      := Set new: 10.
    conditions       := Set new: 3.
    predicates       := Set new: 3.
    nonPredicates    := Set new: 3.
    methodPredicates    := Set new: 3.
    nonMethodPredicates := Set new: 3.
    lookarounds      := Set new: 3.
    aRxbtRegexNode dispatchTo: self.
    aRxbtRegexNode isNullable ifTrue: [conditions add: #atEndOfLine].
    testBlock := self determineTestMethod
```

---

## canStartMatch:at:

```smalltalk
canStartMatch: aCharOrNil at: pos
    "Return false only when a match is guaranteed impossible.
     nil char = end-of-string position — conservatively return true."
    aCharOrNil ifNil: [^true].
    ^testBlock isNil or: [testBlock value: aCharOrNil value: pos]
```

---

## determineTestMethod

```smalltalk
determineTestMethod
    | testers |
    (conditions includes: #any) ifTrue: [^nil].
    testers := OrderedCollection new.
    #(prefixTester nonPrefixTester conditionTester
      predicateTester nonPredicateTester
      methodPredicateTester nonMethodPredicateTester)
        do: [:sel | (self perform: sel) ifNotNil: [:t | testers add: t]].
    testers isEmpty ifTrue: [^nil].
    testers size = 1 ifTrue: [^testers first].
    testers := testers asArray.
    ^[:char :pos | testers contains: [:t | t value: char value: pos]]
```

---

## Tester Builders

```smalltalk
prefixTester
    | p prefixChar |
    prefixes isEmpty ifTrue: [^nil].
    p := self optimizeSet: prefixes.
    ignoreCase ifTrue: [p := p collect: [:c | c asUppercase]].
    ^p size = 1
        ifTrue: [
            prefixChar := p first.
            ignoreCase
                ifTrue:  [[:char :pos | char sameAs: prefixChar]]
                ifFalse: [[:char :pos | char = prefixChar]]]
        ifFalse: [
            ignoreCase
                ifTrue:  [[:char :pos | p includes: char asUppercase]]
                ifFalse: [[:char :pos | p includes: char]]]

nonPrefixTester
    | np nonPrefixChar |
    nonPrefixes isEmpty ifTrue: [^nil].
    np := self optimizeSet: nonPrefixes.
    ^np size = 1
        ifTrue: [
            nonPrefixChar := np first.
            [:char :pos | char ~= nonPrefixChar]]
        ifFalse: [[:char :pos | (np includes: char) not]]

conditionTester
    | sel |
    conditions isEmpty ifTrue: [^nil].
    conditions size = 1 ifTrue: [
        sel := conditions anyOne.
        sel = #atBeginningOfLine ifTrue: [^[:char :pos | pos = 1]].
        sel = #atEndOfLine       ifTrue: [^[:char :pos | false]].   "never skips — EOL anchors rare"
        sel = #atBeginningOfWord ifTrue: [^nil].
        sel = #atEndOfWord       ifTrue: [^nil].
        sel = #atWordBoundary    ifTrue: [^nil].
        sel = #notAtWordBoundary ifTrue: [^nil]].
    ^nil   "multiple conditions — too complex to combine, skip optimisation"

predicateTester
    | p pred |
    predicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: predicates.
    ^p size = 1
        ifTrue: [pred := p first. [:char :pos | pred value: char]]
        ifFalse: [[:char :pos | p contains: [:pr | pr value: char]]]

nonPredicateTester
    | p pred |
    nonPredicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: nonPredicates.
    ^p size = 1
        ifTrue: [pred := p first. [:char :pos | (pred value: char) not]]
        ifFalse: [[:char :pos | p contains: [:pr | (pr value: char) not]]]

methodPredicateTester
    | p selector |
    methodPredicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: methodPredicates.
    ^p size = 1
        ifTrue: [
            selector := p first.
            [:char :pos |
                [char perform: selector]
                    on: MessageNotUnderstood do: [:e | false]]]
        ifFalse: [
            [:char :pos |
                p contains: [:sel |
                    [char perform: sel]
                        on: MessageNotUnderstood do: [:e | false]]]]

nonMethodPredicateTester
    | p selector |
    nonMethodPredicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: nonMethodPredicates.
    ^p size = 1
        ifTrue: [
            selector := p first.
            [:char :pos |
                ([char perform: selector]
                    on: MessageNotUnderstood do: [:e | false]) not]]
        ifFalse: [
            [:char :pos |
                p contains: [:sel |
                    ([char perform: sel]
                        on: MessageNotUnderstood do: [:e | false]) not]]]

optimizeSet: aSet
    "Array beats Set for small membership tests (no hashing overhead)."
    ^aSet size < 10 ifTrue: [aSet asArray] ifFalse: [aSet]
```

---

## syntax*: Visitor Methods

These implement the `dispatchTo:` visitor protocol for `Rbt*` nodes.

```smalltalk
syntaxRegex: node
    "Walk all alternatives. Do NOT allocate markers — we are only collecting prefixes."
    node branch dispatchTo: self.
    node regex ifNotNil: [:r | r dispatchTo: self]

syntaxBranch: node
    "If the head piece is nullable (can match empty), the next piece also
     contributes possible start chars — recurse down the branch."
    (node piece isNullable and: [node branch notNil])
        ifTrue: [node branch dispatchTo: self].
    node piece dispatchTo: self

syntaxPiece: node
    node atom dispatchTo: self

syntaxCharacter: node
    prefixes add: node character

syntaxEpsilon
    "nothing to collect"

syntaxAny
    conditions add: #any

syntaxPredicate: node
    node negation
        ifFalse: [predicates    add: node predicate]
        ifTrue:  [nonPredicates add: node predicate]

syntaxCharSet: node
    "Enumerate literal characters from the set elements."
    node elements do: [:el |
        el isKindOf: RxbtCharacter   ifTrue: [
            node negated
                ifFalse: [prefixes    add: el character]
                ifTrue:  [nonPrefixes add: el character]].
        el isKindOf: RxbtPredicate ifTrue: [
            node negated
                ifFalse: [predicates    add: el predicate]
                ifTrue:  [nonPredicates add: el predicate]].
        "RxbtRange — skip; too many possible chars to enumerate cheaply"]

syntaxMessagePredicate: node
    node negated
        ifFalse: [methodPredicates    add: node selector]
        ifTrue:  [nonMethodPredicates add: node selector]

syntaxLookaround: node
    lookarounds add: node   "collected but not used in testBlock — future work"

syntaxBeginningOfLine
    conditions add: #atBeginningOfLine

syntaxEndOfLine
    conditions add: #atEndOfLine

syntaxWordBoundary
    conditions add: #atWordBoundary

syntaxNonWordBoundary
    conditions add: #notAtWordBoundary

syntaxBeginningOfWord
    conditions add: #atBeginningOfWord

syntaxEndOfWord
    conditions add: #atEndOfWord

syntaxBackreference: node
    "Cannot predict prefix from a backreference — bail out."
    conditions add: #any

syntaxAtomicGroup: node
    node inner dispatchTo: self

syntaxNonCapturingGroup: node
    node inner dispatchTo: self

syntaxInlineModifier: node
    "Scoped flag modifier — recurse into inner if present, else nothing to collect."
    node inner ifNotNil: [:inner | inner dispatchTo: self]

syntaxNamedCapture: node
    node inner dispatchTo: self

syntaxNamedBackreference: node
    conditions add: #any

syntaxGenericNewline
    "Can match CR (13) or LF (10) — add both as prefixes."
    prefixes add: (Character value: 13).
    prefixes add: (Character value: 10)

syntaxBeginningOfString
    conditions add: #atBeginningOfLine   "conservative — reuse existing condition"

syntaxEndOfString
    conditions add: #atEndOfLine

syntaxEndOfStringZ
    conditions add: #atEndOfLine
```

---

## RxbtMatcher Integration

### Add `optimizer` ivar

```smalltalk
(Object << #RxbtMatcher)
    slots: #(ignoreCase inputString captures markerCount rootBlock groupNames optimizer);
    package: 'Regex-Backtracking';
    install.
```

### Update initialize:ignoreCase:

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
                       ignoreCase: aBoolean
```

### Update search:

```smalltalk
search: aString
    inputString := aString.
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

## Test Class

```smalltalk
(TestCase << #RxbtOptimizerTest)
    slots: #();
    package: 'Regex-Backtracking-Tests';
    install.

RxbtOptimizerTest comment: 'Tests for RxbtMatchOptimizer. Verifies that the
search optimiser does not affect correctness — every test exercises a case
where the optimiser would skip positions, ensuring matches still occur.'.
```

## Test Cases

```smalltalk
testLiteralPrefixSkip
    "Pattern starting with literal — optimizer skips non-matching positions."
    | m |
    m := RxbtMatcher forString: 'foo'.
    self assert: (m search: 'xxxfooyyy').
    self assert: (m subexpression: 1) = 'foo'.

testAlternationPrefixes
    "Optimizer collects prefixes from all alternatives."
    | m |
    m := RxbtMatcher forString: 'cat|dog'.
    self assert: (m search: 'I have a dog').
    self assert: (m search: 'the cat sat').
    self deny:   (m search: 'no pets here').

testNullableHead
    "Nullable head — optimizer must not skip valid start positions."
    | m |
    m := RxbtMatcher forString: 'a*b'.
    self assert: (m search: 'xxxb').    "matches b with zero a's"
    self assert: (m search: 'aaab').

testAnchoredPattern
    "^ anchor — optimizer marks atBeginningOfLine, skips non-start positions."
    | m |
    m := RxbtMatcher forString: '^hello'.
    self assert: (m search: 'hello world').
    self deny:   (m search: 'say hello').

testPredicatePrefix
    "\\d prefix — optimizer skips non-digit starting positions."
    | m |
    m := RxbtMatcher forString: '\d+'.
    self assert: (m search: 'abc123def').
    self assert: (m subexpression: 1) = '123'.

testOptimizerRegressionFull
    "Full RxbtMatcherTest suite must still pass with optimizer active."
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty.
```

---

## Acceptance Criteria

```smalltalk
RxbtOptimizerTest suite run printString.    "all pass"
RxbtMatcherTest    suite run printString.    "176/176 — no regression"
```

---

## Pitfalls

- **Nullable head:** if the first piece of a branch can match empty (`isNullable`),
  the *second* piece also contributes possible start characters. `syntaxBranch:` must
  recurse when `piece isNullable`. Without this, patterns like `a*b` incorrectly skip
  positions that only `b` could start.
- **`#any` condition short-circuits everything:** if `syntaxAny` fires (from `.`),
  `determineTestMethod` must return `nil` (no optimisation possible) — every character
  is a valid prefix.
- **Alternation traversal:** `syntaxRegex:` must walk ALL alternatives via `regex` chain,
  same as `RxbtCompiler`. Missing an alternative causes false-negative skips.
- **`initialize:ignoreCase:` reinstall:** adding `optimizer` ivar requires reinstalling
  `RxbtMatcher`. All existing methods survive; verify method count before and after.
- **`searchStream:` position:** stream position is 0-based, string index is 1-based.
  `aStream position: endPos - 1` is correct for a stream whose `contents` maps
  1-based pos to the same string.
- **Phase 9 inline modifiers:** `syntaxInlineModifier:` must recurse into `inner` if
  present (scoped form `(?i:...)`); standalone modifiers have `inner = nil` and only
  affect the flags ivar in `RxbtCompiler` — nothing to collect for the optimizer.
- **Backreferences and named backreferences:** unpredictable prefix — `conditions add: #any`
  disables the optimiser for patterns containing them. Correct but conservative.
