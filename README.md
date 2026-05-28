# Regex-Backtracking

A backtracking regex engine for Pharo 12, implemented as a drop-in replacement
for the built-in `RxMatcher` from `Regex-Core`.

The engine extends the existing API with lazy quantifiers, possessive quantifiers,
atomic groups, lookahead/lookbehind, backreferences, named capture groups, inline
flags, and several other features not available in `RxMatcher`.

---

## Installation

```smalltalk
Metacello new
    baseline: 'RegexBacktracking';
    repository: 'github://YourOrg/pharo-regex-bt/src';
    load.
```

Or load the packages directly from a local checkout via Iceberg.

---

## Quick Start

```smalltalk
"Basic search"
m := RxbtMatcher forString: '\d+'.
m search: 'price: 42 USD'.    "=> true"
m subexpression: 1.            "=> '42'"

"Case-insensitive"
m := RxbtMatcher forString: 'hello' ignoreCase: true.
m matches: 'HELLO'.            "=> true"

"Named capture group"
m := RxbtMatcher forString: '(?<year>\d{4})-(?<month>\d{2})'.
m search: '2026-05'.
m subexpressionNamed: 'year'.  "=> '2026'"

"Replace"
m := RxbtMatcher forString: '\d+'.
m copy: 'abc123def456' replacingMatchesWith: 'N'.  "=> 'abcNdefN'"
```

---

## API

`RxbtMatcher` implements the full public API of `RxMatcher`. Any code that works
with `RxMatcher` works unchanged with `RxbtMatcher`.

### Instance Creation

```smalltalk
RxbtMatcher forString: aPattern
RxbtMatcher forString: aPattern ignoreCase: aBoolean
RxbtMatcher for: aSyntaxTree
RxbtMatcher for: aSyntaxTree ignoreCase: aBoolean
```

### Matching

```smalltalk
matcher matches: aString              "true iff full string matches"
matcher matchesPrefix: aString        "true iff pattern matches at start"
matcher search: aString               "true iff match found anywhere"
matcher matchesStream: aStream
matcher matchesStreamPrefix: aStream
matcher searchStream: aStream
```

### Capture Groups

Groups are 1-based. Group 1 is always the whole match.

```smalltalk
matcher subexpression: n              "String or nil — nth group"
matcher subexpressionCount            "total groups including whole match"
matcher subexpressionNamed: name      "named group by String name"
matcher subexpressionNames            "OrderedCollection of group name strings"
matcher supportsSubexpressions        "always true"
```

### Replace and Collect

```smalltalk
matcher copy: str replacingMatchesWith: replacement
matcher copy: str translatingMatchesUsing: aBlock
matcher matchesIn: str
matcher matchesIn: str collect: aBlock
matcher matchesIn: str do: aBlock
matcher matchingRangesIn: str         "OrderedCollection of Intervals"
matcher matchesOnStream: aStream
matcher matchesOnStream: aStream collect: aBlock
matcher matchesOnStream: aStream do: aBlock
matcher split: str indicesDo: aBlock
matcher copyStream: src to: dst replacingMatchesWith: replacement
matcher copyStream: src to: dst translatingMatchesUsing: aBlock
```

### Catastrophic Backtracking Guard

```smalltalk
matcher stepLimit               "default: 1 000 000"
matcher stepLimit: anInteger    "per-instance override"
```

Raises `RxbtMatchingError` when the step limit is exceeded. Prevents pathological
patterns from hanging the image indefinitely.

---

## Pattern Syntax

All syntax supported by `RxMatcher` (Pharo `Regex-Core`) is supported, plus:

### Quantifiers

| Syntax | Meaning |
|--------|---------|
| `*` `+` `?` `{n,m}` | Greedy (standard) |
| `*?` `+?` `??` `{n,m}?` | Lazy — shortest match first |
| `*+` `++` `?+` `{n,m}+` | Possessive — no backtracking |

### Groups

| Syntax | Meaning |
|--------|---------|
| `(...)` | Capturing group |
| `(?:...)` | Non-capturing group |
| `(?>...)` | Atomic group — no backtracking out of it |
| `(?<name>...)` | Named capturing group |
| `\k<name>` | Named backreference |
| `\1` … `\9` | Numbered backreference |

### Lookaround

| Syntax | Meaning |
|--------|---------|
| `(?=...)` | Positive lookahead |
| `(?!...)` | Negative lookahead |
| `(?<=...)` | Positive lookbehind |
| `(?<!...)` | Negative lookbehind |

### Anchors and Escapes

| Syntax | Meaning |
|--------|---------|
| `\A` | Start of string (never multiline) |
| `\z` | End of string (no trailing newline) |
| `\Z` | End of string (optional trailing newline) |
| `\R` | Generic newline (CR, LF, or CRLF) |
| `\K` | Reset reported match start to current position |
| `\b` `\B` | Word boundary / non-word boundary |

### Inline Flags

| Syntax | Meaning |
|--------|---------|
| `(?i)` | Case-insensitive for remainder of group |
| `(?m)` | Multiline `^`/`$` |
| `(?s)` | Dot matches newline |
| `(?x)` | Extended mode — whitespace ignored |
| `(?i:...)` | Scoped flag — applies only inside the group |

