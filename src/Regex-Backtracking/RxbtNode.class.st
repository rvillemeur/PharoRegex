"
Abstract base for the Regex-Backtracking AST. Fully independent of Regex-Core.
RxbtParser produces these nodes; RxbtCompiler consumes them via dispatchTo: (double-dispatch visitor).
Each subclass implements dispatchTo: aCompiler calling the matching syntax*: method.
"
Class {
	#name : 'RxbtNode',
	#superclass : 'Object',
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'printing' }
RxbtNode >> indentCharacter [ ^$+
]

{ #category : 'testing' }
RxbtNode >> isAtomic [ ^false
]

{ #category : 'testing' }
RxbtNode >> isEnumerable [ ^false
]

{ #category : 'testing' }
RxbtNode >> isNullable [ ^false
]
