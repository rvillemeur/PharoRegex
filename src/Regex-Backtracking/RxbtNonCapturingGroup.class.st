"
AST node for a non-capturing group (?:...).
Wraps the inner alternation tree. RxbtCompiler compiles it like an alternation
but allocates no capture markers, so subexpressionCount is unaffected.
"
Class {
	#name : 'RxbtNonCapturingGroup',
	#superclass : 'RxbtNode',
	#instVars : [
		'inner'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtNonCapturingGroup >> dispatchTo: aCompiler [
    ^aCompiler syntaxNonCapturingGroup: self
]

{ #category : 'accessing' }
RxbtNonCapturingGroup >> inner [
    ^inner
]

{ #category : 'initialize' }
RxbtNonCapturingGroup >> inner: aNode [
    inner := aNode
]

{ #category : 'testing' }
RxbtNonCapturingGroup >> isNullable [
    ^inner isNullable
]
