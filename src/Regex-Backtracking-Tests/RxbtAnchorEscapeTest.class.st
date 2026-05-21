Class {
	#name : 'RxbtAnchorEscapeTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testAbsoluteEndStrict [
    | m |
    m := RxbtMatcher forString: 'foo\z'.
    self assert: (m matches: 'foo').
    self deny:   (m matches: 'foo' , (String with: (Character value: 10)))
]

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testAbsoluteEndZ [
    | m |
    m := RxbtMatcher forString: 'foo\Z'.
    self assert: (m matches: 'foo').
    self assert: (m matches: 'foo' , (String with: (Character value: 10))).
    self deny:   (m matches: 'foobar')
]

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testAbsoluteStart [
    | m |
    m := RxbtMatcher forString: '\Afoo'.
    self assert: (m search: 'foobar').
    self deny:   (m search: 'barfoo')
]

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testGenericNewlineCRLF [
    | m crlf |
    crlf := String with: (Character value: 13) with: (Character value: 10).
    m := RxbtMatcher forString: '\R'.
    self assert: (m matches: crlf).
    self assert: (m subexpression: 1) = crlf
]

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testGenericNewlineSingle [
    | m |
    m := RxbtMatcher forString: '\R'.
    self assert: (m matches: (String with: (Character value: 10))).
    self assert: (m matches: (String with: (Character value: 13)))
]

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testHorizontalWhitespace [
    | m |
    m := RxbtMatcher forString: '\h+'.
    self assert: (m matches: ' ').
    self assert: (m matches: (String with: (Character value: 9))).
    self deny:   (m matches: (String with: (Character value: 10)))
]

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testNotVertical [
    | m |
    m := RxbtMatcher forString: '\V+'.
    self assert: (m matches: 'hello world').
    self deny:   (m search: (String with: (Character value: 10)))
]

{ #category : 'tests' }
RxbtAnchorEscapeTest >> testVerticalWhitespace [
    | m |
    m := RxbtMatcher forString: '\v'.
    self assert: (m matches: (String with: (Character value: 10))).
    self assert: (m matches: (String with: (Character value: 13))).
    self deny:   (m matches: ' ')
]
