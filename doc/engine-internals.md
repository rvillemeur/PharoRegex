# RegexBacktracking Engine Internals

## Overview

`Regex-Backtracking` is a self-contained regex engine for Pharo. It shares no code with `Regex-Core` but exposes the same public API so it can be used as a drop-in replacement for `RxMatcher`.

The engine has three successive stages:

```
regex string
    │
    ▼
RxbtParser          ─── produces ──►  AST (RxbtNode tree)
    │
    ▼
RxbtCompiler        ─── produces ──►  CPS closure tree  ([:pos :cont | Boolean])
    │
    ▼
RxbtMatcher         ─── drives ────►  matching against an input string
```

---

## Stage 1 — Parsing: `RxbtParser`

`RxbtParser` is a hand-written recursive-descent parser. It consumes a regex string character by character via a single-token lookahead (`lookahead` ivar) and produces an `RxbtNode` AST.

### Grammar (simplified)

```
regex  ::= branch ('|' regex)?
branch ::= piece branch?
piece  ::= atom quantifier?
atom   ::= '(' group ')'
         | '[' charSet ']'
         | ':' messagePredicate ':'
         | '.'  | '^'  | '$'
         | '\' escape
         | literal-char
```

### Entry points

| Method | Purpose |
|--------|---------|
| `RxbtParser class >> parse: aString` | Parse, raise `RxbtSyntaxError` on failure |
| `RxbtParser class >> safelyParse: aString` | Parse, return `nil` on failure |

### Key parsing methods

| Method | Produces |
|--------|---------|
| `regex` | `RxbtRegex` — alternation root |
| `branch` | `RxbtBranch` — concatenation |
| `piece` | wraps atom in `RxbtPiece` / `RxbtLazyPiece` / `RxbtPossessivePiece` |
| `atom` | dispatches on the current character to leaf nodes |
| `characterSet` | `RxbtCharSet` from bracket expression `[...]` |
| `messagePredicate` | `RxbtMessagePredicate` from `:selector:` |
| `lookAround` | `RxbtLookaround` for `(?=...)` / `(?!...)` |
| `lookBehind` | `RxbtLookbehind` for `(?<=...)` / `(?<!...)` |
| `inlineModifier` | `RxbtInlineModifier` for `(?imsx...)` |
| `namedCapture` | `RxbtNamedCapture` for `(?<name>...)` |
| `quantifiedAtom` | parses `{n,m}` and returns the right Piece subclass |

### Escape handling

Two class-side dictionaries drive `\x` sequences:

- **`BackslashConstants`** — maps `\e \n \r \f \t` to literal `Character` objects.  
- **`BackslashSpecials`** — maps `\w \W \s \S \d \D \h \H \v \V \b \B \< \>` to  
  `Association key: NodeClass value: initSelector`, so the parser creates the right  
  `RxbtPredicate` or `RxbtContextCondition` in one message send.

---

## Stage 2 — The AST: `RxbtNode` hierarchy

All AST nodes inherit from `RxbtNode`. The double-dispatch protocol is:

```smalltalk
aNode dispatchTo: aCompiler  "→ calls the matching syntax*: method on aCompiler"
```

### Structural nodes

| Class | Role | Key ivars |
|-------|------|-----------|
| `RxbtRegex` | Alternation (`a\|b`). Wraps one or more branches. | `branch`, `regex` (tail or nil) |
| `RxbtBranch` | Concatenation (`ab`). Links a piece to the rest. | `piece`, `branch` (tail or nil) |
| `RxbtPiece` | Greedy quantified atom. | `atom`, `min`, `max` (nil = ∞) |
| `RxbtLazyPiece` | Lazy quantified atom (`*? +? ??`). Subclass of `RxbtPiece`. | same |
| `RxbtPossessivePiece` | Possessive quantified atom (`*+ ++ ?+`). Never backtracks. | same |

`RxbtPiece` testing protocol:

