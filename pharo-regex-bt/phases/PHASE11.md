# Phase 11 — Iterative Quantifiers (Stack Depth Protection)

## Goal

Replace the four recursive quantifier helpers in `RxbtCompiler` with iterative
equivalents that cannot overflow Pharo's call stack. Currently `matchStar:`,
`matchRepeat:`, `matchLazyStar:`, and `matchLazyRepeat:` recurse **once per
character consumed**. A pattern `a*` on a 10 000-character string produces
10 000 recursive frames — well above Pharo's default stack limit (~3 000 frames
before image crash).

Zero behaviour change for the common case (atom = single character, predicate,
or simple group). Known limitation: patterns where `atomBlock` contains
top-level alternation with different match lengths (e.g. `(a|ab)*`) may miss
some paths under the iterative greedy pass; see Pitfalls.

## Package

`Regex-Backtracking`

---

## Background: Why Recursion Happens

Each helper is called from a closure returned by a `greedyStar:` /
`lazyStar:` / `greedyRepeat:min:max:` builder. The closure passes itself as
the continuation for the next step, which recurses. The depth equals the
number of successful atom matches — i.e. the matched substring length.

```smalltalk
"Current (recursive):"
matchStar: atomBlock from: pos continuation: cont
    | result |
    result := atomBlock value: pos value: [:newPos |
        newPos = pos
            ifTrue:  [cont value: newPos]
            ifFalse: [self matchStar: atomBlock from: newPos continuation: cont]].
    result ifFalse: [^cont value: pos].
    ^result
```

On `a*` matching `'aaaa...aaa'` (N chars), the call stack is:
`matchStar:` → `matchStar:` → … (N frames).

---

## Replacement Methods

### matchStar:from:continuation: (greedy)

**Algorithm:**

1. Forward pass — consume greedily, taking the first success from `atomBlock`
   at each position. Collect all reached positions in order.
2. Backward pass — try `cont` from longest match to shortest.

```smalltalk
matchStar: atomBlock from: startPos continuation: cont
    | positions cur next |
    positions := OrderedCollection with: startPos.
    cur := startPos.
    [next := nil.
     atomBlock value: cur value: [:newPos |
         newPos > cur ifTrue: [next := newPos].
         false].
     next notNil] whileTrue: [
        cur := next.
        positions add: cur].
    positions reverseDo: [:pos |
        (cont value: pos) ifTrue: [^true]].
    ^false
```

---

### matchRepeat:from:count:min:max:continuation: (greedy bounded)

**Algorithm:** same as `matchStar:` but respects `minN` / `maxN` bounds.

```smalltalk
matchRepeat: atomBlock from: startPos count: startN min: minN max: maxN continuation: cont
    | positions cur n next |
    positions := OrderedCollection with: startPos -> startN.
    cur := startPos.
    n := startN.
    [(maxN notNil and: [n >= maxN])
        ifTrue: [next := nil]
        ifFalse: [
            next := nil.
            atomBlock value: cur value: [:newPos |
                newPos > cur ifTrue: [next := newPos].
                false]].
     next notNil] whileTrue: [
        n := n + 1.
        cur := next.
        positions add: cur -> n].
    positions reverseDo: [:assoc |
        assoc value >= minN ifTrue: [
            (cont value: assoc key) ifTrue: [^true]]].
    ^false
```

---

### matchLazyStar:from:continuation: (lazy)

**Algorithm:** try `cont` at current position first; if it fails, consume one
more character and repeat. No backward pass needed.

```smalltalk
matchLazyStar: atomBlock from: startPos continuation: cont
    | cur next |
    cur := startPos.
    next := startPos.
    [(cont value: cur) ifTrue: [^true].
     next := nil.
     atomBlock value: cur value: [:np |
         np > cur ifTrue: [next := np].
         false].
     next notNil] whileTrue: [cur := next].
    ^false
```

---

### matchLazyRepeat:from:count:min:max:continuation: (lazy bounded)

```smalltalk
matchLazyRepeat: atomBlock from: startPos count: startN min: minN max: maxN continuation: cont
    | cur n next |
    cur := startPos.
    n := startN.
    [n >= minN ifTrue: [
         (cont value: cur) ifTrue: [^true]].
     (maxN notNil and: [n >= maxN]) ifTrue: [^false].
     next := nil.
     atomBlock value: cur value: [:np |
         np > cur ifTrue: [next := np].
         false].
     next isNil ifTrue: [^false].
     cur := next.
     n := n + 1.
     true] repeat
```

