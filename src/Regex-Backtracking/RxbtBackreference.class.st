"
Numeric backreference \\1-\\9. groupIndex (1-based) is resolved to a marker index at compile time by RxbtCompiler>>syntaxBackreference:.
"
Class {
	#name : 'RxbtBackreference',
	#superclass : 'RxbtNode',
	#instVars : [
		'groupIndex'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtBackreference >> dispatchTo: aMatcher [
    ^aMatcher syntaxBackreference: self
]

{ #category : 'accessing' }
RxbtBackreference >> groupIndex [ 
    ^groupIndex
]

{ #category : 'initialize' }
RxbtBackreference >> groupIndex: n [
    groupIndex := n
]

{ #category : 'testing' }
RxbtBackreference >> isAtomic [ 
    ^true
]

{ #category : 'testing' }
RxbtBackreference >> isNullable [ 
    ^false
]
