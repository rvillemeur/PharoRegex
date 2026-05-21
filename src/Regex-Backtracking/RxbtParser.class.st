"
Full regex parser for Regex-Backtracking. Completely independent of Regex-Core.
Produces an RxbtNode AST consumed by RxbtCompiler. Supports all features:
greedy/lazy/possessive quantifiers, backreferences \\1-\\9, atomic groups (?>...),
lookahead (?=...) (?!...), character classes, message predicates.
BackslashConstants: escape sequences (\\n \\t \\r etc.).
BackslashSpecials: \\w \\d \\s \\b etc. mapped to RxbtPredicate/RxbtContextCondition.
"
Class {
	#name : 'RxbtParser',
	#superclass : 'Object',
	#instVars : [
		'input',
		'lookahead'
	],
	#classVars : [
		'BackslashConstants',
		'BackslashSpecials'
	],
	#category : 'Regex-Backtracking-Base',
	#package : 'Regex-Backtracking',
	#tag : 'Base'
}

{ #category : 'initialize' }
RxbtParser class >> initialize [
    self initializeBackslashConstants.
    self initializeBackslashSpecials
]

{ #category : 'initialize' }
RxbtParser class >> initializeBackslashConstants [
    (BackslashConstants := Dictionary new)
        at: $e put: Character escape;
        at: $n put: Character lf;
        at: $r put: Character cr;
        at: $f put: Character newPage;
        at: $t put: Character tab
]

{ #category : 'initialization' }
RxbtParser class >> initializeBackslashSpecials [
    (BackslashSpecials := Dictionary new)
        at: $w put: (Association key: RxbtPredicate value: #beWordConstituent);
        at: $W put: (Association key: RxbtPredicate value: #beNotWordConstituent);
        at: $s put: (Association key: RxbtPredicate value: #beSpace);
        at: $S put: (Association key: RxbtPredicate value: #beNotSpace);
        at: $d put: (Association key: RxbtPredicate value: #beDigit);
        at: $D put: (Association key: RxbtPredicate value: #beNotDigit);
        at: $h put: (Association key: RxbtPredicate value: #beHorizontalWhitespace);
        at: $H put: (Association key: RxbtPredicate value: #beNotHorizontalWhitespace);
        at: $v put: (Association key: RxbtPredicate value: #beVerticalWhitespace);
        at: $V put: (Association key: RxbtPredicate value: #beNotVerticalWhitespace);
        at: $b put: (Association key: RxbtContextCondition value: #beWordBoundary);
        at: $B put: (Association key: RxbtContextCondition value: #beNonWordBoundary);
        at: $< put: (Association key: RxbtContextCondition value: #beBeginningOfWord);
        at: $> put: (Association key: RxbtContextCondition value: #beEndOfWord)
]

{ #category : 'instance creation' }
RxbtParser class >> parse: aString [
    ^self new parse: aString
]

{ #category : 'instance creation' }
RxbtParser class >> safelyParse: aString [
    ^[self new parse: aString] on: RxbtSyntaxError do: [:ex | nil]
]

{ #category : 'error handling' }
RxbtParser class >> signalSyntaxException: msg [
    RxbtSyntaxError new signal: msg
]

{ #category : 'error handling' }
RxbtParser class >> signalSyntaxException: msg at: pos [
    RxbtSyntaxError signal: msg at: pos
]

{ #category : 'parsing' }
RxbtParser >> atom [
    | atom |
    (lookahead = #epsilon
        or: [lookahead = $|
        or: [lookahead = $)
        or: [lookahead = $*
        or: [lookahead = $+
        or: [lookahead = $?]]]]]) ifTrue: [^RxbtEpsilon new].
    lookahead = $(
        ifTrue: [
            self match: $(.
            lookahead = $?
                ifTrue: [
                    self next.
                    lookahead = $>
                        ifTrue: [
                            self next.
                            atom := self regex.
                            self match: $).
                            ^RxbtAtomicGroup new inner: atom].
                    lookahead = $:
                        ifTrue: [
                            self next.
                            atom := self regex.
                            self match: $).
                            ^RxbtNonCapturingGroup new inner: atom].
                    lookahead = $<
                        ifTrue: [
                            self next.
                            (lookahead = $= or: [lookahead = $!])
                                ifTrue: [
                                    atom := self lookBehind.
                                    self match: $).
                                    ^atom].
                            atom := self namedCapture.
                            self match: $).
                            ^atom].
                    atom := self lookAround.
                    self match: $).
                    ^atom].
            atom := self regex.
            self match: $).
            ^atom].
    lookahead = $[
        ifTrue: [
            self match: $[.
            atom := self characterSet.
            self match: $].
            ^atom].
    lookahead = $:
        ifTrue: [
            self match: $:.
            atom := self messagePredicate.
            self match: $:.
            ^atom].
    lookahead = $. ifTrue: [self next. ^RxbtContextCondition new beAny].
    lookahead = $^ ifTrue: [self next. ^RxbtContextCondition new beBeginningOfLine].
    lookahead = $$ ifTrue: [self next. ^RxbtContextCondition new beEndOfLine].
    lookahead = $\
        ifTrue: [
            self next.
            lookahead = #epsilon ifTrue: [self signalParseError: 'bad quotation'].
            (BackslashConstants includesKey: lookahead)
                ifTrue: [
                    atom := RxbtCharacter with: (BackslashConstants at: lookahead).
                    self next.
                    ^atom].
            self ifSpecial: lookahead then: [:node | self next. ^node].
            lookahead = $A ifTrue: [self next. ^RxbtContextCondition new beBeginningOfString].
            lookahead = $z ifTrue: [self next. ^RxbtContextCondition new beEndOfString].
            lookahead = $Z ifTrue: [self next. ^RxbtContextCondition new beEndOfStringZ].
            lookahead = $R ifTrue: [self next. ^RxbtGenericNewline new].
            lookahead = $k ifTrue: [
                self next.
                lookahead = $< ifTrue: [
                    | refName |
                    self next.
                    refName := self inputUpToAny: '>' errorMessage: 'unterminated backreference name'.
                    self match: $>.
                    ^RxbtNamedBackreference new name: refName]].
            lookahead isDigit ifTrue: [
                | n |
                n := lookahead digitValue.
                n = 0 ifTrue: [self signalParseError: 'backreference index 0 is invalid'].
                self next.
                ^RxbtBackreference new groupIndex: n]].
    atom := RxbtCharacter with: lookahead.
    self next.
    ^atom
]

{ #category : 'parsing' }
RxbtParser >> branch [
    | piece branch |
    piece := self piece.
    (lookahead = #epsilon or: [lookahead = $| or: [lookahead = $)]])
        ifTrue:  [branch := nil]
        ifFalse: [branch := self branch].
    ^RxbtBranch new initializePiece: piece branch: branch
]

{ #category : 'parsing' }
RxbtParser >> characterSet [
    | spec err |
    err := ' no terminating "]"'.
    spec := self inputUpTo: $] nestedOn: $[ errorMessage: err.
    (spec isEmpty or: [spec = '^'])
        ifTrue: [
            self next.
            spec := spec, ']', (self inputUpTo: $] nestedOn: $[ errorMessage: err)].
    ^self characterSetFrom: spec
]

{ #category : 'parsing' }
RxbtParser >> characterSetFrom: setSpec [
    | negated spec |
    spec := ReadStream on: setSpec.
    spec peek = $^
        ifTrue:  [negated := true.  spec next]
        ifFalse: [negated := false].
    ^RxbtCharSet new
        initializeElements: (RxbtCharSetParser on: spec) parse
        negated: negated
]

{ #category : 'parsing' }
RxbtParser >> ifSpecial: aChar then: aBlock [
    | pair |
    pair := BackslashSpecials at: aChar ifAbsent: [^self].
    ^aBlock value: (pair key new perform: pair value)
]

{ #category : 'parsing' }
RxbtParser >> inputUpTo: aChar errorMessage: msg [
    | acc |
    acc := WriteStream on: (String new: 20).
    [lookahead ~= aChar and: [lookahead ~= #epsilon]] whileTrue: [
        acc nextPut: lookahead. self next].
    lookahead = #epsilon ifTrue: [self signalParseError: msg].
    ^acc contents
]

{ #category : 'parsing' }
RxbtParser >> inputUpTo: aChar nestedOn: nested errorMessage: msg [
    | acc level |
    acc := WriteStream on: (String new: 20).
    level := 0.
    [lookahead ~= aChar or: [level > 0]] whileTrue: [
        #epsilon = lookahead ifTrue: [self signalParseError: msg].
        acc nextPut: lookahead.
        lookahead = nested ifTrue: [level := level + 1].
        lookahead = aChar  ifTrue: [level := level - 1].
        self next].
    ^acc contents
]

{ #category : 'parsing' }
RxbtParser >> inputUpToAny: delimiters errorMessage: msg [
    | acc |
    acc := WriteStream on: (String new: 20).
    [(delimiters includes: lookahead) not and: [lookahead ~= #epsilon]] whileTrue: [
        acc nextPut: lookahead. self next].
    lookahead = #epsilon ifTrue: [self signalParseError: msg].
    ^acc contents
]

{ #category : 'parsing' }
RxbtParser >> lookAround [
    | lookaround |
    (lookahead = $! or: [lookahead = $=])
        ifFalse: [self signalParseError: ('Invalid lookaround expression ?', lookahead asString)].
    self next.
    lookaround := RxbtLookaround with: self regex.
    lookahead = $! ifTrue: [lookaround beNegative].
    ^lookaround
]

{ #category : 'parsing' }
RxbtParser >> lookBehind [
    | positive node |
    (lookahead = $= or: [lookahead = $!])
        ifFalse: [self signalParseError: 'invalid lookbehind — expected = or !'].
    positive := lookahead = $=.
    self next.
    node := RxbtLookbehind new inner: self regex.
    positive ifFalse: [node beNegative].
    ^node
]

{ #category : 'parsing' }
RxbtParser >> match: aChar [
    aChar ~= lookahead ifTrue: [^self signalParseError].
    self next
]

{ #category : 'parsing' }
RxbtParser >> messagePredicate [
    | spec negated |
    spec := self inputUpTo: $: errorMessage: ' no terminating ":"'.
    negated := false.
    spec first = $^
        ifTrue: [negated := true. spec := spec copyFrom: 2 to: spec size].
    ^RxbtMessagePredicate new initializeSelector: spec asSymbol negated: negated
]

{ #category : 'parsing' }
RxbtParser >> namedCapture [
    | capName inner |
    capName := self inputUpToAny: '>' errorMessage: 'unterminated group name'.
    self match: $>.
    inner := self regex.
    ^RxbtNamedCapture new name: capName inner: inner
]

{ #category : 'parsing' }
RxbtParser >> next [
    input atEnd
        ifTrue:  [lookahead := #epsilon]
        ifFalse: [lookahead := input next]
]

{ #category : 'parsing' }
RxbtParser >> parse: aString [
    ^self parseStream: (ReadStream on: aString)
]

{ #category : 'parsing' }
RxbtParser >> parseStream: aStream [
    | tree |
    input := aStream.
    lookahead := nil.
    self match: nil.
    tree := self regex.
    self match: #epsilon.
    ^tree
]

{ #category : 'parsing' }
RxbtParser >> piece [
    | atom lazy possessive |
    atom := self atom.
    lookahead = $*
        ifTrue: [
            self next.
            atom isNullable ifTrue: [self signalNullableClosureParserError].
            lazy := lookahead = $?. lazy ifTrue: [self next].
            possessive := lazy not and: [lookahead = $+]. possessive ifTrue: [self next].
            lazy       ifTrue: [^RxbtLazyPiece       new initializeStarAtom: atom].
            possessive ifTrue: [^RxbtPossessivePiece  new initializeStarAtom: atom].
            ^RxbtPiece new initializeStarAtom: atom].
    lookahead = $+
        ifTrue: [
            self next.
            atom isNullable ifTrue: [self signalNullableClosureParserError].
            lazy := lookahead = $?. lazy ifTrue: [self next].
            possessive := lazy not and: [lookahead = $+]. possessive ifTrue: [self next].
            lazy       ifTrue: [^RxbtLazyPiece       new initializePlusAtom: atom].
            possessive ifTrue: [^RxbtPossessivePiece  new initializePlusAtom: atom].
            ^RxbtPiece new initializePlusAtom: atom].
    lookahead = $?
        ifTrue: [
            self next.
            atom isNullable ifTrue: [^self lookAround].
            lazy := lookahead = $?. lazy ifTrue: [self next].
            possessive := lazy not and: [lookahead = $+]. possessive ifTrue: [self next].
            lazy       ifTrue: [^RxbtLazyPiece       new initializeOptionalAtom: atom].
            possessive ifTrue: [^RxbtPossessivePiece  new initializeOptionalAtom: atom].
            ^RxbtPiece new initializeOptionalAtom: atom].
    lookahead = ${ ifTrue: [^self quantifiedAtom: atom].
    ^RxbtPiece new initializeAtom: atom
]

{ #category : 'parsing' }
RxbtParser >> quantifiedAtom: atom [
    | min max lazy possessive |
    self next.
    lookahead = $,
        ifTrue: [min := 0]
        ifFalse: [max := min := (self inputUpToAny: '},}' errorMessage: ' no terminating "}"') asUnsignedInteger].
    lookahead = $,
        ifTrue: [
            self next.
            max := (self inputUpToAny: '},}' errorMessage: ' no terminating "}"') asUnsignedInteger].
    self match: $}.
    lazy := lookahead = $?. lazy ifTrue: [self next].
    possessive := lazy not and: [lookahead = $+]. possessive ifTrue: [self next].
    atom isNullable ifTrue: [self signalNullableClosureParserError].
    (max isNotNil and: [max < min]) ifTrue: [
        self signalParseError: ('wrong quantifier, expected ', min asString, ' <= ', max asString)].
    lazy       ifTrue: [^RxbtLazyPiece      new initializeAtom: atom min: min max: max].
    possessive ifTrue: [^RxbtPossessivePiece new initializeAtom: atom min: min max: max].
    ^RxbtPiece new initializeAtom: atom min: min max: max
]

{ #category : 'parsing' }
RxbtParser >> regex [
    | branch regex |
    branch := self branch.
    (lookahead = #epsilon or: [lookahead = $)])
        ifTrue:  [regex := nil]
        ifFalse: [self match: $|. regex := self regex].
    ^RxbtRegex new initializeBranch: branch regex: regex
]

{ #category : 'error handling' }
RxbtParser >> signalNullableClosureParserError [
    self signalParseError: ' nullable closure'
]

{ #category : 'error handling' }
RxbtParser >> signalParseError [
    self class signalSyntaxException: 'Regex syntax error' at: input position
]

{ #category : 'error handling' }
RxbtParser >> signalParseError: msg [
    self class signalSyntaxException: msg at: input position
]
