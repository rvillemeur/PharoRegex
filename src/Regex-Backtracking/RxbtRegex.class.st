"
Alternation node. branch is the first RxbtBranch; regex is the remaining alternation (RxbtRegex) or nil. Drives syntaxRegex: in RxbtCompiler which allocates capture marker pairs.
"
Class {
	#name : 'RxbtRegex',
	#superclass : 'RxbtNode',
	#instVars : [
		'branch',
		'regex'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'accessing' }
RxbtRegex >> branch [ ^branch
]

{ #category : 'double dispatch' }
RxbtRegex >> dispatchTo: aMatcher [
    ^aMatcher syntaxRegex: self
]

{ #category : 'initialize' }
RxbtRegex >> initializeBranch: aBranch regex: aRegex [
    branch := aBranch.
    regex := aRegex
]

{ #category : 'testing' }
RxbtRegex >> isNullable [
    ^branch isNullable or: [regex isNotNil and: [regex isNullable]]
]

{ #category : 'accessing' }
RxbtRegex >> regex [ ^regex
]