### Character Classes

Standard `[...]` syntax plus POSIX classes inside brackets:

`[:alpha:]` `[:digit:]` `[:alnum:]` `[:space:]` `[:blank:]`
`[:upper:]` `[:lower:]` `[:punct:]` `[:print:]` `[:graph:]`
`[:cntrl:]` `[:xdigit:]` `[:word:]`

```smalltalk
RxbtMatcher forString: '[[:alpha:]_][[:alnum:]_]*'  "identifier"
```

### Miscellaneous

| Syntax | Meaning |
|--------|---------|
| `(?#text)` | Inline comment — ignored at parse time |

---

## Architecture

> Detailed internals documentation: [doc/engine-internals.md](doc/engine-internals.md)

The engine uses a **continuation-passing style (CPS) closure** approach.

The parser produces a `Rbt*` AST. `RxbtCompiler` walks the AST via
`dispatchTo:` double-dispatch and returns a closure `[:pos :cont | Boolean]`
for each node. Matching is a chain of closure calls — no explicit stack,
no recursion for the match itself.

Key classes:

| Class | Role |
|-------|------|
| `RxbtParser` | Parses pattern string into `Rbt*` AST |
| `RxbtCompiler` | Visits AST, produces CPS closure |
| `RxbtMatcher` | Holds input string, captures, runs root closure |
| `RxbtMatchOptimizer` | Pre-match filter — skips hopeless start positions |

**Stack safety:** Quantifier helpers (`matchStar:`, `matchRepeat:`, etc.) are
iterative, not recursive. Patterns like `a*` on a 5 000-character string
complete without stack overflow.

**Backtracking guard:** Every atom-level closure evaluation increments a step
counter. When the count exceeds `stepLimit`, `RxbtMatchingError` is raised.
This terminates patterns like `(a+)+b` on a long non-matching string in
under a second rather than hanging the image.

**Known limitation:** The iterative greedy forward pass follows only the first
success path of each atom. Patterns where the atom is itself a top-level
alternation with different match lengths (e.g. `(a|ab)*c`) may fail to find
a match that the recursive form would find. For typical patterns this is not
an issue.

---

## Benchmarks

Measured in a Pharo 12 image, 1 000 repetitions per case.
All times are total milliseconds for 1 000 runs.

| Pattern | Input | `RxMatcher` | `RxbtMatcher` |
|---------|-------|-------------|---------------|
| `fox` (literal) | 43-char sentence | 3 ms | 1 ms |
| `\d+` (digit search) | 42-char string | 4 ms | 2 ms |
| `cat\|dog\|fish` (alternation) | 30-char sentence | 5 ms | 1 ms |
| `^hello` (anchored) | 11-char string | 1 ms | 1 ms |
| `\d+` replace all | 18-char string | 15 ms | 10 ms |
| `a*` matches (1 000-char string, 100 reps) | `'aaa…'` × 1000 | 129 ms | **6 ms** |
| `\b\w{4}\b` (word boundary) | 50-char sentence | 33 ms | 17 ms |

The largest gap is `a*` on a long string: `RxMatcher` recurses once per
character matched — 1 000 frames deep. `RxbtMatcher` uses an iterative loop
and is ~21× faster on this case, while also being safe on inputs of any length.

Features not available in `RxMatcher` (no comparison possible):

| Pattern | Input | `RxbtMatcher` |
|---------|-------|---------------|
| `<.+?>` (lazy) | HTML fragment | < 1 ms / 1 000 reps |
| `(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2})` (named groups) | Date string | 6 ms |
| `(a+)+b` guarded (step limit 10 000) | `'aaaaaaaaab'` | 1 ms |

---

## Tests

282 tests across 15 test classes.

| Class | Tests | Covers |
|-------|-------|--------|
| `RxbtMatcherTest` | 176 | Full `RxMatcher` compatibility |
| `RxbtBacktrackingTest` | 10 | Core backtracking |
| `RxbtLazyTest` | 6 | Lazy quantifiers |
| `RxbtBackreferenceTest` | 8 | Backreferences |
| `RxbtPossessiveTest` | 6 | Possessive quantifiers + atomic groups |
| `RxbtLookbehindTest` | 6 | Lookbehind assertions |
| `RxbtNamedCaptureTest` | 6 | Named groups |
| `RxbtNonCapturingTest` | 4 | Non-capturing groups |
| `RxbtInlineModifierTest` | 8 | Inline flags |
| `RxbtAnchorEscapeTest` | 8 | `\A` `\z` `\Z` `\R` anchors |
| `RxbtOptimizerTest` | 7 | Match optimizer |
| `RxbtStackDepthTest` | 8 | Stack-safe quantifiers |
| `RxbtBacktrackingGuardTest` | 8 | Catastrophic backtracking guard |
| `RxbtQuickWinsTest` | 13 | Comments, `\K`, POSIX classes |
| `RxbtAPIAuditTest` | 8 | Public API parity with `RxMatcher` |

Run all tests:

```smalltalk
RxbtMatcherTest suite run printString.
```

---

## Package Layout

```
src/
  Regex-Backtracking/            main engine
  Regex-Backtracking-Tests/      test suite
  BaselineOfRegexBacktracking/   Metacello baseline
```
