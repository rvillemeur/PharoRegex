Class {
	#name : 'RxbtMatchOptimizer',
	#superclass : 'Object',
	#instVars : [
		'ignoreCase',
		'prefixes',
		'nonPrefixes',
		'conditions',
		'predicates',
		'nonPredicates',
		'methodPredicates',
		'nonMethodPredicates',
		'lookarounds',
		'testBlock'
	],
	#category : 'Regex-Backtracking-Base',
	#package : 'Regex-Backtracking',
	#tag : 'Base'
}

{ #category : 'testing' }
RxbtMatchOptimizer >> canStartMatch: aCharOrNil at: pos [
    aCharOrNil ifNil: [^true].
    ^testBlock isNil or: [testBlock value: aCharOrNil value: pos]
]

{ #category : 'private' }
RxbtMatchOptimizer >> conditionTester [
    | sel |
    conditions isEmpty ifTrue: [^nil].
    conditions size = 1 ifTrue: [
        sel := conditions anyOne.
        sel = #atBeginningOfLine ifTrue: [^nil].
        sel = #atEndOfLine       ifTrue: [^nil].
        sel = #atBeginningOfWord ifTrue: [^nil].
        sel = #atEndOfWord       ifTrue: [^nil].
        sel = #atWordBoundary    ifTrue: [^nil].
        sel = #notAtWordBoundary ifTrue: [^nil]].
    ^nil
]

{ #category : 'private' }
RxbtMatchOptimizer >> determineTestMethod [
    | testers |
    (conditions includes: #any) ifTrue: [^nil].
    testers := OrderedCollection new.
    #(prefixTester nonPrefixTester conditionTester
      predicateTester nonPredicateTester
      methodPredicateTester nonMethodPredicateTester)
        do: [:sel | (self perform: sel) ifNotNil: [:t | testers add: t]].
    testers isEmpty ifTrue: [^nil].
    testers size = 1 ifTrue: [^testers first].
    testers := testers asArray.
    ^[:char :pos | testers contains: [:t | t value: char value: pos]]
]

{ #category : 'initialization' }
RxbtMatchOptimizer >> initialize: aRxbtRegexNode ignoreCase: aBoolean [
    ignoreCase       := aBoolean.
    prefixes         := Set new: 10.
    nonPrefixes      := Set new: 10.
    conditions       := Set new: 3.
    predicates       := Set new: 3.
    nonPredicates    := Set new: 3.
    methodPredicates    := Set new: 3.
    nonMethodPredicates := Set new: 3.
    lookarounds      := Set new: 3.
    aRxbtRegexNode dispatchTo: self.
    aRxbtRegexNode isNullable ifTrue: [conditions add: #atEndOfLine].
    testBlock := self determineTestMethod
]

{ #category : 'private' }
RxbtMatchOptimizer >> methodPredicateTester [
    | p selector |
    methodPredicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: methodPredicates.
    ^p size = 1
        ifTrue: [
            selector := p first.
            [:char :pos |
                [char perform: selector]
                    on: MessageNotUnderstood do: [:e | false]]]
        ifFalse: [
            [:char :pos |
                p contains: [:sel |
                    [char perform: sel]
                        on: MessageNotUnderstood do: [:e | false]]]]
]

{ #category : 'private' }
RxbtMatchOptimizer >> nonMethodPredicateTester [
    | p selector |
    nonMethodPredicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: nonMethodPredicates.
    ^p size = 1
        ifTrue: [
            selector := p first.
            [:char :pos |
                ([char perform: selector]
                    on: MessageNotUnderstood do: [:e | false]) not]]
        ifFalse: [
            [:char :pos |
                p contains: [:sel |
                    ([char perform: sel]
                        on: MessageNotUnderstood do: [:e | false]) not]]]
]

{ #category : 'private' }
RxbtMatchOptimizer >> nonPredicateTester [
    | p pred |
    nonPredicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: nonPredicates.
    ^p size = 1
        ifTrue: [pred := p first. [:char :pos | (pred value: char) not]]
        ifFalse: [[:char :pos | p contains: [:pr | (pr value: char) not]]]
]

{ #category : 'private' }
RxbtMatchOptimizer >> nonPrefixTester [
    | np nonPrefixChar |
    nonPrefixes isEmpty ifTrue: [^nil].
    np := self optimizeSet: nonPrefixes.
    ^np size = 1
        ifTrue: [
            nonPrefixChar := np first.
            [:char :pos | char ~= nonPrefixChar]]
        ifFalse: [[:char :pos | (np includes: char) not]]
]

{ #category : 'private' }
RxbtMatchOptimizer >> optimizeSet: aSet [
    ^aSet size < 10 ifTrue: [aSet asArray] ifFalse: [aSet]
]

{ #category : 'private' }
RxbtMatchOptimizer >> predicateTester [
    | p pred |
    predicates isEmpty ifTrue: [^nil].
    p := self optimizeSet: predicates.
    ^p size = 1
        ifTrue: [pred := p first. [:char :pos | pred value: char]]
        ifFalse: [[:char :pos | p contains: [:pr | pr value: char]]]
]

{ #category : 'private' }
RxbtMatchOptimizer >> prefixTester [
    | p prefixChar |
    prefixes isEmpty ifTrue: [^nil].
    p := self optimizeSet: prefixes.
    ignoreCase ifTrue: [p := p collect: [:c | c asUppercase]].
    ^p size = 1
        ifTrue: [
            prefixChar := p first.
            ignoreCase
                ifTrue:  [[:char :pos | char sameAs: prefixChar]]
                ifFalse: [[:char :pos | char = prefixChar]]]
        ifFalse: [
            ignoreCase
                ifTrue:  [[:char :pos | p includes: char asUppercase]]
                ifFalse: [[:char :pos | p includes: char]]]
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxAny [
    conditions add: #any
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxAtomicGroup: node [
    node inner dispatchTo: self
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxBackreference: node [
    conditions add: #any
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxBeginningOfLine [
    conditions add: #atBeginningOfLine
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxBeginningOfString [
    conditions add: #atBeginningOfLine
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxBeginningOfWord [
    conditions add: #atBeginningOfWord
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxBranch: node [
    (node piece isNullable and: [node branch notNil])
        ifTrue: [node branch dispatchTo: self].
    node piece dispatchTo: self
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxCharSet: node [
    | pred |
    pred := node predicateIgnoringCase: ignoreCase.
    predicates add: pred
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxCharacter: node [
    prefixes add: node character
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxEndOfLine [
    conditions add: #atEndOfLine
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxEndOfString [
    conditions add: #atEndOfLine
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxEndOfStringZ [
    conditions add: #atEndOfLine
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxEndOfWord [
    conditions add: #atEndOfWord
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxEpsilon [
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxGenericNewline [
    prefixes add: (Character value: 13).
    prefixes add: (Character value: 10)
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxInlineModifier: node [
    node inner ifNotNil: [:inner | inner dispatchTo: self]
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxLookaround: node [
    lookarounds add: node
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxLookbehind: node [
    lookarounds add: node
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxMessagePredicate: node [
    node negated
        ifFalse: [methodPredicates    add: node selector]
        ifTrue:  [nonMethodPredicates add: node selector]
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxNamedBackreference: node [
    conditions add: #any
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxNamedCapture: node [
    node inner dispatchTo: self
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxNonCapturingGroup: node [
    node inner dispatchTo: self
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxNonWordBoundary [
    conditions add: #notAtWordBoundary
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxPiece: node [
    node atom dispatchTo: self
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxPredicate: node [
    predicates add: node predicate
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxRegex: node [
    node branch dispatchTo: self.
    node regex ifNotNil: [:r | r dispatchTo: self]
]

{ #category : 'visitor' }
RxbtMatchOptimizer >> syntaxWordBoundary [
    conditions add: #atWordBoundary
]
