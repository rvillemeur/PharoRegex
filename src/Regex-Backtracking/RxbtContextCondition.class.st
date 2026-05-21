"
Zero-width assertion node. kind is a Symbol naming the syntax*: method on RxbtCompiler to call via perform: (e.g. #syntaxBeginningOfLine). isNullable is true for all except #syntaxAny.
"
Class {
	#name : 'RxbtContextCondition',
	#superclass : 'RxbtNode',
	#instVars : [
		'kind'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'initialize' }
RxbtContextCondition >> beAny [ kind := #syntaxAny
]

{ #category : 'initialize' }
RxbtContextCondition >> beBeginningOfLine [ kind := #syntaxBeginningOfLine
]

{ #category : 'initialize' }
RxbtContextCondition >> beBeginningOfWord [ kind := #syntaxBeginningOfWord
]

{ #category : 'initialize' }
RxbtContextCondition >> beEndOfLine [ kind := #syntaxEndOfLine
]

{ #category : 'initialize' }
RxbtContextCondition >> beEndOfWord [ kind := #syntaxEndOfWord
]

{ #category : 'initialize' }
RxbtContextCondition >> beNonWordBoundary [ kind := #syntaxNonWordBoundary
]

{ #category : 'initialize' }
RxbtContextCondition >> beWordBoundary [ kind := #syntaxWordBoundary
]

{ #category : 'double dispatch' }
RxbtContextCondition >> dispatchTo: aBuilder [
    ^aBuilder perform: kind
]

{ #category : 'testing' }
RxbtContextCondition >> isNullable [ ^#syntaxAny ~~ kind
]
