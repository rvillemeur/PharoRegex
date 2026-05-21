"
Atomic group node (?>...). inner is an RxbtRegex. On match, commits to the first (greedy) result with no backtracking into the group.
"
Class {
	#name : 'RxbtAtomicGroup',
	#superclass : 'RxbtNode',
	#instVars : [
		'inner'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtAtomicGroup >> dispatchTo: aMatcher [
    ^aMatcher syntaxAtomicGroup: self
]

{ #category : 'accessing' }
RxbtAtomicGroup >> inner [ 
    ^inner
]

{ #category : 'initialize' }
RxbtAtomicGroup >> inner: aNode [
    inner := aNode
]

{ #category : 'testing' }
RxbtAtomicGroup >> isAtomic [ 
    ^true
]

{ #category : 'testing' }
RxbtAtomicGroup >> isNullable [ 
    ^inner isNullable
]
