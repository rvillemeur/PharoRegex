"
Bracket expression node [abc...]. elements is a collection of RxbtCharacter/RxbtRange/RxbtPredicate; negated=true for [^...]. Drives syntaxCharSet: which builds a combined predicate block at compile time.
"
Class {
	#name : 'RxbtCharSet',
	#superclass : 'RxbtNode',
	#instVars : [
		'negated',
		'elements'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtCharSet >> dispatchTo: aMatcher [
    ^aMatcher syntaxCharSet: self
]

{ #category : 'private' }
RxbtCharSet >> enumerablePartPredicateIgnoringCase: aBoolean [
    | enum |
    enum := self optimalSetIgnoringCase: aBoolean.
    ^negated
        ifTrue:  [[:c | (enum includes: c) not]]
        ifFalse: [[:c | enum includes: c]]
]

{ #category : 'private' }
RxbtCharSet >> enumerableSetIgnoringCase: aBoolean [
    | set |
    set := Set new.
    elements do: [:e | e isEnumerable ifTrue: [e enumerateTo: set ignoringCase: aBoolean]].
    ^set
]

{ #category : 'testing' }
RxbtCharSet >> hasPredicates [
    ^elements contains: [:e | e isEnumerable not]
]

{ #category : 'initialize' }
RxbtCharSet >> initializeElements: aCollection negated: aBoolean [
    elements := aCollection. negated := aBoolean
]

{ #category : 'testing' }
RxbtCharSet >> isEnumerable [
    ^elements anySatisfy: [:e | e isEnumerable]
]

{ #category : 'testing' }
RxbtCharSet >> isNegated [ ^negated
]

{ #category : 'private' }
RxbtCharSet >> optimalSetIgnoringCase: aBoolean [
    | set |
    set := self enumerableSetIgnoringCase: aBoolean.
    ^set size < 10 ifTrue: [set asArray] ifFalse: [set]
]

{ #category : 'predicates' }
RxbtCharSet >> predicateIgnoringCase: aBoolean [
    | enum |
    enum := self enumerablePartPredicateIgnoringCase: aBoolean.
    ^self hasPredicates
        ifFalse: [enum]
        ifTrue: [
            | pred |
            pred := self predicatePartPredicate.
            negated
                ifTrue:  [[:c | (enum value: c) and: [pred value: c]]]
                ifFalse: [[:c | (enum value: c) or: [pred value: c]]]]
]

{ #category : 'private' }
RxbtCharSet >> predicatePartPredicate [
    | preds |
    preds := elements reject: [:e | e isEnumerable].
    preds isEmpty ifTrue: [^[:c | negated]].
    preds size = 1 ifTrue: [
        ^negated
            ifTrue:  [preds first predicateNegation]
            ifFalse: [preds first predicate]].
    preds := preds collect: [:e | e predicate].
    ^negated
        ifFalse: [[:c | preds contains: [:p | p value: c]]]
        ifTrue:  [[:c | (preds contains: [:p | p value: c]) not]]
]

{ #category : 'accessing' }
RxbtCharSet >> predicates [
    ^(elements reject: [:e | e isEnumerable]) collect: [:e | e predicate]
]