| Message | True when |
|---------|-----------|
| `isSingular` | `min=1, max=1` (no repetition) |
| `isStar` | `min=0, max=nil` |
| `isPlus` | `min=1, max=nil` |
| `isOptional` | `min=0, max=1` |
| `isLazy` | always `false` (overridden to `true` in `RxbtLazyPiece`) |
| `isPossessive` | always `false` (overridden to `true` in `RxbtPossessivePiece`) |

### Leaf / atom nodes

| Class | Syntax | `dispatchTo:` calls |
|-------|--------|---------------------|
| `RxbtCharacter` | literal `a` | `syntaxCharacter:` |
| `RxbtCharSet` | `[abc]` `[^0-9]` | `syntaxCharSet:` |
| `RxbtPredicate` | `\w \d \s …` | `syntaxPredicate:` |
| `RxbtMessagePredicate` | `:isLetter:` | `syntaxMessagePredicate:` |
| `RxbtContextCondition` | `.` `^` `$` `\b` `\A` `\z` … | `perform: kind` (e.g. `syntaxAny`) |
| `RxbtEpsilon` | empty match | `syntaxEpsilon` |
| `RxbtGenericNewline` | `\R` | `syntaxGenericNewline` |
| `RxbtKeepStart` | `\K` | `syntaxKeepStart` |

### Group / assertion nodes

| Class | Syntax | `dispatchTo:` calls |
|-------|--------|---------------------|
| `RxbtRegex` | `(...)` capturing group | `syntaxRegex:` |
| `RxbtNonCapturingGroup` | `(?:...)` | `syntaxNonCapturingGroup:` |
| `RxbtNamedCapture` | `(?<name>...)` | `syntaxNamedCapture:` |
| `RxbtAtomicGroup` | `(?>...)` | `syntaxAtomicGroup:` |
| `RxbtLookaround` | `(?=...)` `(?!...)` | `syntaxLookaround:` |
| `RxbtLookbehind` | `(?<=...)` `(?<!...)` | `syntaxLookbehind:` |
| `RxbtInlineModifier` | `(?imsx)` `(?i:...)` | `syntaxInlineModifier:` |
| `RxbtBackreference` | `\1`…`\9` | `syntaxBackreference:` |
| `RxbtNamedBackreference` | `\k<name>` | `syntaxNamedBackreference:` |

### `isNullable` — used by quantifier safety checks

A node is *nullable* if it can match the empty string. `RxbtParser` rejects `(epsilon)*` and similar patterns that would loop forever. The `isNullable` protocol propagates bottom-up through the AST.

---

## Stage 3 — Compilation: `RxbtCompiler`

`RxbtCompiler` walks the AST via the visitor protocol and builds a tree of Smalltalk closures. Every closure has the signature:

```smalltalk
[:pos :cont | Boolean]
```

- **`pos`** — 1-based position in `inputString` (the current candidate position).
- **`cont`** — the *continuation* closure: everything that must still match after this node. It also has signature `[:pos | Boolean]`.
- **Return value** — `true` if the whole remaining pattern (this node + continuation) matched from `pos`; `false` otherwise.

This is **continuation-passing style (CPS)**. Backtracking is achieved by returning `false`, which causes the caller to try the next alternative.

### Compilation of each node type

#### `syntaxCharacter:` — literal character

```smalltalk
[:pos :cont |
    matcher incrementStep.
    str := matcher inputString.
    (pos <= str size and: [str at: pos = ch])
        ifTrue: [cont value: pos + 1]
        ifFalse: [false]]
```

Advances `pos` by 1 if the character matches, then calls the continuation.

#### `syntaxCharSet:` — bracket expression

Builds a combined predicate block at compile time (no per-character case analysis at runtime). The predicate closes over the `RxbtFlags` snapshot at compilation time.

#### `syntaxBranch:` — concatenation

```smalltalk
[:pos :cont |
    pieceBlock value: pos value: [:pos2 |
        restBlock value: pos2 value: cont]]
```

Threads `pos` through the piece, then through the rest. The continuation chains naturally.

#### `syntaxRegex:` — alternation + capturing group

Allocates a marker pair `(startIdx, endIdx)`. Tries each alternative left-to-right. On failure of one alternative, restores the saved markers before trying the next:

