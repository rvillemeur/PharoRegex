# Phase 7 — Named Captures

## Goal
Add named capture groups `(?<name>...)` and named backreferences `\k<name>`.
Extend the `RxbtMatcher` API with `subexpressionNamed:` and `subexpressionNames`.

## Package
`Regex-Backtracking`

---

## New AST Nodes

### RxsNamedCapture

```smalltalk
(RxsNode << #RxsNamedCapture
    slots: #(name inner);
    package: 'Regex-Backtracking') install.

RxsNamedCapture comment: 'AST node for a named capture group (?<name>...).
Behaves like a normal capture group but additionally registers name -> markerIndex
in RxbtMatcher so captured text can be retrieved by name via subexpressionNamed:.
name is a String (the group name). inner is the RxsRegex node for the contents.'.

RxsNamedCapture compile: 'name  ^name'  classified: 'accessing'.
RxsNamedCapture compile: 'inner ^inner' classified: 'accessing'.
RxsNamedCapture compile: 'name: aString inner: aNode
    name  := aString.
    inner := aNode' classified: 'initialize'.
RxsNamedCapture compile: 'isNullable ^inner isNullable' classified: 'testing'.
RxsNamedCapture compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxNamedCapture: self' classified: 'double dispatch'.
```

### RxsNamedBackreference

```smalltalk
(RxsNode << #RxsNamedBackreference
    slots: #(name);
    package: 'Regex-Backtracking') install.

RxsNamedBackreference comment: 'AST node for a named backreference \k<name>.
Matches the text previously captured by the named group. Resolved to a marker
index at compile time via RxbtCompiler, same mechanics as RxsBackreference.'.

RxsNamedBackreference compile: 'name  ^name'  classified: 'accessing'.
RxsNamedBackreference compile: 'name: aString name := aString' classified: 'initialize'.
RxsNamedBackreference compile: 'isNullable ^false' classified: 'testing'.
RxsNamedBackreference compile: 'dispatchTo: aMatcher
    ^aMatcher syntaxNamedBackreference: self' classified: 'double dispatch'.
```

---

## RxbtMatcher Changes

Add `groupNames` ivar (Dictionary: String -> Integer markerIndex) and API:

```smalltalk
"Redefine class to add groupNames slot:"
(Object << #RxbtMatcher
    slots: #(ignoreCase inputString captures markerCount rootBlock groupNames);
    package: 'Regex-Backtracking') install.

RxbtMatcher compile: 'groupNames ^groupNames' classified: 'accessing'.

RxbtMatcher compile: 'registerGroupName: aString at: markerIdx
    "Called by RxbtCompiler when compiling a named capture group."
    groupNames ifNil: [groupNames := Dictionary new].
    groupNames at: aString put: markerIdx' classified: 'accessing'.

RxbtMatcher compile: 'subexpressionNamed: aString
    "Return the captured text for the group named aString, or nil."
    | idx start end |
    groupNames isNil ifTrue: [^nil].
    idx := groupNames at: aString ifAbsent: [^nil].
    start := captures at: 2 * idx - 1.
    end   := captures at: 2 * idx.
    (start isNil or: [end isNil]) ifTrue: [^nil].
    ^inputString copyFrom: start to: end - 1' classified: 'accessing'.

RxbtMatcher compile: 'subexpressionNames
    "Return a collection of all defined group names."
    groupNames isNil ifTrue: [^#()].
    ^groupNames keys' classified: 'accessing'.
```

Also update `initialize:ignoreCase:` to reset `groupNames`:

```smalltalk
initialize: syntaxTreeRoot ignoreCase: aBoolean
    | compiler |
    ignoreCase := aBoolean.
    groupNames := nil.
    compiler := RxbtCompiler for: self ignoreCase: aBoolean.
    rootBlock := compiler compile: syntaxTreeRoot.
    markerCount := compiler markerCount.
    captures := Array new: markerCount withAll: nil.
```

---

## Parser Changes

### Named capture `(?<name>...)`

In `RxParser>>atom`, inside the `(?` branch, add `<` handling.
After the lookbehind `<` check (Phase 6), disambiguate `<name>` from `<=` / `<!`:

```smalltalk
lookahead = $<
    ifTrue: [
        self next.   "consume <"
        (lookahead = $= or: [lookahead = $!])
            ifTrue: [
                "lookbehind (?<=...) or (?<!...)"
                atom := self lookBehind.
                self match: $).
                ^atom].
        "named capture (?<name>...)"
        atom := self namedCapture.
        self match: $).
        ^atom].
```

Add `namedCapture` method to `RxParser` (in `Regex-Backtracking` category):

```smalltalk
namedCapture
    "Parse (?<name>inner) after < has been consumed. Returns RxsNamedCapture."
    | name inner |
    name := self inputUpToAny: '>' errorMessage: 'unterminated group name'.
    self match: $>.
    inner := self regex.
    ^RxsNamedCapture new name: name inner: inner
```

### Named backreference `\k<name>`

In the `\` handling section of `RxParser>>atom`, after the digit backreference check:

```smalltalk
lookahead = $k ifTrue: [
    self next.   "consume k"
    lookahead = $< ifTrue: [
        self next.   "consume <"
        | name |
        name := self inputUpToAny: '>' errorMessage: 'unterminated backreference name'.
        self match: $>.
        ^RxsNamedBackreference new name: name]].
