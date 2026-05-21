"
Lazy (non-greedy) quantified atom. Matches the minimum number of repetitions first. isLazy returns true, overriding RxbtPiece default.
"
Class {
	#name : 'RxbtLazyPiece',
	#superclass : 'RxbtPiece',
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'testing' }
RxbtLazyPiece >> isLazy [ 
    ^true
]
