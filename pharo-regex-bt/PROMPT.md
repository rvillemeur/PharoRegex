# Phase Prompts — Pharo Backtracking Regex Engine

Paste the appropriate prompt below as a message to trigger each phase.
Read CLAUDE.md in this directory before starting any phase.

---

## PHASE 1 — Core Backtracking Engine

```
Read /home/me/pharo-regex-bt/CLAUDE.md and /home/me/pharo-regex-bt/phases/PHASE1.md
for full context.

Your task: Implement RxbtMatcher in Pharo 12 using the Pharo MCP tools.

Package: Regex-Backtracking
Class: RxbtMatcher (Object subclass)

Architecture: CPS closure engine. Each syntax*: method returns a
[:pos :cont | Boolean] block. See CLAUDE.md for the complete design.

Required steps (in order):
1. Define RxbtMatcher with slots: ast ignoreCase inputString captures groupMap markerCount rootBlock
2. Implement all class-side creation methods (forString: / for: / forString:ignoreCase: / for:ignoreCase:)
3. Implement buildFrom: and allocateMarker
4. Implement all syntax*: methods as CPS closures (see CLAUDE.md for pseudocode)
5. Implement the public matching API: matches: matchesPrefix: search: matchesStream: matchesStreamPrefix: searchStream:
6. Implement subexpression: subexpressionCount supportsSubexpressions
7. Implement replace/collect API: copy:replacingMatchesWith: copy:translatingMatchesUsing: matchesIn: matchesIn:collect: matchesIn:do: matchingRangesIn: split:indicesDo:
8. Define RxbtMatcherTest as subclass of RxMatcherTest overriding matcherClass to return RxbtMatcher
9. Run RxbtMatcherTest suite and fix failures until all 174 tests pass

After each method group, run a quick smoke test before continuing.
Report final test result: "X ran, X passed, 0 failures, 0 errors".
```

---

## PHASE 2 — True Backtracking Validation

```
Read /home/me/pharo-regex-bt/CLAUDE.md and /home/me/pharo-regex-bt/phases/PHASE2.md.

Context: RxbtMatcher exists and passes all RxMatcherTest tests. Now validate
that it demonstrates TRUE backtracking power — patterns that fail in RxMatcher
but succeed in RxbtMatcher.

Your task:
1. Create RxbtBacktrackingTest (TestCase subclass) in Regex-Backtracking-Tests
2. Implement each test case from PHASE2.md
3. For each test, also verify RxMatcher FAILS (proving RxbtMatcher is better)
4. All RxbtBacktrackingTest tests must pass
5. All RxbtMatcherTest tests must still pass (no regression)

Report: test count, any RxMatcher comparison notes.
```

---

## PHASE 3 — Lazy Quantifiers

```
Read /home/me/pharo-regex-bt/CLAUDE.md and /home/me/pharo-regex-bt/phases/PHASE3.md.

Context: RxbtMatcher passes Phase 1+2. Now add lazy (non-greedy) quantifiers.

Your task:
1. Extend RxParser to support *? +? ?? {n,m}? syntax
   - Add a 'lazy' flag to RxsPiece: subclass RxsPiece as RxsLazyPiece OR
     add a lazyMin:max: initializer, OR extend existing RxsPiece with a lazy slot
   - In RxParser>>piece, after parsing *, +, ?, {n,m}: check for trailing ?
     and set lazy flag accordingly
2. Implement lazyStar: lazyPlus: lazyOptional: lazyRepeat:min:max: in RxbtMatcher
   (try FEWER matches first, fall back to more)
3. Create RxbtLazyTest with all test cases from PHASE3.md
4. All RxbtLazyTest tests must pass
5. All prior tests must still pass

Report: lazy test count + full regression status.
```

---

## PHASE 4 — Backreferences

```
Read /home/me/pharo-regex-bt/CLAUDE.md and /home/me/pharo-regex-bt/phases/PHASE4.md.

Context: RxbtMatcher passes Phases 1-3. Now add backreferences (\1 through \9).

Your task:
1. Extend RxParser>>atom to recognise \1 through \9 and produce RxsBackreference nodes
   - Define RxsBackreference (RxsNode subclass) with slot: groupIndex
   - Add dispatchTo: sending syntaxBackreference: to matcher
2. Implement syntaxBackreference: in RxbtMatcher
   - At match time, look up the current content of group groupIndex from captures
   - Match that exact string at the current position (respecting ignoreCase)
3. Create RxbtBackreferenceTest with all test cases from PHASE4.md
4. All RxbtBackreferenceTest tests must pass
5. All prior tests must still pass

Note: \1 refers to the STRING matched by group 1 at the time of the backreference,
not the group definition. If the group has not matched yet, the backreference fails.

Report: backreference test count + full regression status.
```

---

## PHASE 5 — Possessive Quantifiers & Atomic Groups

```
Read /home/me/pharo-regex-bt/CLAUDE.md and /home/me/pharo-regex-bt/phases/PHASE5.md.

Context: RxbtMatcher passes Phases 1-4. Now add possessive quantifiers and atomic groups.

Your task:
1. Extend RxParser to support *+ ++ ?+ {n,m}+ (possessive) and (?>...) (atomic group)
   - RxsPiece: add possessive flag (or subclass RxsPossessivePiece)
   - Atomic group: new AST node RxsAtomicGroup (RxsNode subclass), slot: inner
2. Implement possessiveStar: possessivePlus: etc. in RxbtMatcher
   - Possessive: match greedily, then FORBID backtracking into the quantifier
   - Implementation: match, record final position, call cont — if cont fails, return false (no retry)
3. Implement syntaxAtomicGroup: in RxbtMatcher
   - Match inner, if succeeds pass position to cont — if cont fails, return false (no retry)
4. Create RxbtPossessiveTest with all test cases from PHASE5.md
5. All RxbtPossessiveTest tests must pass
6. All prior tests must still pass

Report: possessive test count + full regression status.
```
