"
Compiles a regex AST into a CPS (continuation-passing style) closure tree for RxbtMatcher. Implements the visitor protocol (syntax*: methods) defined by RxsNode>>dispatchTo:. Each syntax*: method returns a [:pos :cont | Boolean] block. Runtime state (inputString, captures) is read via the matcher back-reference. CPS helpers (greedyStar:, lazyStar:, etc.) are private and called only from syntaxPiece:.
"
Class {
	#name : 'RxbtCompiler',
	#superclass : 'Object',
	#instVars : [
		'matcher',
		'ignoreCase',
		'markerCount',
		'groupMap',
		'flags'
	],
	#category : 'Regex-Backtracking-Base',
	#package : 'Regex-Backtracking',
	#tag : 'Base'
}

{ #category : 'instance creation' }
RxbtCompiler class >> for: aMatcher ignoreCase: aBoolean [
    ^self new initializeFor: aMatcher ignoreCase: aBoolean
]

{ #category : 'building' }
RxbtCompiler >> allocateMarker [
    markerCount := markerCount + 1.
    ^markerCount
]

{ #category : 'building' }
RxbtCompiler >> compile: syntaxTree [
    "Visit the AST and return the root CPS block."
    ^syntaxTree dispatchTo: self
]

{ #category : 'cps-possessive' }
RxbtCompiler >> consumeAll: atomBlock from: pos [
    | cur advanced |
    cur := pos.
    [advanced := false.
     atomBlock value: cur value: [:newPos |
         newPos > cur ifTrue: [cur := newPos. advanced := true].
         false].
     advanced] whileTrue.
    ^cur
]

{ #category : 'accessing' }
RxbtCompiler >> flags [
    ^flags
]

{ #category : 'cps-greedy' }
RxbtCompiler >> greedyOptional: atomBlock [
    ^[:pos :cont |
        (atomBlock value: pos value: cont) or: [cont value: pos]]
]

{ #category : 'cps-greedy' }
RxbtCompiler >> greedyPlus: atomBlock [
    ^[:pos :cont |
        atomBlock value: pos value: [:pos2 |
            self matchStar: atomBlock from: pos2 continuation: cont]]
]

{ #category : 'cps-greedy' }
RxbtCompiler >> greedyRepeat: atomBlock min: minN max: maxN [
    ^[:pos :cont |
        self matchRepeat: atomBlock from: pos count: 0
             min: minN max: maxN continuation: cont]
]

{ #category : 'cps-greedy' }
RxbtCompiler >> greedyStar: atomBlock [
    ^[:pos :cont | self matchStar: atomBlock from: pos continuation: cont]
]

{ #category : 'initialize' }
RxbtCompiler >> initializeFor: aMatcher ignoreCase: aBoolean [
    matcher     := aMatcher.
    ignoreCase  := aBoolean.
    markerCount := 0.
    groupMap    := IdentityDictionary new.
    flags       := aBoolean
        ifTrue:  [RxbtFlags caseInsensitive]
        ifFalse: [RxbtFlags default]
]

{ #category : 'private' }
RxbtCompiler >> isWordChar: aChar [
    ^aChar isLetter or: [aChar isDigit or: [aChar = $_]]
]

{ #category : 'cps-lazy' }
RxbtCompiler >> lazyOptional: atomBlock [
    ^[:pos :cont |
        (cont value: pos) ifTrue: [true] ifFalse: [atomBlock value: pos value: cont]]
]

{ #category : 'cps-lazy' }
RxbtCompiler >> lazyPlus: atomBlock [
    ^[:pos :cont |
        atomBlock value: pos value: [:pos2 |
            self matchLazyStar: atomBlock from: pos2 continuation: cont]]
]

{ #category : 'cps-lazy' }
RxbtCompiler >> lazyRepeat: atomBlock min: minN max: maxN [
    ^[:pos :cont |
        self matchLazyRepeat: atomBlock from: pos count: 0
             min: minN max: maxN continuation: cont]
]

{ #category : 'cps-lazy' }
RxbtCompiler >> lazyStar: atomBlock [
    ^[:pos :cont | self matchLazyStar: atomBlock from: pos continuation: cont]
]

{ #category : 'accessing' }
RxbtCompiler >> markerCount [
    ^markerCount
]

{ #category : 'private' }
RxbtCompiler >> matchLazyRepeat: atomBlock from: startPos count: startN min: minN max: maxN continuation: cont [
    | cur n prevCur next result |
    cur := startPos.
    n := startN.
    prevCur := nil.
    [n >= minN ifTrue: [
         result := prevCur isNil
             ifTrue:  [cont value: cur]
             ifFalse: [
                 atomBlock value: prevCur value: [:np |
                     np = cur ifTrue: [cont value: cur] ifFalse: [false]]].
         result ifTrue: [^true]].
     (maxN notNil and: [n >= maxN]) ifTrue: [^false].
     next := nil.
     atomBlock value: cur value: [:np |
         np > cur ifTrue: [next := np].
         false].
     next isNil ifTrue: [^false].
     prevCur := cur.
     cur := next.
     n := n + 1.
     true] repeat
]

{ #category : 'private' }
RxbtCompiler >> matchLazyStar: atomBlock from: startPos continuation: cont [
    | cur prevCur next result |
    cur := startPos.
    prevCur := nil.
    [result := prevCur isNil
        ifTrue:  [cont value: cur]
        ifFalse: [
            atomBlock value: prevCur value: [:np |
                np = cur ifTrue: [cont value: cur] ifFalse: [false]]].
     result ifTrue: [^true].
     next := nil.
     atomBlock value: cur value: [:np |
         np > cur ifTrue: [next := np].
         false].
     next isNil ifTrue: [^false].
     prevCur := cur.
     cur := next.
     true] repeat
]

{ #category : 'private' }
RxbtCompiler >> matchRepeat: atomBlock from: startPos count: startN min: minN max: maxN continuation: cont [
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
    positions size to: 1 by: -1 do: [:i |
        | assoc pos count |
        assoc := positions at: i.
        pos := assoc key.
        count := assoc value.
        count >= minN ifTrue: [
            i = 1
                ifTrue: [
                    (cont value: pos) ifTrue: [^true]]
                ifFalse: [
                    | prevPos |
                    prevPos := (positions at: i - 1) key.
                    (atomBlock value: prevPos value: [:np |
                        np = pos ifTrue: [cont value: pos] ifFalse: [false]])
                        ifTrue: [^true]]]].
    ^false
]

{ #category : 'private' }
RxbtCompiler >> matchStar: atomBlock from: startPos continuation: cont [
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
    positions size to: 1 by: -1 do: [:i |
        | pos |
        pos := positions at: i.
        i = 1
            ifTrue: [
                (cont value: pos) ifTrue: [^true]]
            ifFalse: [
                | prevPos |
                prevPos := positions at: i - 1.
                (atomBlock value: prevPos value: [:np |
                    np = pos ifTrue: [cont value: pos] ifFalse: [false]])
                    ifTrue: [^true]]].
    ^false
]

{ #category : 'cps-possessive' }
RxbtCompiler >> possessiveOptional: atomBlock [
    ^[:pos :cont |
        | matchedPos |
        matchedPos := pos.
        atomBlock value: pos value: [:newPos | matchedPos := newPos. false].
        cont value: matchedPos]
]

{ #category : 'cps-possessive' }
RxbtCompiler >> possessivePlus: atomBlock [
    ^[:pos :cont |
        | firstPos |
        firstPos := nil.
        atomBlock value: pos value: [:p | firstPos := p. false].
        firstPos isNil
            ifTrue:  [false]
            ifFalse: [cont value: (self consumeAll: atomBlock from: firstPos)]]
]

{ #category : 'cps-possessive' }
RxbtCompiler >> possessiveRepeat: atomBlock min: minN max: maxN [
    ^[:pos :cont |
        | cur count done |
        cur := pos. count := 0. done := false.
        [done not and: [maxN isNil or: [count < maxN]]] whileTrue: [
            | prev |
            prev := cur.
            atomBlock value: cur value: [:newPos |
                newPos > cur ifTrue: [cur := newPos. count := count + 1].
                false].
            cur = prev ifTrue: [done := true]].
        count < minN
            ifTrue:  [false]
            ifFalse: [cont value: cur]]
]

{ #category : 'cps-possessive' }
RxbtCompiler >> possessiveStar: atomBlock [
    ^[:pos :cont |
        cont value: (self consumeAll: atomBlock from: pos)]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxAny [
    | da |
    da := flags dotall.
    ^[:pos :cont |
        | str ch |
        str := matcher inputString.
        pos <= str size
            ifTrue: [
                ch := str at: pos.
                (ch asInteger ~= 0 and: [da or: [ch asInteger ~= 10]])
                    ifTrue:  [cont value: pos + 1]
                    ifFalse: [false]]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxAtomicGroup: node [
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    ^[:pos :cont |
        | endPos |
        endPos := nil.
        innerBlock value: pos value: [:ep |
            endPos isNil ifTrue: [endPos := ep].
            false].
        endPos isNil
            ifTrue:  [false]
            ifFalse: [cont value: endPos]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxBackreference: node [
    | markerIdx |
    markerIdx := node groupIndex + 1.
    ^[:pos :cont |
        | caps str start end refText sz |
        caps := matcher captures.
        str  := matcher inputString.
        (2 * markerIdx > caps size)
            ifTrue: [ false ]
            ifFalse: [
                start := caps at: 2 * markerIdx - 1.
                end   := caps at: 2 * markerIdx.
                (start isNil or: [ end isNil ])
                    ifTrue: [ false ]
                    ifFalse: [
                        refText := str copyFrom: start to: end - 1.
                        sz := refText size.
                        (pos + sz - 1 > str size)
                            ifTrue: [ false ]
                            ifFalse: [
                                (ignoreCase
                                    ifTrue:  [ (str copyFrom: pos to: pos + sz - 1) asLowercase = refText asLowercase ]
                                    ifFalse: [ (str copyFrom: pos to: pos + sz - 1) = refText ])
                                    ifTrue:  [ cont value: pos + sz ]
                                    ifFalse: [ false ] ] ] ] ]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxBeginningOfLine [
    | ml |
    ml := flags multiline.
    ^[:pos :cont |
        | str atBOL prev |
        str := matcher inputString.
        atBOL := pos = 1 or: [
            ml and: [
                pos > 1 and: [
                    prev := str at: pos - 1.
                    prev = (Character value: 10) or: [
                        prev = (Character value: 13) and: [
                            pos > str size or: [
                                (str at: pos) ~= (Character value: 10)]]]]]].
        atBOL ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxBeginningOfString [
    ^[:pos :cont |
        pos = 1
            ifTrue:  [cont value: pos]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxBeginningOfWord [
    ^[:pos :cont |
        | str atWord prevWord |
        str := matcher inputString.
        atWord   := pos <= str size and: [self isWordChar: (str at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (str at: pos - 1)].
        (atWord and: [prevWord not]) ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxBranch: branchNode [
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
RxbtCompiler >> syntaxCharSet: charSetNode [
    | f predBlock |
    f := flags.
    predBlock := charSetNode predicateIgnoringCase: f ignoreCase.
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos <= str size and: [predBlock value: (str at: pos)])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxCharacter: charNode [
    | f ch |
    f  := flags.
    ch := charNode character.
    (f extended and: [ch isSeparator]) ifTrue: [
        ^[:pos :cont | cont value: pos]].
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos <= str size and: [
            f ignoreCase
                ifTrue:  [(str at: pos) asLowercase = ch asLowercase]
                ifFalse: [(str at: pos) = ch]])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxEndOfLine [
    | ml |
    ml := flags multiline.
    ^[:pos :cont |
        | str atEOL cur |
        str := matcher inputString.
        atEOL := pos > str size or: [
            ml and: [
                cur := str at: pos.
                cur = (Character value: 13) or: [
                    cur = (Character value: 10) and: [
                        pos = 1 or: [(str at: pos - 1) ~= (Character value: 13)]]]]].
        atEOL ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxEndOfString [
    ^[:pos :cont |
        pos > matcher inputString size
            ifTrue:  [cont value: pos]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxEndOfStringZ [
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        pos > str size
            ifTrue:  [cont value: pos]
            ifFalse: [
                (pos = str size and: [(str at: pos) = (Character value: 10)])
                    ifTrue:  [cont value: pos + 1]
                    ifFalse: [false]]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxEndOfWord [
    ^[:pos :cont |
        | str atWord prevWord |
        str := matcher inputString.
        atWord   := pos <= str size and: [self isWordChar: (str at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (str at: pos - 1)].
        (prevWord and: [atWord not]) ifTrue: [cont value: pos] ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxEpsilon [
    ^[:pos :cont | cont value: pos]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxGenericNewline [
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        pos > str size
            ifTrue: [false]
            ifFalse: [
                (pos < str size
                    and: [(str at: pos) = (Character value: 13)
                    and: [(str at: pos + 1) = (Character value: 10)]])
                    ifTrue: [cont value: pos + 2]
                    ifFalse: [
                        (#(10 11 12 13 133) anySatisfy: [:b | (str at: pos) = (Character value: b)])
                            ifTrue:  [cont value: pos + 1]
                            ifFalse: [false]]]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxInlineModifier: node [
    | savedFlags newFlags |
    savedFlags := flags.
    newFlags   := flags applySet: node setFlags clear: node clearFlags.
    node isScoped
        ifTrue: [
            | innerBlock |
            flags := newFlags.
            innerBlock := node inner dispatchTo: self.
            flags := savedFlags.
            ^innerBlock]
        ifFalse: [
            flags := newFlags.
            ^[:pos :cont | cont value: pos]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxLookaround: node [
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
RxbtCompiler >> syntaxLookbehind: node [
    | innerBlock |
    innerBlock := node inner dispatchTo: self.
    node positive
        ifTrue: [
            ^[:pos :cont |
                | caps saved found |
                caps := matcher captures.
                saved := caps copy.
                found := false.
                1 to: pos - 1 do: [:start |
                    found ifFalse: [
                        found := innerBlock value: start value: [:endPos | endPos = pos]]].
                1 to: saved size do: [:i | caps at: i put: (saved at: i)].
                found ifTrue: [cont value: pos] ifFalse: [false]]]
        ifFalse: [
            ^[:pos :cont |
                | caps saved found |
                caps := matcher captures.
                saved := caps copy.
                found := false.
                1 to: pos - 1 do: [:start |
                    found ifFalse: [
                        found := innerBlock value: start value: [:endPos | endPos = pos]]].
                1 to: saved size do: [:i | caps at: i put: (saved at: i)].
                found ifTrue: [false] ifFalse: [cont value: pos]]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxMessagePredicate: node [
    | sel neg |
    sel := node selector.
    neg := node negated.
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos <= str size and: [((str at: pos) perform: sel) xor: neg])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxNamedBackreference: node [
    | groupNum |
    groupNum := matcher groupNames
        ifNil: [nil]
        ifNotNil: [:gn | gn at: node name ifAbsent: [nil]].
    groupNum isNil ifTrue: [^[:pos :cont | false]].
    ^[:pos :cont |
        | caps str start end refText sz |
        caps := matcher captures.
        str  := matcher inputString.
        (2 * groupNum > caps size)
            ifTrue: [false]
            ifFalse: [
                start := caps at: 2 * groupNum - 1.
                end   := caps at: 2 * groupNum.
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
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxNamedCapture: node [
    | startIdx endIdx altBlocks inner |
    startIdx := self allocateMarker.
    endIdx   := self allocateMarker.
    matcher registerGroupName: node name at: (startIdx + 1) // 2.
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
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxNonCapturingGroup: node [
    | altBlocks inner |
    altBlocks := OrderedCollection new.
    inner := node inner.
    [inner notNil] whileTrue: [
        altBlocks add: (inner branch dispatchTo: self).
        inner := inner regex].
    altBlocks size = 1 ifTrue: [^altBlocks first].
    ^[:pos :cont |
        | result |
        result := false.
        altBlocks do: [:ab |
            result ifFalse: [
                result := ab value: pos value: cont]].
        result]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxNonWordBoundary [
    ^[:pos :cont |
        | str atWord prevWord |
        str := matcher inputString.
        atWord   := pos <= str size and: [self isWordChar: (str at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (str at: pos - 1)].
        (atWord xor: prevWord) ifFalse: [cont value: pos] ifTrue: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxPiece: pieceNode [
    | atomBlock |
    atomBlock := pieceNode atom dispatchTo: self.
    pieceNode isSingular ifTrue: [ ^atomBlock ].
    pieceNode isPossessive
        ifTrue: [
            pieceNode isStar     ifTrue: [ ^self possessiveStar: atomBlock ].
            pieceNode isPlus     ifTrue: [ ^self possessivePlus: atomBlock ].
            pieceNode isOptional ifTrue: [ ^self possessiveOptional: atomBlock ].
            ^self possessiveRepeat: atomBlock min: pieceNode min max: pieceNode max ].
    pieceNode isLazy
        ifTrue: [
            pieceNode isStar     ifTrue: [ ^self lazyStar: atomBlock ].
            pieceNode isPlus     ifTrue: [ ^self lazyPlus: atomBlock ].
            pieceNode isOptional ifTrue: [ ^self lazyOptional: atomBlock ].
            ^self lazyRepeat: atomBlock min: pieceNode min max: pieceNode max ].
    pieceNode isStar     ifTrue: [ ^self greedyStar: atomBlock ].
    pieceNode isPlus     ifTrue: [ ^self greedyPlus: atomBlock ].
    pieceNode isOptional ifTrue: [ ^self greedyOptional: atomBlock ].
    ^self greedyRepeat: atomBlock min: pieceNode min max: pieceNode max
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxPredicate: predNode [
    ^[:pos :cont |
        | str |
        str := matcher inputString.
        (pos <= str size and: [predNode value: (str at: pos)])
            ifTrue: [cont value: pos + 1]
            ifFalse: [false]]
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxRegex: regexNode [
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
]

{ #category : 'syntax' }
RxbtCompiler >> syntaxWordBoundary [
    ^[:pos :cont |
        | str atWord prevWord |
        str := matcher inputString.
        atWord   := pos <= str size and: [self isWordChar: (str at: pos)].
        prevWord := pos > 1 and: [self isWordChar: (str at: pos - 1)].
        (atWord xor: prevWord) ifTrue: [cont value: pos] ifFalse: [false]]
]
