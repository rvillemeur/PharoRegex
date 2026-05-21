Class {
	#name : 'RxbtNonCapturingGroup',
	#superclass : 'RxbtNode',
	#instVars : [
		'inner'
	],
	#category : 'Regex-Backtracking',
	#package : 'Regex-Backtracking'
}

{ #category : 'double dispatch' }
RxbtNonCapturingGroup >> dispatchTo: aCompiler [
    ^aCompiler syntaxNonCapturingGroup: self
]

{ #category : 'accessing' }
RxbtNonCapturingGroup >> inner [ ^inner
]

{ #category : 'initialize' }
RxbtNonCapturingGroup >> inner: aNode [ inner := aNode
]

{ #category : 'testing' }
RxbtNonCapturingGroup >> isNullable [ ^inner isNullable
]
