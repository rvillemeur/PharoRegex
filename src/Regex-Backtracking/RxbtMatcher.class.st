"
Drop-in backtracking replacement for RxMatcher. Provides the same public API but uses a CPS (continuation-passing style) engine that supports true backtracking, lazy quantifiers (*? +? ?? {n,m}?), backreferences (\1..\9), possessive quantifiers (*+ ++ ?+ {n,m}+), and atomic groups (?>...).

## Responsibilities
- Public API: create matchers, run matches, expose capture groups.
- Hold runtime state: inputString (current subject), captures (1-based marker array), markerCount, rootBlock.
- Delegate ALL compilation to RxbtCompiler, which visits the AST and builds the CPS closure tree.

## Creation
  RxbtMatcher forString: 'a+'
  RxbtMatcher forString: 'a+' ignoreCase: true
  RxbtMatcher for: aSyntaxTree

## Matching
  matcher matches: aString            ""full match""
  matcher matchesPrefix: aString      ""prefix match""
  matcher search: aString             ""search anywhere""
  matcher searchStream: aStream

## Captures (1-based; group 1 = whole match, group 2 = first explicit group)
  matcher subexpression: n            ""String or nil""
  matcher subexpressionCount

## Internals
rootBlock is a [:pos :cont | Boolean] closure built by RxbtCompiler.
captures is an Array of 1-based string positions: index 2n-1 = start of group n, 2n = end.
Each match call resets captures to a fresh nil-filled array.

See RxbtCompiler for the CPS engine implementation.
"
Class {
	#name : 'RxbtMatcher',
	#superclass : 'Object',
	#instVars : [
		'ignoreCase',
		'inputString',
		'captures',
		'markerCount',
		'rootBlock',
		'groupNames',
		'optimizer',
		'stepCount',
		'stepLimit'
	],
	#category : 'Regex-Backtracking-Base',
	#package : 'Regex-Backtracking',
	#tag : 'Base'
}

