"
AST node for a named backreference \k<name>.
Matches text previously captured by the named group. Resolved to a marker
index at compile time via RxbtCompiler.
"
Class {
	#name : 'RxbtNamedBackreference',
	#superclass : 'RxbtNode',
	#instVars : [
		'name'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtNamedBackreference >> dispatchTo: aCompiler [
    ^aCompiler syntaxNamedBackreference: self
]

{ #category : 'testing' }
RxbtNamedBackreference >> isNullable [
    ^false
]

{ #category : 'accessing' }
RxbtNamedBackreference >> name [
    ^name
]

{ #category : 'initialize' }
RxbtNamedBackreference >> name: aString [
    name := aString
]