```

---

## Compiler Methods

### syntaxNamedCapture:

Same as `syntaxRegex:` but additionally registers the group name with the matcher:

```smalltalk
syntaxNamedCapture: node
    "Compile a named capture group — allocates markers and registers name."
    | startIdx endIdx altBlocks inner |
    startIdx := self allocateMarker.
    endIdx   := self allocateMarker.
    matcher registerGroupName: node name at: startIdx // 2 + 1.
    altBlocks := OrderedCollection new.
    inner := node inner.
    [inner notNil] whileTrue: [
        altBlocks add: (inner branch dispatchTo: self).
        inner := inner regex].
    ^[:pos :cont |
        | caps savedStart savedEnd result |
        caps := matcher captures.
        savedStart := caps at: startIdx.
        savedEnd   := caps at: endIdx.
        caps at: startIdx put: pos.
        result := false.
        altBlocks do: [:ab |
            result ifFalse: [
                result := ab value: pos value: [:endPos |
                    caps at: endIdx put: endPos.
                    cont value: endPos]]].
        result ifFalse: [
            caps at: startIdx put: savedStart.
            caps at: endIdx   put: savedEnd].
        result]
```

Note: `startIdx // 2 + 1` converts the marker index to a group number compatible
with `subexpression: n`. Verify against the `allocateMarker` sequence: marker 1/2
= group 1, 3/4 = group 2, so `startIdx = 2n-1` → `n = (startIdx + 1) // 2`.
Use: `matcher registerGroupName: node name at: (startIdx + 1) // 2`.

### syntaxNamedBackreference:

Resolve the name to a marker index at compile time:

```smalltalk
syntaxNamedBackreference: node
    "Compile \k<name> — resolved to a numeric marker at compile time.
     Falls back to false if the name is not defined in this pattern."
    | markerIdx |
    markerIdx := matcher groupNames
        ifNil: [nil]
        ifNotNil: [:gn | gn at: node name ifAbsent: [nil]].
    markerIdx isNil ifTrue: [^[:pos :cont | false]].
    "Delegate to numeric backreference mechanics"
    ^[:pos :cont |
        | caps str start end refText sz |
        caps := matcher captures.
        str  := matcher inputString.
        (2 * markerIdx > caps size)
            ifTrue: [false]
            ifFalse: [
                start := caps at: 2 * markerIdx - 1.
                end   := caps at: 2 * markerIdx.
                (start isNil or: [end isNil])
                    ifTrue: [false]
                    ifFalse: [
                        refText := str copyFrom: start to: end - 1.
                        sz := refText size.
                        (pos + sz - 1 > str size)
                            ifTrue: [false]
                            ifFalse: [
                                (ignoreCase
                                    ifTrue:  [(str copyFrom: pos to: pos + sz - 1) asLowercase = refText asLowercase]
                                    ifFalse: [(str copyFrom: pos to: pos + sz - 1) = refText])
                                    ifTrue:  [cont value: pos + sz]
                                    ifFalse: [false]]]]]
```

---

## Test Class

```smalltalk
(TestCase << #RxbtNamedCaptureTest
    slots: #();
    package: 'Regex-Backtracking-Tests') install.

RxbtNamedCaptureTest comment: 'Tests for named capture groups (?<name>...) and named
backreferences \k<name> in RxbtMatcher. Named groups behave like numbered groups but
are additionally accessible via subexpressionNamed: and subexpressionNames.'.
```

## Test Cases

```smalltalk
testBasicNamedCapture
    | m |
    m := RxbtMatcher forString: '(?<year>\d{4})-(?<month>\d{2})'.
    self assert: (m search: '2024-03').
    self assert: (m subexpressionNamed: 'year')  = '2024'.
    self assert: (m subexpressionNamed: 'month') = '03'.

testNamedCaptureGroupNumber
    "Named groups also accessible by number."
    | m |
    m := RxbtMatcher forString: '(?<word>\w+)'.
    m search: 'hello'.
    self assert: (m subexpression: 2) = 'hello'.
    self assert: (m subexpressionNamed: 'word') = 'hello'.

testSubexpressionNames
    | m |
    m := RxbtMatcher forString: '(?<a>\w)(?<b>\d)'.
    self assert: (m subexpressionNames asSortedCollection asArray) = #('a' 'b').

testUnknownName
    | m |
    m := RxbtMatcher forString: '(?<x>\w+)'.
    m search: 'hi'.
    self assert: (m subexpressionNamed: 'missing') isNil.

testNamedBackreference
    "Doubled word using named backreference."
    | m |
    m := RxbtMatcher forString: '(?<w>\w+)\s+\k<w>'.
    self assert: (m search: 'hello hello').
    self assert: (m subexpressionNamed: 'w') = 'hello'.
    self deny:   (m search: 'hello world').

testNamedVsNumbered
    "Named capture coexists with numbered capture."
    | m |
    m := RxbtMatcher forString: '(\d+)-(?<tag>[a-z]+)'.
    m search: '42-abc'.
    self assert: (m subexpression: 2) = '42'.
    self assert: (m subexpressionNamed: 'tag') = 'abc'.
```

## Acceptance Criteria

```smalltalk
RxbtNamedCaptureTest suite run printString.   "all pass"
RxbtMatcherTest       suite run printString.   "176/176 — no regression"
```

## Pitfalls

- `registerGroupName: at:` must compute the group number consistently with `subexpression:`.
  If `startIdx = 1`, group = 1 (whole match); `startIdx = 3`, group = 2; etc.
  Formula: `(startIdx + 1) // 2`. Verify with a two-group pattern.
- `syntaxNamedBackreference:` reads `matcher groupNames` at COMPILE time. If `\k<name>`
  appears BEFORE the named group `(?<name>...)` in the pattern, `groupNames` will not
  yet contain the name → returns `false` block. This matches PCRE forward-reference
  behaviour (undefined = fail). Document this limitation.
- `groupNames` must be reset in `initialize:ignoreCase:` (not just allocated lazily)
  to avoid stale names from a previous compilation on the same object.
