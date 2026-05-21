"
Lookahead assertion node. piece is the inner RxbtRegex; positive=true for (?=...), positive=false for (?!...). Zero-width: does not consume input on success.
"
Class {
	#name : 'RxbtLookaround',
	#superclass : 'RxbtNode',
	#instVars : [
		'piece',
		'positive'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'instance creation' }
RxbtLookaround class >> with: anRxbtPiece [
    ^self new initializePiece: anRxbtPiece
]

{ #category : 'initialize' }
RxbtLookaround >> beNegative [ positive := false
]

{ #category : 'initialize' }
RxbtLookaround >> bePositive [ positive := true
]

{ #category : 'double dispatch' }
RxbtLookaround >> dispatchTo: aBuilder [
    ^aBuilder syntaxLookaround: self
]

{ #category : 'initialize' }
RxbtLookaround >> initializePiece: anRxbtPiece [
    super initialize.
    piece := anRxbtPiece
]

{ #category : 'accessing' }
RxbtLookaround >> piece [ ^piece
]

{ #category : 'accessing' }
RxbtLookaround >> positive [ ^positive
]
