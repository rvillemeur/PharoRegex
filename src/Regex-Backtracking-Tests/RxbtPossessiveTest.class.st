"
Tests for possessive quantifiers (*+, ++, ?+, {n,m}+) and atomic groups (?>...) in RxbtMatcher. Possessive quantifiers match greedily and never give back characters; atomic groups commit to the greedy match and do not retry on continuation failure.
"
Class {
	#name : 'RxbtPossessiveTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtPossessiveTest >> testAtomicGroup [
    self deny:   ((RxbtMatcher forString: '(?>a+)a') matches: 'aaa').
    self assert: ((RxbtMatcher forString: '(?>a+)b') matches: 'aaab')
]

{ #category : 'tests' }
RxbtPossessiveTest >> testAtomicGroupVsNormal [
    "(a+)a backtracks; (?>a+)a does not."
    self assert: ((RxbtMatcher forString: '(a+)a')   matches: 'aaa').
    self deny:   ((RxbtMatcher forString: '(?>a+)a') matches: 'aaa')
]

{ #category : 'tests' }
RxbtPossessiveTest >> testPossessiveOptional [
    "a?+a: possessive optional takes a, then second a fails."
    self deny:   ((RxbtMatcher forString: 'a?+a') matches: 'a').
    self assert: ((RxbtMatcher forString: 'a?+b') matches: 'ab').
    self assert: ((RxbtMatcher forString: 'a?+b') matches: 'b')
]

{ #category : 'tests' }
RxbtPossessiveTest >> testPossessivePerformance [
    "Possessive prevents catastrophic backtracking on long input with no match."
    | m |
    m := RxbtMatcher forString: 'a*+b'.
    self deny: (m matches: (String new: 100 withAll: $a))
]

{ #category : 'tests' }
RxbtPossessiveTest >> testPossessivePlus [
    self deny:   ((RxbtMatcher forString: 'a++a') matches: 'aaa').
    self assert: ((RxbtMatcher forString: 'a++b') matches: 'aaab')
]

{ #category : 'tests' }
RxbtPossessiveTest >> testPossessiveStar [
    "a*+a takes all a-s, then second a fails — no backtrack."
    self deny:   ((RxbtMatcher forString: 'a*+a') matches: 'aaa').
    self assert: ((RxbtMatcher forString: 'a*a')  matches: 'aaa')
]