{ #category : 'instance creation' }
RxbtMatcher class >> for: aSyntaxTree [
    ^self for: aSyntaxTree ignoreCase: false
]

{ #category : 'instance creation' }
RxbtMatcher class >> for: aSyntaxTree ignoreCase: aBoolean [
    ^self new initialize: aSyntaxTree ignoreCase: aBoolean
]

{ #category : 'instance creation' }
RxbtMatcher class >> forString: aString [
    ^self forString: aString ignoreCase: false
]

{ #category : 'instance creation' }
RxbtMatcher class >> forString: aString ignoreCase: aBoolean [
    | tree |
    tree := RxbtParser safelyParse: aString.
    ^tree ifNotNil: [self for: tree ignoreCase: aBoolean]
]

{ #category : 'accessing' }
RxbtMatcher >> captures [
    ^captures
]

{ #category : 'accessing' }
RxbtMatcher >> captures: anArray [ captures := anArray
]

{ #category : 'replace' }
RxbtMatcher >> copy: aString replacingMatchesWith: replacement [
    | answer |
    answer := (String new: aString size) writeStream.
    self copyStream: aString readStream to: answer replacingMatchesWith: replacement.
    ^answer contents
]

{ #category : 'replace' }
RxbtMatcher >> copy: aString translatingMatchesUsing: aBlock [
    | answer |
    answer := (String new: aString size) writeStream.
    self copyStream: aString readStream to: answer translatingMatchesUsing: aBlock.
    ^answer contents
]

{ #category : 'replace' }
RxbtMatcher >> copyStream: aStream to: writeStream replacingMatchesWith: replacement [
    | searchStart preMatchLen |
    [searchStart := aStream position.
     self searchStream: aStream] whileTrue: [
        preMatchLen := (captures at: 1) - 1 - searchStart.
        aStream position: searchStart.
        preMatchLen timesRepeat: [writeStream nextPut: aStream next].
        writeStream nextPutAll: replacement.
        aStream position: (captures at: 2) - 1.
        (captures at: 1) = (captures at: 2) ifTrue: [
            aStream atEnd ifTrue: [^self].
            writeStream nextPut: aStream next]].
    [aStream atEnd] whileFalse: [writeStream nextPut: aStream next]
]

{ #category : 'replace' }
RxbtMatcher >> copyStream: aStream to: writeStream translatingMatchesUsing: aBlock [
    | searchStart preMatchLen matchStr |
    [searchStart := aStream position.
     self searchStream: aStream] whileTrue: [
        preMatchLen := (captures at: 1) - 1 - searchStart.
        aStream position: searchStart.
        preMatchLen timesRepeat: [writeStream nextPut: aStream next].
        matchStr := self subexpression: 1.
        aStream position: (captures at: 2) - 1.
        writeStream nextPutAll: (aBlock value: matchStr).
        (captures at: 1) = (captures at: 2) ifTrue: [
            aStream atEnd ifTrue: [^self].
            writeStream nextPut: aStream next]].
    [aStream atEnd] whileFalse: [writeStream nextPut: aStream next]
]

{ #category : 'accessing' }
RxbtMatcher >> groupNames [
    ^groupNames
]

{ #category : 'private' }
RxbtMatcher >> incrementStep [
    stepCount := stepCount + 1.
    stepCount > self stepLimit ifTrue: [
        RxbtMatchingError signal:
            'Regex step limit exceeded (',
            self stepLimit printString,
            ' steps) — possible catastrophic backtracking']
]

{ #category : 'initialization' }
RxbtMatcher >> initialize: syntaxTreeRoot ignoreCase: aBoolean [
    | compiler |
    ignoreCase  := aBoolean.
    groupNames  := nil.
    compiler    := RxbtCompiler for: self ignoreCase: aBoolean.
    rootBlock   := compiler compile: syntaxTreeRoot.
    markerCount := compiler markerCount.
    captures    := Array new: markerCount withAll: nil.
    optimizer   := RxbtMatchOptimizer new
                       initialize: syntaxTreeRoot
                       ignoreCase: aBoolean.
    stepCount   := 0
]

{ #category : 'accessing' }
RxbtMatcher >> inputAt: pos [
    ^inputString at: pos
]

{ #category : 'accessing' }
RxbtMatcher >> inputSize [
    ^inputString size
]

{ #category : 'accessing' }
RxbtMatcher >> inputString [
    ^inputString
]

{ #category : 'matching' }
RxbtMatcher >> matches: aString [
    inputString := aString.
    captures := Array new: markerCount withAll: nil.
    ^rootBlock value: 1 value: [:endPos | endPos = (aString size + 1)]
]

{ #category : 'matching' }
RxbtMatcher >> matchesIn: aString [
    | result |
    result := OrderedCollection new.
    self matchesOnStream: aString readStream do: [:match | result add: match].
    ^result
]

{ #category : 'matching' }
RxbtMatcher >> matchesIn: aString collect: aBlock [
    | result |
    result := OrderedCollection new.
    self matchesOnStream: aString readStream do: [:match | result add: (aBlock value: match)].
    ^result
]

{ #category : 'matching' }
RxbtMatcher >> matchesIn: aString do: aBlock [
    self matchesOnStream: aString readStream do: aBlock
]

{ #category : 'matching' }
RxbtMatcher >> matchesOnStream: aStream [
    | result |
    result := OrderedCollection new.
    self matchesOnStream: aStream do: [:match | result add: match].
    ^result
]

{ #category : 'matching' }
RxbtMatcher >> matchesOnStream: aStream collect: aBlock [
    | result |
    result := OrderedCollection new.
    self matchesOnStream: aStream do: [:match | result add: (aBlock value: match)].
    ^result
]

{ #category : 'matching' }
RxbtMatcher >> matchesOnStream: aStream do: aBlock [
    | subexpression |
    [self searchStream: aStream] whileTrue: [
        subexpression := self subexpression: 1.
        aBlock value: subexpression.
        subexpression size = 0 ifTrue: [
            aStream atEnd ifTrue: [^self].
            aStream next]]
]

{ #category : 'matching' }
RxbtMatcher >> matchesPrefix: aString [
    inputString := aString.
    captures := Array new: markerCount withAll: nil.
    ^rootBlock value: 1 value: [:endPos | true]
]

{ #category : 'matching' }
RxbtMatcher >> matchesStream: aStream [
    | str startPos |
    str := aStream upToEnd.
    aStream reset.
    inputString := str.
    captures := Array new: markerCount withAll: nil.
    startPos := aStream position + 1.
    (rootBlock value: startPos value: [:endPos | endPos = (str size + 1)])
        ifTrue: [aStream position: str size. ^true].
    ^false
]

{ #category : 'matching' }
RxbtMatcher >> matchesStreamPrefix: aStream [
    | str startPos result endPos |
    str := aStream upToEnd.
    aStream reset.
    inputString := str.
    captures := Array new: markerCount withAll: nil.
    startPos := aStream position + 1.
    result := rootBlock value: startPos value: [:ep | endPos := ep. true].
    result ifTrue: [aStream position: endPos - 1].
    ^result
]

{ #category : 'matching' }
RxbtMatcher >> matchingRangesIn: aString [
    | result |
    result := OrderedCollection new.
    self matchesIn: aString do: [:match |
        result add: ((captures at: 1) to: (captures at: 2) - 1)].
    ^result
]

{ #category : 'accessing' }
RxbtMatcher >> registerGroupName: aString at: groupNumber [
    groupNames ifNil: [groupNames := Dictionary new].
    groupNames at: aString put: groupNumber
]

{ #category : 'private' }
RxbtMatcher >> resetStepCount [
    stepCount := 0
]

{ #category : 'matching' }
RxbtMatcher >> search: aString [
    ^self searchStream: aString readStream
]

{ #category : 'matching' }
RxbtMatcher >> searchStream: aStream [
    | str startPos |
    str := aStream contents.
    inputString := str.
    self resetStepCount.
    startPos := aStream position + 1.
    startPos to: str size + 1 do: [:pos |
        | lookahead |
        lookahead := pos <= str size
            ifTrue:  [str at: pos]
            ifFalse: [nil].
        (optimizer canStartMatch: lookahead at: pos) ifTrue: [
            captures := Array new: markerCount withAll: nil.
            (rootBlock value: pos value: [:endPos |
                aStream position: (captures at: 2) - 1.
                true])
                ifTrue: [^true]]].
    ^false
]

{ #category : 'matching' }
RxbtMatcher >> split: aString indicesDo: aBlock [
    | stream lastPosition matchStart matchEnd |
    stream := aString readStream.
    lastPosition := 0.
    [self searchStream: stream] whileTrue: [
        matchStart := captures at: 1.
        matchEnd := captures at: 2.
        aBlock value: lastPosition + 1 value: matchStart - 1.
        matchEnd = matchStart ifTrue: [Error signal: 'Regex cannot match null string'].
        lastPosition := matchEnd - 1].
    aBlock value: lastPosition + 1 value: aString size
]

{ #category : 'accessing' }
RxbtMatcher >> stepCount [ ^stepCount
]

{ #category : 'accessing' }
RxbtMatcher >> stepLimit [
    ^stepLimit ifNil: [1000000]
]

{ #category : 'accessing' }
RxbtMatcher >> stepLimit: anInteger [
    stepLimit := anInteger
]

{ #category : 'accessing' }
RxbtMatcher >> subexpression: n [
    | start end |
    start := captures at: (2 * n) - 1.
    end   := captures at: 2 * n.
    (start isNil or: [end isNil]) ifTrue: [^nil].
    ^inputString copyFrom: start to: end - 1
]

{ #category : 'accessing' }
RxbtMatcher >> subexpressionCount [
    ^markerCount // 2
]

{ #category : 'accessing' }
RxbtMatcher >> subexpressionNamed: aString [
    | idx start end |
    groupNames isNil ifTrue: [^nil].
    idx := groupNames at: aString ifAbsent: [^nil].
    start := captures at: 2 * idx - 1.
    end   := captures at: 2 * idx.
    (start isNil or: [end isNil]) ifTrue: [^nil].
    ^inputString copyFrom: start to: end - 1
]

{ #category : 'accessing' }
RxbtMatcher >> subexpressionNames [
    groupNames isNil ifTrue: [^#()].
    ^groupNames keys
]

{ #category : 'accessing' }
RxbtMatcher >> supportsSubexpressions [
    ^true
]
