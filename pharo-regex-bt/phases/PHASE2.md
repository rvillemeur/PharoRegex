# Phase 2 — True Backtracking Validation

## Goal
Prove that `RxbtMatcher` provides true backtracking power by testing patterns
that **fail** in `RxMatcher` but **succeed** in `RxbtMatcher`.

These tests come from known backtracking failure cases in NFA-based greedy engines.

## Package
`Regex-Backtracking-Tests`

## Test Class

```smalltalk
TestCase subclass: #RxbtBacktrackingTest
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking-Tests'.
```

Helper methods:
```smalltalk
assertRegex: pattern matches: string subexpressions: expected
    "expected is nil or Array of (groupIdx string) pairs"
    | m result |
    m := RxbtMatcher forString: pattern.
    result := m search: string.
    self assert: result description: pattern , ' should match ' , string.
    expected isNil ifTrue: [^self].
    1 to: expected size by: 2 do: [:i |
        self
            assert: (m subexpression: (expected at: i)) = (expected at: i+1)
            description: 'Group ' , (expected at: i) printString]

assertRegex: pattern doesNotMatch: string
    | m |
    m := RxbtMatcher forString: pattern.
    self deny: (m search: string) description: pattern , ' should NOT match ' , string

assertRxMatcherFails: pattern on: string
    "Confirm the old engine fails this case (backtracking superiority)"
    | m |
    m := RxMatcher forString: pattern.
    self deny: (m search: string)
        description: 'RxMatcher should fail on ' , pattern , ' / ' , string
```

## Test Cases

### testAlternationBacktrack
`(a|ab)c` on `abc` — greedy NFA picks `a` for first alt, then `c` fails,
but RxMatcher doesn't backtrack to try `ab`. RxbtMatcher should succeed.

```smalltalk
testAlternationBacktrack
    self assertRxMatcherFails: '(a|ab)c' on: 'abc'.
    self assertRegex: '(a|ab)c' matches: 'abc' subexpressions: #(2 'a')
```

Wait — with left-to-right alternation AND backtracking, `(a|ab)c` tries `a` at 1,
then needs `c` at 2, but finds `b`. Backtracks. Tries `ab` at 1→2, then needs `c`
at 3, finds `c`. Match! Group 2 = 'ab'.

Correction: the match succeeds with group 2 = 'ab':
```smalltalk
testAlternationBacktrack
    self assertRxMatcherFails: '(a|ab)c' on: 'abc'.
    self assertRegex: '(a|ab)c' matches: 'abc' subexpressions: #(2 'ab')
```

### testGreedyStarBacktrack
`a*b` on `aaab` — greedy `a*` takes `aaa`, then needs `b`, finds `b`. 
Both engines pass this. BUT `(a*)a` on `aaa` — greedy `a*` takes `aaa`,
then needs `a`, fails. Backtrack: `a*` gives up one, tries `aa` then `a`. 

```smalltalk
testGreedyStarBacktrack
    self assertRegex: '(a*)a' matches: 'aaa' subexpressions: #(2 'aa').
    "Verify RxMatcher also passes this one (NFA handles it via structure)"
    self assert: (RxMatcher forString: '(a*)a') search: 'aaa'
```

### testNestedGroupBacktrack
`(a+)(a+)` on `aaaa` — greedy first `a+` takes all 4, second `a+` needs at least 1,
fails. Backtrack: first `a+` gives up one, second gets `a`. Group 2 = 'aaa', group 3 = 'a'.

```smalltalk
testNestedGroupBacktrack
    self assertRxMatcherFails: '(a+)(a+)' on: 'aaaa'.
    self assertRegex: '(a+)(a+)' matches: 'aaaa' subexpressions: #(2 'aaa' 3 'a')
```

### testOverlappingAlternatives
`(ab|a)(b|bc)c` on `abbc`:
- Try `ab` then `b` then `c`: position after `ab`=3, `b` at 3, `c` at 4 → but string is `abbc`, pos 4 = `c`? 
  string: a(1) b(2) b(3) c(4).
  `ab` matches pos 1-2 → pos=3. `b` matches pos 3 → pos=4. Need `c` at 4 → `c` = `c`. Match!
  group 2 = 'ab', group 3 = 'b'. ✓ Both engines may handle this.

Use a cleaner failing case: `(a|aa)(a|aa)b` on `aaab`.
- greedy engine: first group tries `aa` (longer alt if ordered by length), 
  but left-to-right: tries `a`, second group tries `a`, then `b` at pos 3 = `a` → fail.
  Backtrack: second group tries `aa` (pos 2-3), then `b` at pos 4 = `b`. ✓
  Group 2='a', group 3='aa'.

```smalltalk
testOverlappingAlternatives
    self assertRegex: '(a|aa)(a|aa)b' matches: 'aaab'
        subexpressions: #(2 'a' 3 'aa')
```

### testQuantifierBacktrackOnFailure  
`x*xy` on `xxxy` — greedy `x*` takes 3 `x`'s, then needs `x`, fails.
Backtrack: `x*` = `xx`, then `x` matches, then `y` matches. ✓

```smalltalk
testQuantifierBacktrackOnFailure
    self assertRegex: 'x*xy' matches: 'xxxy' subexpressions: nil
```

### testOptionalBacktrack
`<.+>` on `<a>b<c>` — greedy `.+` takes `a>b<c`, then needs `>`, fails.
Backtrack: `.+` = `a>b<`, then `>` at pos... wait let's use `<.+?>` for lazy
(Phase 3). For greedy backtracking: `<[^>]+>` is the idiomatic form. 

Use: `a?ab` on `ab` — `a?` greedily takes `a`, then needs `a`, finds `b`, fails.
Backtrack: `a?` = empty, then `a` matches, then `b` matches. ✓

```smalltalk
testOptionalBacktrack
    self assertRegex: 'a?ab' matches: 'ab' subexpressions: nil
```

### testCatastrophicBacktrackBound  
Verify engine doesn't infinite-loop on `(a+)+b` with `aaa` (no match).
Should return false, not hang. Set a reasonable expectation.

```smalltalk
testCatastrophicBacktrackTerminates
    "Should return false quickly, not hang"
    | m |
    m := RxbtMatcher forString: '(a+)+b'.
    self deny: (m matches: 'aaaa')
```

## Acceptance Criteria

```smalltalk
RxbtBacktrackingTest suite run printString
"All tests pass. RxbtMatcherTest still passes (174 ran, 174 passed)."
```
