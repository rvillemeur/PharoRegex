"
Lazy (non-greedy) quantifier piece. Produced by RxParser for *?, +?, ??, and {n,m}?. Identical to RxsPiece except isLazy returns true, causing RxbtMatcher>>syntaxPiece: to dispatch to lazy CPS helpers instead of greedy ones.
"
Class {
	#name : 'RxsLazyPiece',
	#superclass : 'RxsPiece',
	#category : 'Regex-Backtracking',
	#package : 'Regex-Backtracking'
}

{ #category : 'testing' }
RxsLazyPiece >> isLazy [
    "Always true — this piece carries lazy (non-greedy) semantics."
    ^true
]