```smalltalk
[:pos :cont |
    caps at: startIdx put: pos.
    altBlocks do: [:ab |
        result ifFalse: [
            result := ab value: pos value: [:endPos |
                caps at: endIdx put: endPos.
                cont value: endPos]]].
    result ifFalse: [restore savedStart, savedEnd].
    result]
```

#### `syntaxPiece:` — quantifier dispatch

`syntaxPiece:` reads the piece's `isLazy` / `isPossessive` / `isStar` / `isPlus` / `isOptional` flags and delegates to one of nine CPS helpers:

| Quantifier type | Methods called |
|-----------------|----------------|
| Greedy `*` `+` `?` `{n,m}` | `greedyStar:` `greedyPlus:` `greedyOptional:` `greedyRepeat:min:max:` |
| Lazy `*?` `+?` `??` `{n,m}?` | `lazyStar:` `lazyPlus:` `lazyOptional:` `lazyRepeat:min:max:` |
| Possessive `*+` `++` `?+` `{n,m}+` | `possessiveStar:` `possessivePlus:` `possessiveOptional:` `possessiveRepeat:min:max:` |

---

## How Quantifiers Work

### Greedy — `matchStar:from:continuation:`

1. Greedily advance as far as possible, collecting every reachable position into an `OrderedCollection`.
2. Walk the collection **backwards** (longest match first), calling `cont` at each position.
3. Return `true` on first continuation success; `false` if none succeed.

This is backtracking by rewinding: the positions list acts as the backtrack stack.

```
regex: a*b    input: "aaab"
positions collected: [1, 2, 3, 4]   (after 0, 1, 2, 3 'a's)
try cont at pos=4 → 'b' matches → true
```

### Lazy — `matchLazyStar:from:continuation:`

1. Start at the minimum (zero repetitions). Try the continuation immediately.
2. If the continuation fails, advance one more match and retry.
3. Return `true` on first continuation success.

```
regex: a*?b   input: "aaab"
try pos=1 → cont fails ('a'≠'b')
advance → pos=2 → cont fails
advance → pos=3 → cont fails
advance → pos=4 → cont succeeds ('b'='b') → true
```

### Possessive — `consumeAll:from:` + `cont value: finalPos`

Greedily consume all possible matches, then call the continuation exactly once at the final position. No backtracking: if the continuation fails, the entire possessive quantifier fails immediately.

### Bounded `{n,m}` — `matchRepeat:from:count:min:max:continuation:`

Same as greedy star but stops collecting at `max` repetitions and only tries positions where `count >= min`.

---

## Capture Groups

`RxbtMatcher` holds a flat `captures` array (1-based indices):

- `captures[2n-1]` — start position of group n (1-based in the string)
- `captures[2n]` — end position (exclusive) of group n

Group 1 is the whole match.

**Allocation:** `RxbtCompiler >> allocateMarker` increments `markerCount` and returns the next index. Each `RxbtRegex` and `RxbtNamedCapture` node claims two consecutive indices.

**Restoration on backtrack:** Every capturing group saves the old marker values before trying alternatives and restores them on failure. This ensures captures reflect only the currently committed match path.

**Access from Pharo:**

```smalltalk
matcher subexpression: 1    "whole match"
matcher subexpression: 2    "first explicit group"
matcher subexpressionNamed: 'year'
```

---

## Zero-Width Assertions

Zero-width nodes call the continuation with the **same `pos`** they received — they consume no input.

| Node | Condition checked |
|------|-----------------|
| `syntaxBeginningOfLine` | `pos=1` or preceded by newline (multiline mode) |
| `syntaxEndOfLine` | `pos > size` or current char is newline (multiline mode) |
| `syntaxBeginningOfString` | `pos=1` |
| `syntaxEndOfString` | `pos > size` |
| `syntaxEndOfStringZ` | `pos > size` or last char is `\n` |
| `syntaxWordBoundary` | word↔non-word transition |
| `syntaxNonWordBoundary` | no word boundary |
| `syntaxBeginningOfWord` | non-word then word |
| `syntaxEndOfWord` | word then non-word |

---

## Lookahead and Lookbehind

### Lookahead `(?=...)` / `(?!...)`

