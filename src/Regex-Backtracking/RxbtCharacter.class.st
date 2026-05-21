"
Literal character node. character holds the Character to match. isAtomic returns true for substring optimisation.
"
Class {
	#name : 'RxbtCharacter',
	#superclass : 'RxbtNode',
	#instVars : [
		'character'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'instance creation' }
RxbtCharacter class >> with: aCharacter [
    ^self new initializeCharacter: aCharacter
]

{ #category : 'accessing' }
RxbtCharacter >> character [ ^character
]

{ #category : 'double dispatch' }
RxbtCharacter >> dispatchTo: aMatcher [
    ^aMatcher syntaxCharacter: self
]

{ #category : 'enumeration' }
RxbtCharacter >> enumerateTo: aSet ignoringCase: aBoolean [
    aBoolean
        ifTrue: [aSet add: character asUppercase. aSet add: character asLowercase]
        ifFalse: [aSet add: character]
]

{ #category : 'initialize' }
RxbtCharacter >> initializeCharacter: aChar [ character := aChar
]

{ #category : 'testing' }
RxbtCharacter >> isAtomic [ ^true
]

{ #category : 'testing' }
RxbtCharacter >> isEnumerable [ ^true
]
