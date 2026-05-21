"
Concatenation node. piece is an RxbtPiece; branch is the rest of the branch (RxbtBranch) or nil. Drives syntaxBranch: in RxbtCompiler.
"
Class {
	#name : 'RxbtBranch',
	#superclass : 'RxbtNode',
	#instVars : [
		'piece',
		'branch'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'accessing' }
RxbtBranch >> branch [ ^branch
]

{ #category : 'double dispatch' }
RxbtBranch >> dispatchTo: aMatcher [
    ^aMatcher syntaxBranch: self
]

{ #category : 'initialize' }
RxbtBranch >> initializePiece: aPiece branch: aBranch [
    piece := aPiece.
    branch := aBranch
]

{ #category : 'testing' }
RxbtBranch >> isNullable [
    ^piece isNullable and: [branch isNil or: [branch isNullable]]
]

{ #category : 'accessing' }
RxbtBranch >> piece [ ^piece
]

{ #category : 'optimising' }
RxbtBranch >> tryMergingInto: aStream [
    piece isAtomic ifFalse: [^self].
    aStream nextPut: piece character.
    ^branch ifNil: [branch] ifNotNil: [branch tryMergingInto: aStream]
]