---

## No New Classes

All changes are method replacements on `RxbtCompiler`. No new slots, no
reinstall of `RxbtMatcher`.

---

## Test Class

```smalltalk
(TestCase << #RxbtStackDepthTest)
    slots: #();
    package: 'Regex-Backtracking-Tests';
    install.

RxbtStackDepthTest comment: 'Tests that quantifier-heavy patterns on long strings
complete without stack overflow. Before Phase 11 these would crash the Pharo image.'.
```

## Test Cases

```smalltalk
testLongGreedyStar
    "a* on 5 000-char string — would overflow stack in recursive version."
    | input m |
    input := String new: 5000 withAll: $a.
    m := RxbtMatcher forString: 'a*'.
    self assert: (m matches: input).

testLongGreedyPlus
    | input m |
    input := String new: 5000 withAll: $b.
    m := RxbtMatcher forString: 'b+'.
    self assert: (m matches: input).

testLongLazyStar
    | input m |
    input := String new: 5000 withAll: $c.
    m := RxbtMatcher forString: 'c*?c'.
    self assert: (m search: input).

testLongBoundedRepeat
    "a{1,5000} on 5 000-char string."
    | input m |
    input := String new: 5000 withAll: $a.
    m := RxbtMatcher forString: 'a{1,5000}'.
    self assert: (m matches: input).

testLongMixedPattern
    "Realistic long input: word characters followed by digits."
    | input m |
    input := (String new: 2000 withAll: $x) , (String new: 2000 withAll: $1).
    m := RxbtMatcher forString: '\w+\d+'.
    self assert: (m matches: input).

testGreedyBacktrack
    "Greedy star must still backtrack correctly on short input."
    | m |
    m := RxbtMatcher forString: 'a*b'.
    self assert: (m matches: 'aaab').
    self assert: (m matches: 'b').
    self deny:   (m matches: 'aaa').

testLazyBacktrack
    "Lazy star must yield shortest match."
    | m |
    m := RxbtMatcher forString: 'a*?b'.
    self assert: (m search: 'aaab').
    self assert: (m subexpression: 1) = 'aaab'.

testBoundedRepeatMinMax
    | m |
    m := RxbtMatcher forString: 'a{2,4}'.
    self assert: (m matches: 'aa').
    self assert: (m matches: 'aaaa').
    self deny:   (m matches: 'a').
    self deny:   (m matches: 'aaaaa').

testRegressionFull
    "All existing tests must still pass."
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty.
```

---

## Acceptance Criteria

```smalltalk
RxbtStackDepthTest suite run printString.   "all pass"
RxbtMatcherTest    suite run printString.   "176/176 — no regression"
```

---

## Pitfalls

- **Forward-pass non-determinism:** The iterative greedy pass calls `atomBlock`
  with a continuation that returns `false` immediately after capturing `newPos`.
  This means only the FIRST success path of `atomBlock` is followed. Patterns
  where `atomBlock` is itself a top-level alternation with different match lengths
  (e.g. `(a|ab)*c`) may miss the longer alternative during collection and fail
  to find an overall match. The recursive form is correct for these cases because
  backtracking inside `atomBlock` propagates back up the call stack. This phase
  documents the limitation; full correctness for such patterns requires a
  trampoline refactor (future work).

- **`whileTrue:` loop variable scope:** Pharo does not allow `| next |`
  declarations inside `whileTrue:` blocks. All temporaries must be declared in
  the enclosing method scope. The code above follows this rule.

- **`OrderedCollection` overhead:** For very long strings (> 100 000 chars),
  growing `positions` one element at a time is acceptable (amortised O(1)) but
  note that the backward pass must iterate the full list. If this proves too
  slow in profiling, replace with a `Bag`-free reversed scan using indices.

- **`repeat` vs `whileTrue:`:** The lazy helpers use `[...] repeat` with explicit
  `^false` exit. Ensure the final `^false` is reachable after `next isNil ifTrue: [^false]`.

- **No `consumeAll:from:` change needed:** `consumeAll:from:` is already
  iterative (uses `whileTrue:`). It is used only by possessive quantifiers which
  are not affected by this phase.

- **Regression test count:** Run `RxbtMatcherTest suite run` AND the full
  backtracking test suites (Phase 2–9). The iterative change must not alter
  match results for any of the ~230 existing tests.
