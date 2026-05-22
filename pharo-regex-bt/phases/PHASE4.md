# Phase 4 — Backreferences

## Goal
Add backreferences `\1` through `\9`. A backreference matches the SAME TEXT
that was matched by the corresponding capture group earlier in the pattern.

Backreferences require a backtracking engine to be meaningful — they cannot
be implemented in a pure NFA-based engine.

## Package
`Regex-Backtracking`

## New AST Node

```smalltalk
RxsNode subclass: #RxsBackreference
    instanceVariableNames: 'groupIndex'
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking'.

RxsBackreference compile: 'groupIndex ^groupIndex' classified: 'accessing'.
RxsBackreference compile: 'groupIndex: n groupIndex := n' classified: 'initialize'.
RxsBackreference compile: 'isNullable ^false' classified: 'testing'.
RxsBackreference compile: 'isAtomic ^true' classified: 'testing'.
RxsBackreference compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxBackreference: self' classified: 'double dispatch'.
```

## Parser Changes

In `RxParser>>atom`, handle `\1` through `\9`:

The existing code handles `\` followed by a character. Backreferences come from
`\` followed by a digit (`$1` to `$9`). Digits are NOT in `BackslashConstants`
or `BackslashSpecials`, so they fall through to the "regular character" case.

Override this by checking for digit AFTER `\`:

```smalltalk
"In RxParser>>atom, in the backslash handling section, add before the ifSpecial:then: check:"
lookahead isDigit
    ifTrue: [
        | n |
        n := lookahead digitValue.
        n = 0 ifTrue: [self signalParseError: 'backreference \\0 is invalid'].
        self next.
        ^RxsBackreference new groupIndex: n].
```

Note: `BackslashConstants` contains `$n`, `$t`, `$r` etc., and `BackslashSpecials`
contains `$d`, `$w`, `$s`, `$b`, `$B` etc. Digits 1-9 are not in either, so the
insertion point is after the `ifSpecial:then:` check but before the fallthrough.

Check `RxParser>>atom` source carefully and insert at the right location.

## Matcher Changes

Add `syntaxBackreference:` to `RxbtMatcher`:

```smalltalk
syntaxBackreference: node
    | n |
    n := node groupIndex.
    ^[:pos :cont |
        | start end refText sz |
        start := captures at: 2 * n - 1.
        end   := captures at: 2 * n.
        (start isNil or: [end isNil]) ifTrue: [^false].  "group not yet matched"
        refText := inputString copyFrom: start to: end - 1.
        sz := refText size.
        (pos + sz - 1 > inputString size) ifTrue: [^false].
        (ignoreCase
            ifTrue:  [(inputString copyFrom: pos to: pos + sz - 1) asLowercase =
                       refText asLowercase]
            ifFalse: [(inputString copyFrom: pos to: pos + sz - 1) = refText])
            ifFalse: [^false].
        cont value: pos + sz]
```

## Group Index vs Marker Index

`\1` refers to subexpression 1 (the whole match). But in practice, `\1` in most
regex flavours refers to the FIRST EXPLICIT group, which is subexpression 2 in
Pharo's convention (since subexpression 1 = whole match).

**Design choice**: Follow Perl/PCRE convention where `\1` = first explicit `(...)`.
This means `\1` → groupIndex=2 in terms of marker positions.

Two options:
1. Parser sets `groupIndex` to the 1-based EXPLICIT group number (1 = first `(...)`).
   Matcher translates: `n := node groupIndex + 1` (to get the full marker index).
2. Parser sets `groupIndex` to the full subexpression index (2 = first `(...)`).

**Recommendation**: Use option 1 — store explicit group number (1-based) in the AST node.
In `syntaxBackreference:`, translate: `n := node groupIndex + 1` when computing
marker positions, so `\1` → marker pair at `captures at: 3` / `captures at: 4`.

BUT — verify against `RxMatcher` group numbering. From Phase 1 verification:
```
(RxMatcher forString: '(a+)(b+)') search: 'aaabbb'.
subexpression: 1 → 'aaabbb'   (whole match)
subexpression: 2 → 'aaa'      (first group)
subexpression: 3 → 'bbb'      (second group)
```

So `\1` should match `aaa` (first explicit group = subexpression 2).
In `syntaxBackreference:`, use: `n := node groupIndex + 1` (node stores 1, we use 2).

## Test Class

```smalltalk
TestCase subclass: #RxbtBackreferenceTest
    instanceVariableNames: ''
    classVariableNames: ''
    poolDictionaries: ''
    category: 'Regex-Backtracking-Tests'.
