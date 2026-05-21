"
Possessive quantified atom. Matches greedily and never backtracks. isPossessive returns true, overriding RxbtPiece default.
"
Class {
	#name : 'RxbtPossessivePiece',
	#superclass : 'RxbtPiece',
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'testing' }
RxbtPossessivePiece >> isPossessive [ ^true
]
