"
Message-send predicate node :selector:. Matches characters for which (char perform: selector) xor negated is true.
"
Class {
	#name : 'RxbtMessagePredicate',
	#superclass : 'RxbtNode',
	#instVars : [
		'selector',
		'negated'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtMessagePredicate >> dispatchTo: aBuilder [
    ^aBuilder syntaxMessagePredicate: self
]

{ #category : 'initialize' }
RxbtMessagePredicate >> initializeSelector: sel [
    selector := sel
]

{ #category : 'initialize' }
RxbtMessagePredicate >> initializeSelector: sel negated: neg [
    selector := sel. negated := neg
]

{ #category : 'accessing' }
RxbtMessagePredicate >> negated [ ^negated
]

{ #category : 'accessing' }
RxbtMessagePredicate >> selector [ ^selector
]