```smalltalk
"positive"
[:pos :cont |
    (innerBlock value: pos value: [:_ | true])
        ifTrue:  [cont value: pos]   "inner matched → proceed without consuming"
        ifFalse: [false]]
```

The inner block is run with a trivially-true continuation so it immediately returns success/failure without advancing `pos`. The outer continuation then receives the original `pos`.

### Lookbehind `(?<=...)` / `(?<!...)`

More expensive: tries the inner regex from all positions `1..pos-1`, checking whether any match ends exactly at `pos`. Captures inside the lookbehind are saved and restored.

---

## Atomic Groups `(?>...)`

```smalltalk
[:pos :cont |
    endPos := nil.
    innerBlock value: pos value: [:ep |
        endPos isNil ifTrue: [endPos := ep].
        false].           "always return false — collect only the first match"
    endPos isNil
        ifTrue:  [false]
        ifFalse: [cont value: endPos]]
```

The inner block is run with a continuation that records the first match and immediately returns `false` (forcing the inner block to not try further alternatives). Then the outer continuation is called from the committed position — no backtracking into the group is possible.

---

## Inline Modifiers `(?imsx)` / `(?i:...)`

`RxbtFlags` is an immutable value object. `RxbtCompiler` holds the current `flags` ivar. When `syntaxInlineModifier:` is called:

- **Scoped** (`(?i:inner)`): the compiler swaps `flags`, compiles the inner tree, then restores `flags`. The mode applies only inside.
- **Unscoped** (`(?i)`): the compiler permanently updates `flags` for all subsequent nodes. Returns an epsilon block.

Flags supported:

| Flag | Effect |
|------|--------|
| `i` | Case-insensitive character matching |
| `s` | Dotall — `.` matches newline |
| `m` | Multiline — `^` `$` match at internal newlines |
| `x` | Extended — literal spaces in pattern are ignored |

Defaults (matching `RxMatcher` baseline): `i=false, s=true, m=true, x=false`.

---

## Match Optimizer: `RxbtMatchOptimizer`

Before any matching attempt, `searchStream:` calls:

```smalltalk
optimizer canStartMatch: lookahead at: pos
```

`RxbtMatchOptimizer` walks the AST once at build time (same visitor protocol) to determine which characters could possibly start a match. It builds a compiled `testBlock` from one or more testers:

| Tester | Condition |
|--------|-----------|
| `prefixTester` | character must be in the known literal prefix set |
| `nonPrefixTester` | character must NOT be a known non-matching prefix |
| `predicateTester` | character must satisfy a predicate (`\w` etc.) |
| `nonPredicateTester` | character must not satisfy a predicate |
| `methodPredicateTester` | character responds to a message predicate |
| `conditionTester` | zero-width conditions (mostly returns nil — cannot filter) |

If `canStartMatch:at:` returns `false`, the engine skips that position entirely, avoiding the full CPS traversal. For patterns with a fixed first character (e.g. `foo.*bar`), this turns an O(n·m) search into nearly O(n) in the common case.

---

## Step Limit and Catastrophic Backtracking Guard

`RxbtMatcher` tracks `stepCount`. Every `matcher incrementStep` call in the CPS closures increments it. If `stepCount` exceeds `stepLimit` (default: 1 000 000), `RxbtMatchingError` is signalled:

```
'Regex step limit exceeded (1000000 steps) — possible catastrophic backtracking'
```

`stepCount` is reset on each call to `searchStream:`. The limit is configurable:

```smalltalk
matcher stepLimit: 500000.
```

---

## Public API: `RxbtMatcher`

### Creation

```smalltalk
RxbtMatcher forString: 'a+'
RxbtMatcher forString: 'a+' ignoreCase: true
RxbtMatcher for: aSyntaxTree            "from a pre-parsed RxbtNode"
```

### Matching

| Method | Behaviour |
|--------|-----------|
| `matches: aString` | Full match (must consume entire string) |
| `matchesPrefix: aString` | Prefix match (any length accepted) |
| `search: aString` | Search anywhere in string |
| `searchStream: aStream` | Search from current stream position |
| `matchesIn: aString do: aBlock` | Iterate all non-overlapping matches |
| `copy: aString replacingMatchesWith: replacement` | Replace all matches |
| `copy: aString translatingMatchesUsing: aBlock` | Replace with block transformation |