```

## Test Cases

### testSimpleBackreference
```smalltalk
testSimpleBackreference
    "Match doubled word"
    self assert: (RxbtMatcher forString: '(a+)\1') matches: 'aaaa'.
    self deny:   (RxbtMatcher forString: '(a+)\1') matches: 'aaa'.
    self assert: (RxbtMatcher forString: '(a+)\1') matches: 'aa'.
```

### testDoubledWord
```smalltalk
testDoubledWord
    | m |
    m := RxbtMatcher forString: '\b(\w+)\s+\1\b'.
    self assert: (m search: 'the the quick fox').
    self assert: (m subexpression: 1) = 'the the'.
    self assert: (m subexpression: 2) = 'the'.
    
    self deny: (m search: 'the quick brown fox')
```

### testBackreferenceWithAlternation
```smalltalk
testBackreferenceWithAlternation
    "Backreference must match what was actually captured"
    | m |
    m := RxbtMatcher forString: '(cat|dog)\1'.
    self assert: (m matches: 'catcat').
    self assert: (m matches: 'dogdog').
    self deny:   (m matches: 'catdog').
    self deny:   (m matches: 'dogcat')
```

### testBackreferenceBeforeGroup
```smalltalk
testBackreferenceBeforeGroup
    "Backreference to group not yet matched → fail"
    | m |
    m := RxbtMatcher forString: '\1(a)'.
    self deny: (m matches: 'aa')  "group 1 not matched when \1 is evaluated"
```

### testCaseInsensitiveBackreference
```smalltalk
testCaseInsensitiveBackreference
    | m |
    m := RxbtMatcher forString: '(Hello)\s+\1' ignoreCase: true.
    self assert: (m matches: 'Hello hello').
    self assert: (m matches: 'HELLO hello')
```

### testMultipleBackreferences
```smalltalk
testMultipleBackreferences
    | m |
    m := RxbtMatcher forString: '(a)(b)\2\1'.
    self assert: (m matches: 'abba').
    self deny:   (m matches: 'abab')
```

### testBackreferenceWithQuantifier
```smalltalk
testBackreferenceWithQuantifier
    "Group is quantified, backreference matches final capture"
    | m |
    m := RxbtMatcher forString: '(a+)\1'.
    self assert: (m matches: 'aaaa').   "group1='aa', backref='aa'"
    self deny:   (m matches: 'aaa').    "no split of 'aaa' gives equal halves"
    self assert: (m matches: 'aa').     "group1='a', backref='a'"
```

## Acceptance Criteria

```smalltalk
RxbtBackreferenceTest suite run printString.
"All backreference tests pass."

RxbtMatcherTest suite run printString.
"174 ran, 174 passed — no regression."

RxbtLazyTest suite run printString.
"No regression."
```

## Pitfalls

- The existing `RxParser` compiles `\d` as `$d` via `BackslashSpecials`. Verify
  that `$1` through `$9` are NOT in that dictionary before inserting the digit check.
- Empty backreference: if the group matched empty string (`start = end`), the
  backreference matches empty and always succeeds (zero-length match). Handle correctly.
- Group index out of range: if `\5` is used but there are only 3 groups,
  treat as failure (group not matched → nil captures).
- The `captures` array at match time may be nil for groups not yet reached.
  Always check for nil before using.
