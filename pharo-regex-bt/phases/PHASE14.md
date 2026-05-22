# Phase 14 — Packaging: API Audit & BaselineOf

## Goal

Make `Regex-Backtracking` a proper, loadable, shareable package.

1. **Part A — Public API audit:** Verify every public method on `RxMatcher`
   exists on `RxbtMatcher` and behaves identically.
2. **Part B — `BaselineOfRegexBacktracking`:** Metacello baseline so the
   package loads from a repository without manual image surgery.

## Package

`Regex-Backtracking` (new: also `BaselineOfRegexBacktracking`)

---

## Part A — Public API Audit

### Methods to Verify

These are the public methods on `RxMatcher`. Each must exist on `RxbtMatcher`
and return the same result for the same input.

| Method | Status | Notes |
|--------|--------|-------|
| `forString:` (class) | likely OK | constructor |
| `forString:ignoreCase:` (class) | likely OK | constructor |
| `matches:` | likely OK | |
| `matchesPrefix:` | verify | delegates to `search:`? |
| `matchesStream:` | verify | |
| `matchesStreamPrefix:` | verify | |
| `search:` | OK | |
| `searchStream:` | OK | |
| `subexpression:` | OK | |
| `subexpressionCount` | verify | |
| `subexpressionNamed:` | verify | Phase 7 |
| `subexpressionNames` | verify | Phase 7 |
| `matchesIn:` | verify | |
| `matchesIn:collect:` | verify | |
| `matchesIn:do:` | verify | |
| `matchesOnStream:` | verify | |
| `matchesOnStream:collect:` | verify | |
| `matchesOnStream:do:` | verify | |
| `matchingRangesIn:` | verify | |
| `copy:replacingMatchesWith:` | verify | |
| `copy:translatingMatchesUsing:` | verify | |
| `copyStream:to:replacingMatchesWith:` | verify | |
| `copyStream:to:translatingMatchesUsing:` | verify | |
| `split:indicesDo:` | verify | |
| `supportsSubexpressions` | verify | should return `true` |
| `groupNames` | verify | Phase 7 |
| `registerGroupName:at:` | verify | Phase 7 |
| `inputString` | verify | |
| `inputAt:` | verify | |
| `inputSize` | verify | |
| `captures` | verify | |
| `captures:` | verify | |

### Audit Script

Run this in the Pharo image to detect missing methods:

```smalltalk
| rxMethods rxbtMethods missing |
rxMethods  := RxMatcher methodDict keys asSet.
rxbtMethods := RxbtMatcher methodDict keys asSet.
missing := rxMethods select: [:sel |
    (rxbtMethods includes: sel) not
    and: [(sel beginsWith: 'test') not]].
missing asSortedCollection asArray
```

### Behaviour Verification Script

```smalltalk
"Run RxMatcher and RxbtMatcher side by side on a corpus of patterns."
| patterns inputs |
patterns := #(
    'foo' 'f(o+)' '\d+' '^hello' 'a*b' '(cat|dog)'
    '\w+\s+\w+' '[aeiou]+' '(\w)\1' 'foo(?=bar)').
inputs := #(
    'foobar' 'xxxfooyyy' '' 'hello world' 'aaab' 'I have a dog').
patterns do: [:pat |
    inputs do: [:str |
        | rm rbt |
        rm  := [RxMatcher  forString: pat] on: Error do: [:e | nil].
        rbt := [RxbtMatcher forString: pat] on: Error do: [:e | nil].
        (rm notNil and: [rbt notNil]) ifTrue: [
            | rmResult rbtResult |
            rmResult  := rm  search: str.
            rbtResult := rbt search: str.
            rmResult = rbtResult ifFalse: [
                Transcript showCr: 'MISMATCH: /' , pat , '/ on ' , str printString ,
                    ' — RxMatcher=' , rmResult printString ,
                    ' RxbtMatcher=' , rbtResult printString]]]]].
'audit done'
```

### Expected Findings

Likely gap: `matchesPrefix:` and `matchesStreamPrefix:` — these check whether
the pattern matches at the START of the string without requiring a full match.
`RxbtMatcher` may already have these via inheritance or copy, but verify the
behaviour matches `RxMatcher`.

If any method is missing, add it. Most missing methods will be one-liners that
delegate to `search:` or `searchStream:`.

---

## Part B — BaselineOfRegexBacktracking

### Goal

Allow loading the package via:

```smalltalk
Metacello new
    baseline: 'RegexBacktracking';
    repository: 'github://YourOrg/pharo-regex-bt/src';
    load.
```

### Repository Layout

```
pharo-regex-bt/
  src/
    Regex-Backtracking/            ← main package
    Regex-Backtracking-Tests/      ← test package
  BaselineOfRegexBacktracking.class.st
```

Export the current packages to `src/` using Iceberg or `FileStream` export,
then write `BaselineOfRegexBacktracking`.

### Class Definition

```smalltalk
(BaselineOf << #BaselineOfRegexBacktracking)
    slots: {};
    package: 'BaselineOfRegexBacktracking';
    install.
```

### baseline: Method

```smalltalk
baseline: spec
    <baseline>
    spec for: #common do: [
        spec
            package: 'Regex-Backtracking';
            package: 'Regex-Backtracking-Tests'
                with: [spec requires: #('Regex-Backtracking')]]
```

### Post-Load Initialization

`RxbtParser>>initializeBackslashSpecials` must be called after load to populate
the `BackslashSpecials` shared variable. Add a post-load hook:

