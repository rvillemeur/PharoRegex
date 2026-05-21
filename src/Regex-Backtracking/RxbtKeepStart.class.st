"
AST node for \K (keep-start reset). Zero-width — resets the reported match start to the current position. Everything before \K is excluded from subexpression: 1.
"
Class {
	#name : 'RxbtKeepStart',
	#superclass : 'RxbtNode',
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtKeepStart >> dispatchTo: aCompiler [ ^aCompiler syntaxKeepStart
]

{ #category : 'testing' }
RxbtKeepStart >> isNullable [ ^true
]
