"
AST node for a named capture group (?<name>...).
Behaves like a numbered capture group but also registers name -> groupNumber
in RxbtMatcher so captured text is retrievable via subexpressionNamed:.
"
Class {
	#name : 'RxbtNamedCapture',
	#superclass : 'RxbtNode',
	#instVars : [
		'name',
		'inner'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtNamedCapture >> dispatchTo: aCompiler [
    ^aCompiler syntaxNamedCapture: self
]

{ #category : 'accessing' }
RxbtNamedCapture >> inner [
    ^inner
]

{ #category : 'testing' }
RxbtNamedCapture >> isNullable [
    ^inner isNullable
]

{ #category : 'accessing' }
RxbtNamedCapture >> name [
    ^name
]

{ #category : 'initialize' }
RxbtNamedCapture >> name: aString inner: aNode [
    name := aString.
    inner := aNode
]
