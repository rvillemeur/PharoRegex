"
Character range node for use inside bracket expressions. first and last are the boundary Characters. isEnumerable=true.
"
Class {
	#name : 'RxbtRange',
	#superclass : 'RxbtNode',
	#instVars : [
		'first',
		'last'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'instance creation' }
RxbtRange class >> from: f to: l [ ^self new initializeFirst: f last: l
]

{ #category : 'enumeration' }
RxbtRange >> enumerateTo: aSet ignoringCase: aBoolean [
    first asInteger to: last asInteger do: [:n |
        | c |
        c := n asCharacter.
        aBoolean
            ifTrue:  [aSet add: c asUppercase. aSet add: c asLowercase]
            ifFalse: [aSet add: c]]
]

{ #category : 'initialize' }
RxbtRange >> initializeFirst: f last: l [ first := f. last := l
]

{ #category : 'testing' }
RxbtRange >> isEnumerable [ ^true
]
