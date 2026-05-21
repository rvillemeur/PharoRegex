"
AST node for a backreference (\1..\9). groupIndex holds the 1-based explicit group number (1 = first explicit capture group, matching Perl/PCRE convention). RxbtMatcher>>syntaxBackreference: translates to marker index as groupIndex + 1.
"
Class {
	#name : 'RxsBackreference',
	#superclass : 'RxsNode',
	#instVars : [
		'groupIndex'
	],
	#category : 'Regex-Backtracking',
	#package : 'Regex-Backtracking'
}

{ #category : 'double dispatch' }
RxsBackreference >> dispatchTo: aMatcher [
    ^aMatcher syntaxBackreference: self
]

{ #category : 'accessing' }
RxsBackreference >> groupIndex [ ^groupIndex
]

{ #category : 'initialize' }
RxsBackreference >> groupIndex: n [ groupIndex := n
]

{ #category : 'testing' }
RxsBackreference >> isAtomic [ ^true
]

{ #category : 'testing' }
RxsBackreference >> isNullable [ ^false
]
