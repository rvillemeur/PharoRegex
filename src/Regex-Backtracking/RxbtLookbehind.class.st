"
AST node for lookbehind assertions (?<=...) and (?<!...).
positive=true for positive lookbehind, false for negative.
At runtime the inner pattern is tried against all substrings ending at the current
position. Zero-width: does not advance pos on success.
"
Class {
	#name : 'RxbtLookbehind',
	#superclass : 'RxbtNode',
	#instVars : [
		'inner',
		'positive'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'initialize' }
RxbtLookbehind >> beNegative [
    positive := false
]

{ #category : 'double dispatch' }
RxbtLookbehind >> dispatchTo: aCompiler [
    ^aCompiler syntaxLookbehind: self
]

{ #category : 'accessing' }
RxbtLookbehind >> inner [
    ^inner
]

{ #category : 'initialize' }
RxbtLookbehind >> inner: aNode [
    inner := aNode.
    positive := true
]

{ #category : 'testing' }
RxbtLookbehind >> isNullable [
    ^true
]

{ #category : 'accessing' }
RxbtLookbehind >> positive [
    ^positive
]
