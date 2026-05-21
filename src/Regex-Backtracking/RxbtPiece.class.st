"
Quantified atom node. atom is the inner node; min/max are occurrence bounds (max=nil means infinity). Drives syntaxPiece: which dispatches to greedy/lazy/possessive helpers.
"
Class {
	#name : 'RxbtPiece',
	#superclass : 'RxbtNode',
	#instVars : [
		'atom',
		'min',
		'max'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'accessing' }
RxbtPiece >> atom [ 
    ^atom
]

{ #category : 'accessing' }
RxbtPiece >> character [ 
    ^atom character
]

{ #category : 'double dispatch' }
RxbtPiece >> dispatchTo: aMatcher [
    ^aMatcher syntaxPiece: self
]

{ #category : 'initialize' }
RxbtPiece >> initializeAtom: anAtom [
    self initializeAtom: anAtom min: 1 max: 1
]

{ #category : 'initialize' }
RxbtPiece >> initializeAtom: anAtom min: minN max: maxN [
    atom := anAtom. min := minN. max := maxN
]

{ #category : 'initialize' }
RxbtPiece >> initializeOptionalAtom: anAtom [
    self initializeAtom: anAtom min: 0 max: 1
]

{ #category : 'initialize' }
RxbtPiece >> initializePlusAtom: anAtom [
    self initializeAtom: anAtom min: 1 max: nil
]

{ #category : 'initialize' }
RxbtPiece >> initializeStarAtom: anAtom [
    self initializeAtom: anAtom min: 0 max: nil
]

{ #category : 'testing' }
RxbtPiece >> isAtomic [ 
    ^self isSingular and: [atom isAtomic]
]

{ #category : 'testing' }
RxbtPiece >> isLazy [ 
    ^false
]

{ #category : 'testing' }
RxbtPiece >> isNullable [ 
    ^min = 0 or: [atom isNullable]
]

{ #category : 'testing' }
RxbtPiece >> isOptional [ 
    ^min = 0 and: [max = 1]
]

{ #category : 'testing' }
RxbtPiece >> isPlus [ 
    ^min = 1 and: [max == nil]
]

{ #category : 'testing' }
RxbtPiece >> isPossessive [ 
    ^false
]

{ #category : 'testing' }
RxbtPiece >> isSingular [ 
    ^min = 1 and: [max = 1]
]

{ #category : 'testing' }
RxbtPiece >> isStar [ 
    ^min = 0 and: [max == nil]
]

{ #category : 'accessing' }
RxbtPiece >> max [ 
    ^max
]

{ #category : 'accessing' }
RxbtPiece >> min [ 
    ^min
]
