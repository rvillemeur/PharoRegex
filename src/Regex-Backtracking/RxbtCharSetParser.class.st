"
Parser for bracket expressions [...] inside RxbtParser. Produces collections of RxbtCharacter, RxbtRange, and RxbtPredicate nodes. Independent of Regex-Core: no RxParser or Rxs* references.
"
Class {
	#name : 'RxbtCharSetParser',
	#superclass : 'Object',
	#instVars : [
		'source',
		'lookahead',
		'elements'
	],
	#category : 'Regex-Backtracking-Utilities',
	#package : 'Regex-Backtracking',
	#tag : 'Utilities'
}

{ #category : 'instance creation' }
RxbtCharSetParser class >> on: aStream [ ^self new initialize: aStream
]

{ #category : 'parsing' }
RxbtCharSetParser >> addChar: aChar [
    elements add: (RxbtCharacter with: aChar)
]

{ #category : 'parsing' }
RxbtCharSetParser >> addRangeFrom: f to: l [
    f asInteger > l asInteger ifTrue: [
        RxbtSyntaxError signal: ' bad character range' at: source position].
    elements add: (RxbtRange from: f to: l)
]

{ #category : 'initialize' }
RxbtCharSetParser >> initialize: aStream [
    source := aStream.
    lookahead := aStream next.
    elements := OrderedCollection new
]

{ #category : 'parsing' }
RxbtCharSetParser >> match: aChar [
    aChar = lookahead
        ifFalse: [
            RxbtSyntaxError
                signal: ('unexpected character: ', (String with: lookahead))
                at: source position].
    ^source atEnd
        ifTrue:  [lookahead := nil]
        ifFalse: [lookahead := source next]
]

{ #category : 'parsing' }
RxbtCharSetParser >> parse [
    lookahead = $- ifTrue: [self addChar: $-. self match: $-].
    [lookahead isNil] whileFalse: [self parseStep].
    ^elements
]

{ #category : 'parsing' }
RxbtCharSetParser >> parseCharOrRange [
    | firstChar |
    firstChar := lookahead.
    self match: firstChar.
    lookahead = $-
        ifTrue: [
            self match: $-.
            ^lookahead
                ifNil: [self addChar: firstChar. self addChar: $-]
                ifNotNil: [
                    self addRangeFrom: firstChar to: lookahead.
                    self match: lookahead]].
    self addChar: firstChar
]

{ #category : 'parsing' }
RxbtCharSetParser >> parseEscapeChar [
    self match: $\.
    $- = lookahead
        ifTrue:  [elements add: (RxbtCharacter with: $-)]
        ifFalse: [elements add: (RxbtPredicate forEscapedLetter: lookahead)].
    self match: lookahead
]

{ #category : 'parsing' }
RxbtCharSetParser >> parseNamedSet [
    | name |
    self match: $[; match: $:.
    name := (String with: lookahead), (source upTo: $:).
    lookahead := source next.
    self match: $].
    elements add: (RxbtPredicate forNamedClass: name)
]

{ #category : 'parsing' }
RxbtCharSetParser >> parseStep [
    lookahead = $[ ifTrue: [
        ^source peek = $:
            ifTrue:  [self parseNamedSet]
            ifFalse: [self parseCharOrRange]].
    lookahead = $\ ifTrue: [^self parseEscapeChar].
    lookahead = $- ifTrue: [
        RxbtSyntaxError signal: 'invalid range' at: source position].
    self parseCharOrRange
]
