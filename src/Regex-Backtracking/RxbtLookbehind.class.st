Class {
	#name : 'RxbtLookbehind',
	#superclass : 'RxbtNode',
	#instVars : [
		'inner',
		'positive'
	],
	#category : 'Regex-Backtracking',
	#package : 'Regex-Backtracking'
}

{ #category : 'initialize' }
RxbtLookbehind >> beNegative [ positive := false
]

{ #category : 'double dispatch' }
RxbtLookbehind >> dispatchTo: aCompiler [
    ^aCompiler syntaxLookbehind: self
]

{ #category : 'accessing' }
RxbtLookbehind >> inner [ ^inner
]

{ #category : 'initialize' }
RxbtLookbehind >> inner: aNode [
    inner := aNode.
    positive := true
]

{ #category : 'testing' }
RxbtLookbehind >> isNullable [ ^true
]

{ #category : 'accessing' }
RxbtLookbehind >> positive [ ^positive
]
