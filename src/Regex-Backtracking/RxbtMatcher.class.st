Class {
	#name : 'RxbtMatcher',
	#superclass : 'Object',
	#instVars : [
		'ignoreCase',
		'inputString',
		'captures',
		'markerCount',
		'rootBlock',
		'groupMap'
	],
	#category : 'Regex-Backtracking',
	#package : 'Regex-Backtracking'
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
    tree := RxParser safelyParse: aString.
    ^tree ifNotNil: [self for: tree ignoreCase: aBoolean]
]

{ #category : 'building' }
RxbtMatcher >> allocateMarker [
    markerCount := markerCount + 1.
    ^markerCount
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

{ #category : 'matching' }
RxbtMatcher >> greedyOptional: atomBlock [
    ^[:pos :cont |
        (atomBlock value: pos value: cont) or: [cont value: pos]]
]

{ #category : 'matching' }
RxbtMatcher >> greedyPlus: atomBlock [
    ^[:pos :cont |
        atomBlock value: pos value: [:pos2 |
            self matchStar: atomBlock from: pos2 continuation: cont]]
]

{ #category : 'matching' }
RxbtMatcher >> greedyRepeat: atomBlock min: minN max: maxN [
    ^[:pos :cont |
        self matchRepeat: atomBlock from: pos count: 0 min: minN max: maxN continuation: cont]
]

{ #category : 'matching' }
RxbtMatcher >> greedyStar: atomBlock [
    ^[:pos :cont | self matchStar: atomBlock from: pos continuation: cont]
]

{ #category : 'building' }
RxbtMatcher >> initialize: syntaxTreeRoot ignoreCase: aBoolean [
    ignoreCase := aBoolean.
    markerCount := 0.
    groupMap := IdentityDictionary new.
    rootBlock := syntaxTreeRoot dispatchTo: self.
    captures := Array new: markerCount withAll: nil
]

{ #category : 'accessing' }
RxbtMatcher >> inputAt: pos [
    ^inputString at: pos
]

{ #category : 'accessing' }
RxbtMatcher >> inputSize [
    ^inputString size
]

{ #category : 'private' }
RxbtMatcher >> isWordChar: aChar [
    ^aChar isLetter or: [aChar isDigit or: [aChar = $_]]
]

{ #category : 'building' }
RxbtMatcher >> lazyOptional: atomBlock [
    "Return a CPS block matching zero or one occurrence, lazy (zero first)."
    ^[ :pos :cont |
        (cont value: pos) ifTrue: [ true ] ifFalse: [ atomBlock value: pos value: cont ] ]
]

{ #category : 'building' }
RxbtMatcher >> lazyPlus: atomBlock [
    "Return a CPS block matching one or more repetitions, lazy (fewest first)."
    ^[ :pos :cont |
        atomBlock value: pos value: [ :pos2 |
            self matchLazyStar: atomBlock from: pos2 continuation: cont ] ]
]

{ #category : 'building' }
RxbtMatcher >> lazyRepeat: atomBlock min: minN max: maxN [
    "Return a CPS block for lazy {minN,maxN} — fewest matches first."
    ^[ :pos :cont |
        self matchLazyRepeat: atomBlock from: pos count: 0
             min: minN max: maxN continuation: cont ]
]

{ #category : 'building' }
RxbtMatcher >> lazyStar: atomBlock [
    "Return a CPS block matching zero or more repetitions, lazy (fewest first)."
    ^[ :pos :cont | self matchLazyStar: atomBlock from: pos continuation: cont ]
]

{ #category : 'building' }
RxbtMatcher >> matchLazyRepeat: atomBlock from: pos count: n min: minN max: maxN continuation: cont [
    "Recursive lazy {n,m}: try continuation as soon as minimum is reached."
    n >= minN ifTrue: [
        (cont value: pos) ifTrue: [ ^true ] ].
    (maxN notNil and: [ n >= maxN ]) ifTrue: [ ^false ].
    ^atomBlock value: pos value: [ :newPos |
        newPos = pos
            ifTrue:  [ false ]
            ifFalse: [ self matchLazyRepeat: atomBlock from: newPos count: n + 1
                            min: minN max: maxN continuation: cont ] ]
]

{ #category : 'building' }
RxbtMatcher >> matchLazyStar: atomBlock from: pos continuation: cont [
    "Try zero matches first (lazy). Expand by one on continuation failure."
    (cont value: pos) ifTrue: [ ^true ].
    ^atomBlock value: pos value: [ :newPos |
        newPos = pos
            ifTrue:  [ false ]
            ifFalse: [ self matchLazyStar: atomBlock from: newPos continuation: cont ] ]
]

{ #category : 'matching' }
RxbtMatcher >> matchRepeat: atomBlock from: pos count: n min: minN max: maxN continuation: cont [
    | result |
    (maxN notNil and: [n >= maxN]) ifTrue: [
        ^n >= minN ifTrue: [cont value: pos] ifFalse: [false]].
    result := atomBlock value: pos value: [:newPos |
        newPos = pos
            ifTrue:  [n >= minN ifTrue: [cont value: newPos] ifFalse: [false]]
            ifFalse: [self matchRepeat: atomBlock from: newPos count: n+1
                          min: minN max: maxN continuation: cont]].
    (result not and: [n >= minN]) ifTrue: [^cont value: pos].
    ^result
]

{ #category : 'matching' }
RxbtMatcher >> matchStar: atomBlock from: pos continuation: cont [
    | result |
    result := atomBlock value: pos value: [:newPos |
        newPos = pos
            ifTrue:  [cont value: newPos]
            ifFalse: [self matchStar: atomBlock from: newPos continuation: cont]].
    result ifFalse: [^cont value: pos].
    ^result
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

{ #category : 'matching' }
RxbtMatcher >> search: aString [
    ^self searchStream: aString readStream
]

{ #category : 'matching' }
RxbtMatcher >> searchStream: aStream [
    | str startPos |
    str := aStream contents.
    inputString := str.
    startPos := aStream position + 1.
    startPos to: str size + 1 do: [:pos |
        captures := Array new: markerCount withAll: nil.
        (rootBlock value: pos value: [:endPos | true])
            ifTrue: [aStream position: (captures at: 2) - 1. ^true]].
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
RxbtMatcher >> supportsSubexpressions [
    ^true
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxAny [
    ^[:pos :cont |
        (pos <= inputString size and: [(inputString at: pos) asInteger ~= 0])
            ifTrue:  [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxBeginningOfLine [
    ^[:pos :cont |
        | atBOL prev |
        atBOL := pos = 1 or: [
            prev := inputString at: pos - 1.
            prev = (Character value: 10) or: [
                prev = (Character value: 13) and: [
                    pos > inputString size or: [
                        (inputString at: pos) ~= (Character value: 10)]]]].
        atBOL ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxBeginningOfWord [
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (atWord and: [prevWord not]) ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxBranch: branchNode [
    | pieceBlock restBlock |
    pieceBlock := branchNode piece dispatchTo: self.
    restBlock := branchNode branch isNil
        ifTrue:  [nil]
        ifFalse: [branchNode branch dispatchTo: self].
    restBlock isNil ifTrue: [^pieceBlock].
    ^[:pos :cont |
        pieceBlock value: pos value: [:pos2 |
            restBlock value: pos2 value: cont]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxCharSet: charSetNode [
    | predBlock |
    predBlock := charSetNode predicateIgnoringCase: ignoreCase.
    ^[:pos :cont |
        (pos <= inputString size and: [predBlock value: (inputString at: pos)])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxCharacter: charNode [
    ^[:pos :cont |
        (pos <= inputString size and: [
            ignoreCase
                ifTrue:  [(inputString at: pos) asLowercase = charNode character asLowercase]
                ifFalse: [(inputString at: pos) = charNode character]])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxEndOfLine [
    ^[:pos :cont |
        | atEOL cur |
        atEOL := pos > inputString size or: [
            cur := inputString at: pos.
            cur = (Character value: 13) or: [
                cur = (Character value: 10) and: [
                    pos = 1 or: [(inputString at: pos - 1) ~= (Character value: 13)]]]].
        atEOL ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxEndOfWord [
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (prevWord and: [atWord not]) ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxEpsilon [
    ^[:pos :cont | cont value: pos]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxLookaround: node [
    | innerBlock |
    innerBlock := node piece dispatchTo: self.
    node positive
        ifTrue: [
            ^[:pos :cont |
                (innerBlock value: pos value: [:_ | true])
                    ifTrue:  [cont value: pos]
                    ifFalse: [false]]]
        ifFalse: [
            ^[:pos :cont |
                (innerBlock value: pos value: [:_ | true])
                    ifTrue:  [false]
                    ifFalse: [cont value: pos]]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxMessagePredicate: node [
    | sel neg |
    sel := node selector.
    neg := node negated.
    ^[:pos :cont |
        (pos <= inputString size and: [
            ((inputString at: pos) perform: sel) xor: neg])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxNonWordBoundary [
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (atWord xor: prevWord) ifFalse: [cont value: pos] ifTrue: [false]]
]

{ #category : 'building' }
RxbtMatcher >> syntaxPiece: pieceNode [
    "Dispatch to greedy or lazy CPS helpers based on pieceNode isLazy."
    | atomBlock |
    atomBlock := pieceNode atom dispatchTo: self.
    pieceNode isSingular ifTrue: [ ^atomBlock ].
    pieceNode isLazy
        ifTrue: [
            pieceNode isStar     ifTrue: [ ^self lazyStar: atomBlock ].
            pieceNode isPlus     ifTrue: [ ^self lazyPlus: atomBlock ].
            pieceNode isOptional ifTrue: [ ^self lazyOptional: atomBlock ].
            ^self lazyRepeat: atomBlock min: pieceNode min max: pieceNode max ]
        ifFalse: [
            pieceNode isStar     ifTrue: [ ^self greedyStar: atomBlock ].
            pieceNode isPlus     ifTrue: [ ^self greedyPlus: atomBlock ].
            pieceNode isOptional ifTrue: [ ^self greedyOptional: atomBlock ].
            ^self greedyRepeat: atomBlock min: pieceNode min max: pieceNode max ]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxPredicate: predNode [
    ^[:pos :cont |
        (pos <= inputString size and: [predNode value: (inputString at: pos)])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxRegex: regexNode [
    | startIdx endIdx altBlocks node |
    startIdx := self allocateMarker.
    endIdx   := self allocateMarker.
    groupMap at: regexNode put: startIdx.
    altBlocks := OrderedCollection new.
    node := regexNode.
    [node notNil] whileTrue: [
        altBlocks add: (node branch dispatchTo: self).
        node := node regex].
    ^[:pos :cont |
        | savedStart savedEnd result |
        savedStart := captures at: startIdx.
        savedEnd   := captures at: endIdx.
        captures at: startIdx put: pos.
        result := false.
        altBlocks do: [:ab |
            result ifFalse: [
                result := ab value: pos value: [:endPos |
                    captures at: endIdx put: endPos.
                    cont value: endPos]]].
        result ifFalse: [
            captures at: startIdx put: savedStart.
            captures at: endIdx   put: savedEnd].
        result]
]

{ #category : 'syntax' }
RxbtMatcher >> syntaxWordBoundary [
    ^[:pos :cont |
        | atWord prevWord |
        atWord   := pos <= inputString size and: [self isWordChar: (inputString at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (inputString at: pos - 1)].
        (atWord xor: prevWord) ifTrue: [cont value: pos] ifFalse: [false]]
]