```smalltalk
"In BaselineOfRegexBacktracking>>baseline:"
spec for: #common do: [
    ...
    spec postLoadDoIt: #initializeAfterLoad].

"Class-side method:"
BaselineOfRegexBacktracking class compile:
    'initializeAfterLoad
        RxbtParser initialize'
    classified: 'hooks'.
```

Alternatively, add `RxbtParser class >> initialize` that is called automatically
by the Pharo class initializer mechanism (implement `initialize` on the class side
and Pharo calls it on image startup):

```smalltalk
RxbtParser class compile: 'initialize
    self initializeBackslashSpecials'
classified: 'initialization'.
```

This is the preferred approach — it also handles image save/restore correctly
without needing a Baseline hook.

### Export Steps

1. In Pharo, open Iceberg → add repository at `pharo-regex-bt/`
2. Add packages `Regex-Backtracking` and `Regex-Backtracking-Tests` to the repo
3. Commit via Iceberg or:

```smalltalk
"Export via Tonel (file-based format):"
| writer |
writer := TonelWriter on: 'pharo-regex-bt/src' asFileReference.
writer writePackageNamed: 'Regex-Backtracking'.
writer writePackageNamed: 'Regex-Backtracking-Tests'.
```

### Version Tagging

Add a version method for reference:

```smalltalk
BaselineOfRegexBacktracking class compile: 'version ^''1.0.0''' classified: 'accessing'.
```

---

## Test Class

```smalltalk
(TestCase << #RxbtAPIAuditTest)
    slots: {};
    tag: 'Tests';
    package: 'Regex-Backtracking-Tests';
    install.

RxbtAPIAuditTest comment: 'Verifies that RxbtMatcher implements the full
public API of RxMatcher with identical behaviour.'.
```

## Test Cases

```smalltalk
testNoMissingPublicMethods
    "Every public RxMatcher instance method must exist on RxbtMatcher."
    | rxMethods rxbtMethods missing |
    rxMethods   := (RxMatcher methodDict keys reject: [:s |
                        s beginsWith: 'test']) asSet.
    rxbtMethods := RxbtMatcher methodDict keys asSet.
    missing := rxMethods select: [:sel | (rxbtMethods includes: sel) not].
    self
        assert: missing isEmpty
        description: 'Missing methods: ' , missing asSortedCollection printString.

testMatchesIdentical
    #('foo' '\d+' 'a*b' '^hello' '(cat|dog)') do: [:pat |
        #('foobar' 'hello' 'aaab' 'dog' '') do: [:str |
            | rm rbt |
            rm  := [RxMatcher  forString: pat] on: Error do: [:e | nil].
            rbt := [RxbtMatcher forString: pat] on: Error do: [:e | nil].
            (rm notNil and: [rbt notNil]) ifTrue: [
                self
                    assert: (rm search: str) = (rbt search: str)
                    description: '/' , pat , '/ on ' , str printString]]].

testSubexpressionCount
    | m |
    m := RxbtMatcher forString: '(a)(b(c))'.
    self assert: m subexpressionCount = 3.

testMatchingRangesIn
    | m ranges |
    m := RxbtMatcher forString: '\d+'.
    ranges := m matchingRangesIn: 'abc123def456'.
    self assert: ranges size = 2.
    self assert: ranges first = (4 to: 6).
    self assert: ranges last  = (10 to: 12).

testCopyReplacingMatches
    | m result |
    m := RxbtMatcher forString: '\d+'.
    result := m copy: 'abc123def456' replacingMatchesWith: 'N'.
    self assert: result = 'abcNdefN'.

testCopyTranslatingMatches
    | m result |
    m := RxbtMatcher forString: '\d+'.
    result := m copy: 'abc123' translatingMatchesUsing: [:s | s reversed].
    self assert: result = 'abc321'.

testSupportsSubexpressions
    self assert: (RxbtMatcher forString: 'x') supportsSubexpressions.

testRegressionFull
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty.
```

---

## Acceptance Criteria

```smalltalk
RxbtAPIAuditTest suite run printString.   "all pass"
RxbtMatcherTest  suite run printString.   "176/176"
```

---

## Pitfalls

- **`RxbtParser class >> initialize`:** Without this, loading the package into
  a fresh image leaves `BackslashSpecials` empty — `\d`, `\w`, `\s` etc. all
  fail silently. Adding `initialize` on the class side fixes this for all load
  paths.

- **Tonel format line endings:** Tonel exports methods with LF. When loaded
  into Pharo, these are converted to CR automatically by the Tonel reader.
  The LF-in-methods issue is an IMAGE-time concern, not a file-format concern.

- **`BaselineOf` package location:** The baseline class itself lives in its own
  package `BaselineOfRegexBacktracking`, NOT in `Regex-Backtracking`. Iceberg
  handles this automatically if you use the standard Metacello project layout.

- **`RxbtMatcherTest` copies vs delegation:** `RxbtMatcherTest` copies all
  methods from `RxMatcherTest`. If `RxMatcher` is updated in a future Pharo
  release, `RxbtMatcherTest` won't pick up the changes. Document this as
  intentional — independence was the design goal.

- **`matchingRangesIn:` returns `Interval` objects:** Verify the return type
  matches `RxMatcher`'s implementation. If `RxbtMatcher` returns different
  objects (e.g., plain integers instead of an `Interval`), downstream code may
  break.

- **`split:indicesDo:` edge cases:** Test with empty matches and overlapping
  boundaries. `RxMatcher`'s implementation has specific behaviour for these
  edge cases — `RxbtMatcher` must match exactly.
