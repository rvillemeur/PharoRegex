"
AST node for \R (generic newline).
Matches CRLF as a single unit, or any single vertical whitespace (LF VT FF CR NEL).
CRLF takes priority — cannot be modelled as a simple character predicate.
"
Class {
	#name : 'RxbtGenericNewline',
	#superclass : 'RxbtNode',
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'double dispatch' }
RxbtGenericNewline >> dispatchTo: aCompiler [
    ^aCompiler syntaxGenericNewline
]

{ #category : 'testing' }
RxbtGenericNewline >> isNullable [
    ^false
]
