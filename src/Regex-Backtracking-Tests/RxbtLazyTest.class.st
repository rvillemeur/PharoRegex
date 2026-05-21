"
Tests for lazy (non-greedy) quantifiers in RxbtMatcher: *?, +?, ??, {n,m}?. Each test verifies that lazy quantifiers take fewest possible characters and yield correct subexpression captures.
"
Class {
	#name : 'RxbtLazyTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests',
	#package : 'Regex-Backtracking-Tests'
}

{ #category : 'private' }
RxbtLazyTest >> matchFirst: pattern in: string [
    "Return the whole-match string for the first occurrence, or nil if no match."
    | m |
    m := RxbtMatcher forString: pattern.
    (m search: string) ifFalse: [ ^nil ].
    ^m subexpression: 1
]

{ #category : 'tests' }
RxbtLazyTest >> testLazyNested [
    "Lazy .*? stops at first closing tag."
    | m |
    m := RxbtMatcher forString: '<[^>]+>.*?</[^>]+>'.
    self assert: (m search: '<b>hello</b> world <i>there</i>').
    self assert: (m subexpression: 1) = '<b>hello</b>'
]

{ #category : 'tests' }
RxbtLazyTest >> testLazyOptional [
    "a?? tries zero first, then one."
    | m |
    m := RxbtMatcher forString: 'a??b'.
    self assert: (m matches: 'b').
    self assert: (m matches: 'ab')
]

{ #category : 'tests' }
RxbtLazyTest >> testLazyPlus [
    ".+? takes exactly one character when possible."
    self assert: (self matchFirst: '.+?' in: 'abc') = 'a'.
    self assert: (self matchFirst: 'a.+?b' in: 'aXYb') = 'aXYb'
]

{ #category : 'tests' }
RxbtLazyTest >> testLazyQuantifiedAtom [
    "a{2,4}? takes the minimum (2) when the rest matches."
    | m |
    m := RxbtMatcher forString: 'a{2,4}?b'.
    self assert: (m matches: 'aab').
    self assert: (m matches: 'aaab').
    self deny:   (m matches: 'b')
]

{ #category : 'tests' }
RxbtLazyTest >> testLazyStar [
    ".*? takes as few characters as possible."
    self assert: (self matchFirst: '.*?' in: 'abc') = ''.
    self assert: (self matchFirst: 'a.*?b' in: 'aXbYb') = 'aXb'
]

{ #category : 'tests' }
RxbtLazyTest >> testLazyVsGreedy [
    "Greedy .+ takes entire <a><b>; lazy .+? stops at first >."
    | greedy lazy |
    greedy := RxbtMatcher forString: '<.+>'.
    lazy   := RxbtMatcher forString: '<.+?>'.
    greedy search: '<a><b>'.
    self assert: (greedy subexpression: 1) = '<a><b>'.
    lazy search: '<a><b>'.
    self assert: (lazy subexpression: 1) = '<a>'
]
