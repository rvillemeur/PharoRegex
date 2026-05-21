"
Possessive quantifier piece. Matches greedily but never backtracks into the quantifier. Produced by RxParser for *+, ++, ?+, {n,m}+. RxbtMatcher>>syntaxPiece: checks isPossessive first and dispatches to possessive CPS helpers.
"
Class {
	#name : 'RxsPossessivePiece',
	#superclass : 'RxsPiece',
	#category : 'Regex-Backtracking',
	#package : 'Regex-Backtracking'
}

{ #category : 'testing' }
RxsPossessivePiece >> isPossessive [
    "Always true — this piece uses possessive (no-backtrack) semantics."
    ^true
]
