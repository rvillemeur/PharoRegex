"
Character-class predicate node. predicate is a [:char | Boolean] block; negation is its inverse. Class-side NamedClassSelectors and EscapedLetterSelectors dictionaries map names/letters to initialisation selectors.
"
Class {
	#name : 'RxbtPredicate',
	#superclass : 'RxbtNode',
	#instVars : [
		'predicate',
		'negation'
	],
	#classVars : [
		'EscapedLetterSelectors',
		'NamedClassSelectors'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'instance creation' }
RxbtPredicate class >> forEscapedLetter: aChar [
    ^self new perform:
        (EscapedLetterSelectors
            at: aChar
            ifAbsent: [RxbtSyntaxError new signal: 'bad backslash escape'])
]

{ #category : 'instance creation' }
RxbtPredicate class >> forNamedClass: aString [
    ^self new perform:
        (NamedClassSelectors
            at: aString
            ifAbsent: [RxbtSyntaxError new signal: 'bad character class name'])
]

{ #category : 'initialize' }
RxbtPredicate class >> initialize [
    self initializeNamedClassSelectors.
    self initializeEscapedLetterSelectors
]

{ #category : 'initialize' }
RxbtPredicate class >> initializeEscapedLetterSelectors [
    (EscapedLetterSelectors := Dictionary new)
        at: $w put: #beWordConstituent;
        at: $W put: #beNotWordConstituent;
        at: $d put: #beDigit;
        at: $D put: #beNotDigit;
        at: $s put: #beSpace;
        at: $S put: #beNotSpace;
        at: $\ put: #beBackslash
]

{ #category : 'initialize' }
RxbtPredicate class >> initializeNamedClassSelectors [
    (NamedClassSelectors := Dictionary new)
        at: 'alnum' put: #beAlphaNumeric;
        at: 'alpha' put: #beAlphabetic;
        at: 'cntrl' put: #beControl;
        at: 'digit' put: #beDigit;
        at: 'graph' put: #beGraphics;
        at: 'lower' put: #beLowercase;
        at: 'print' put: #bePrintable;
        at: 'punct' put: #bePunctuation;
        at: 'space' put: #beSpace;
        at: 'upper' put: #beUppercase;
        at: 'xdigit' put: #beHexDigit
]

{ #category : 'initialize' }
RxbtPredicate >> beAlphaNumeric [
    predicate := [:c | c isAlphaNumeric].
    negation  := [:c | c isAlphaNumeric not]
]

{ #category : 'initialize' }
RxbtPredicate >> beAlphabetic [
    predicate := [:c | c isLetter].
    negation  := [:c | c isLetter not]
]

{ #category : 'initialize' }
RxbtPredicate >> beBackslash [
    predicate := [:c | c == $\].
    negation  := [:c | c ~~ $\]
]

{ #category : 'initialize' }
RxbtPredicate >> beControl [
    predicate := [:c | c asInteger < 32].
    negation  := [:c | c asInteger >= 32]
]

{ #category : 'initialize' }
RxbtPredicate >> beDigit [
    predicate := [:c | c isDigit].
    negation  := [:c | c isDigit not]
]

{ #category : 'initialize' }
RxbtPredicate >> beGraphics [ self beControl; negate
]

{ #category : 'initialize' }
RxbtPredicate >> beHexDigit [
    | hex |
    hex := 'abcdefABCDEF'.
    predicate := [:c | c isDigit or: [hex includes: c]].
    negation  := [:c | c isDigit not and: [(hex includes: c) not]]
]

{ #category : 'initialize' }
RxbtPredicate >> beLowercase [
    predicate := [:c | c isLowercase].
    negation  := [:c | c isLowercase not]
]

{ #category : 'initialize' }
RxbtPredicate >> beNotDigit [ self beDigit; negate
]

{ #category : 'initialize' }
RxbtPredicate >> beNotSpace [ self beSpace; negate
]

{ #category : 'initialize' }
RxbtPredicate >> beNotWordConstituent [ self beWordConstituent; negate
]

{ #category : 'initialize' }
RxbtPredicate >> bePrintable [ self beControl; negate
]

{ #category : 'initialize' }
RxbtPredicate >> bePunctuation [
    | p |
    p := #($. $, $! $? $; $: $" $' $- $( $) $`).
    predicate := [:c | p includes: c].
    negation  := [:c | (p includes: c) not]
]

{ #category : 'initialize' }
RxbtPredicate >> beSpace [
    predicate := [:c | c isSeparator].
    negation  := [:c | c isSeparator not]
]

{ #category : 'initialize' }
RxbtPredicate >> beUppercase [
    predicate := [:c | c isUppercase].
    negation  := [:c | c isUppercase not]
]

{ #category : 'initialize' }
RxbtPredicate >> beWordConstituent [
    predicate := [:c | c isAlphaNumeric or: [c == $_]].
    negation  := [:c | c isAlphaNumeric not and: [c ~~ $_]]
]

{ #category : 'double dispatch' }
RxbtPredicate >> dispatchTo: anObject [ ^anObject syntaxPredicate: self
]

{ #category : 'testing' }
RxbtPredicate >> isEnumerable [ ^false
]

{ #category : 'operations' }
RxbtPredicate >> negate [
    | tmp |
    tmp := predicate. predicate := negation. negation := tmp
]

{ #category : 'accessing' }
RxbtPredicate >> negated [ ^self copy negate
]

{ #category : 'accessing' }
RxbtPredicate >> predicate [ ^predicate
]

{ #category : 'accessing' }
RxbtPredicate >> predicateNegation [ ^negation
]

{ #category : 'evaluating' }
RxbtPredicate >> value: aChar [ ^predicate value: aChar
]