### Captures

```smalltalk
matcher subexpressionCount          "number of groups (including group 1)"
matcher subexpression: n            "String or nil; group 1 = whole match"
matcher subexpressionNamed: 'name'  "named group"
matcher subexpressionNames          "collection of registered names"
```

---

## Data Flow for a Single `matches:` Call

```
matches: 'hello'
  │
  ├─ inputString := 'hello'
  ├─ captures := Array new: markerCount withAll: nil
  └─ rootBlock value: 1 value: [:endPos | endPos = 6]
       │
       ├─ (group 1 start marker set to 1)
       ├─ altBlock[0] value: 1 value: …
       │    ├─ pieceBlock₁ value: 1 value: …   "match 'h'"
       │    │    └─ cont value: 2
       │    ├─ pieceBlock₂ value: 2 value: …   "match 'e'"
       │    │    └─ cont value: 3
       │    ⋮
       │    └─ pieceBlockₙ value: 5 value: cont
       │         └─ cont value: 6
       │              └─ (group 1 end marker set to 6)
       │                   └─ finalCont value: 6  →  6 = 6 → true
       └─ → true
```

If any piece fails, the closure returns `false`, which bubbles up through the CPS chain. Quantifiers with multiple positions try the next candidate and call the continuation again.

---

## Class Responsibility Summary

| Class | Package tag | Responsibility |
|-------|-------------|---------------|
| `RxbtParser` | Base | Tokenise + parse regex string → AST |
| `RxbtCompiler` | Base | Visit AST → CPS closure tree; allocate markers |
| `RxbtMatcher` | Base | Hold runtime state; drive matching; expose API |
| `RxbtMatchOptimizer` | Base | Pre-filter positions before CPS traversal |
| `RxbtFlags` | Base | Immutable snapshot of active flags |
| `RxbtNode` | Nodes | Abstract AST node; `dispatchTo:` protocol |
| `RxbtRegex` | Nodes | Alternation + capturing group |
| `RxbtBranch` | Nodes | Concatenation |
| `RxbtPiece` | Nodes | Greedy quantified atom |
| `RxbtLazyPiece` | Nodes | Lazy quantified atom |
| `RxbtPossessivePiece` | Nodes | Possessive quantified atom |
| `RxbtCharacter` | Nodes | Literal character |
| `RxbtCharSet` | Nodes | Bracket expression `[...]` |
| `RxbtCharSetParser` | Base | Parse the content of `[...]` |
| `RxbtPredicate` | Nodes | `\w \d \s …` shorthand predicate |
| `RxbtMessagePredicate` | Nodes | `:selector:` Pharo message predicate |
| `RxbtContextCondition` | Nodes | Zero-width positional assertion |
| `RxbtEpsilon` | Nodes | Empty match |
| `RxbtGenericNewline` | Nodes | `\R` (any newline sequence) |
| `RxbtKeepStart` | Nodes | `\K` (reset match start) |
| `RxbtAtomicGroup` | Nodes | `(?>...)` — no backtrack into group |
| `RxbtLookaround` | Nodes | `(?=...)` / `(?!...)` |
| `RxbtLookbehind` | Nodes | `(?<=...)` / `(?<!...)` |
| `RxbtInlineModifier` | Nodes | `(?imsx)` / `(?i:...)` |
| `RxbtBackreference` | Nodes | `\1`…`\9` |
| `RxbtNamedCapture` | Nodes | `(?<name>...)` |
| `RxbtNamedBackreference` | Nodes | `\k<name>` |
| `RxbtNonCapturingGroup` | Nodes | `(?:...)` |
| `RxbtRange` | Nodes | Character range `a-z` inside `[...]` |
| `RxbtSyntaxError` | Base | Parse-time error |
| `RxbtMatchingError` | Base | Runtime error (step limit etc.) |
| `RxbtCompilationError` | Base | Compile-time error |
