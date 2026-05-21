"
AST node for an atomic group (?>...). Matches inner pattern greedily and commits — no backtracking into the group if the continuation fails.
"
Class {
	#name : 'RxsAtomicGroup',
	#superclass : 'RxsNode',
	#instVars : [
		'inner'
	],
	#category : 'Regex-Backtracking',
	#package : 'Regex-Backtracking'
}

{ #category : 'double dispatch' }
RxsAtomicGroup >> dispatchTo: aMatcher [
    ^aMatcher syntaxAtomicGroup: self
]

{ #category : 'accessing' }
RxsAtomicGroup >> inner [ ^inner
]

{ #category : 'initialize' }
RxsAtomicGroup >> inner: aNode [ inner := aNode
]

{ #category : 'testing' }
RxsAtomicGroup >> isAtomic [ ^true
]

{ #category : 'testing' }
RxsAtomicGroup >> isNullable [ ^inner isNullable
]
