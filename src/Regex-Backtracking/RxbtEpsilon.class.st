"
Empty node. Used at end of branch and alternation chains. isNullable = true; drives syntaxEpsilon which always succeeds without advancing position.
"
Class {
	#name : 'RxbtEpsilon',
	#superclass : 'RxbtNode',
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtEpsilon >> dispatchTo: aBuilder [
    ^aBuilder syntaxEpsilon
]

{ #category : 'testing' }
RxbtEpsilon >> isNullable [ ^true
]
