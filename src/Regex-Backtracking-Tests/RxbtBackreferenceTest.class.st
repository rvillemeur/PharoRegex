"
Tests for backreferences in RxbtMatcher. Verifies that \1..\9 match the text captured by the corresponding explicit group, including alternation, case-insensitive, and unmatched-group cases.
"
Class {
	#name : 'RxbtBackreferenceTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtBackreferenceTest >> testBackreferenceBeforeGroup [
    "Backreference to group not yet matched returns false."
    | m |
    m := RxbtMatcher forString: '\1(a)'.
    self deny: (m matches: 'aa')
]

{ #category : 'tests' }
RxbtBackreferenceTest >> testBackreferenceWithAlternation [
    | m |
    m := RxbtMatcher forString: '(cat|dog)\1'.
    self assert: (m matches: 'catcat').
    self assert: (m matches: 'dogdog').
    self deny:   (m matches: 'catdog').
    self deny:   (m matches: 'dogcat')
]

{ #category : 'tests' }
RxbtBackreferenceTest >> testBackreferenceWithQuantifier [
    "Group with quantifier: backref matches final captured text."
    | m |
    m := RxbtMatcher forString: '(a+)\1'.
    self assert: (m matches: 'aaaa').
    self deny:   (m matches: 'aaa').
    self assert: (m matches: 'aa')
]

{ #category : 'tests' }
RxbtBackreferenceTest >> testCaseInsensitiveBackreference [
    | m |
    m := RxbtMatcher forString: '(Hello)\s+\1' ignoreCase: true.
    self assert: (m matches: 'Hello hello').
    self assert: (m matches: 'HELLO hello')
]

{ #category : 'tests' }
RxbtBackreferenceTest >> testDoubledWord [
    | m |
    m := RxbtMatcher forString: '\b(\w+)\s+\1\b'.
    self assert: (m search: 'the the quick fox').
    self assert: (m subexpression: 1) = 'the the'.
    self assert: (m subexpression: 2) = 'the'.
    self deny: (m search: 'the quick brown fox')
]

{ #category : 'tests' }
RxbtBackreferenceTest >> testMultipleBackreferences [
    | m |
    m := RxbtMatcher forString: '(a)(b)\2\1'.
    self assert: (m matches: 'abba').
    self deny:   (m matches: 'abab')
]

{ #category : 'tests' }
RxbtBackreferenceTest >> testOutOfRangeBackreference [
    "Backreference to group that does not exist in the pattern returns false, not an error."
    | m |
    m := RxbtMatcher forString: '(a)\5'.
    self deny: (m matches: 'aa')
]

{ #category : 'tests' }
RxbtBackreferenceTest >> testSimpleBackreference [
    self assert: ((RxbtMatcher forString: '(a+)\1') matches: 'aaaa').
    self deny:   ((RxbtMatcher forString: '(a+)\1') matches: 'aaa').
    self assert: ((RxbtMatcher forString: '(a+)\1') matches: 'aa')
]
