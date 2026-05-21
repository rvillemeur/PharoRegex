Class {
	#name : 'RxbtBacktrackingGuardTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testCatastrophicPattern [
    | m |
    m := RxbtMatcher forString: '(a+)+b'.
    m stepLimit: 10000.
    self should: [m search: (String new: 15 withAll: $a)] raise: RxbtMatchingError
]

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testCustomLimit [
    | m |
    m := RxbtMatcher forString: '(a+)+b'.
    m stepLimit: 500.
    self should: [m search: 'aaaaaaa'] raise: RxbtMatchingError.
    m stepLimit: 1000000.
    self shouldnt: [m search: 'ab'] raise: RxbtMatchingError
]

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testErrorMessageContent [
    | m ex |
    m := RxbtMatcher forString: '(a+)+b'.
    m stepLimit: 100.
    ex := nil.
    [m search: 'aaaaaaaaaa'] on: RxbtMatchingError do: [:e | ex := e].
    self assert: ex notNil.
    self assert: (ex messageText includesSubstring: '100')
]

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testExponentialAlternation [
    "((a+)) double-nested quantifier — still O(n^2) steps with iterative helpers."
    | m |
    m := RxbtMatcher forString: '((a+))+b'.
    m stepLimit: 10000.
    self should: [m search: (String new: 15 withAll: $a)] raise: RxbtMatchingError
]

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testLongButLinearPattern [
    | m input |
    input := String new: 5000 withAll: $a.
    m := RxbtMatcher forString: 'a*'.
    m stepLimit: 1000000.
    self assert: (m matches: input)
]

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testNormalPatternUnaffected [
    | m |
    m := RxbtMatcher forString: 'foo'.
    m stepLimit: 10000.
    self assert: (m search: 'xxxfooyyy')
]

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testRegressionFull [
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty
]

{ #category : 'tests' }
RxbtBacktrackingGuardTest >> testStepCountResetBetweenSearches [
    | m |
    m := RxbtMatcher forString: 'a+'.
    m stepLimit: 1000.
    self assert: (m search: 'aaa').
    self assert: (m search: 'aaa')
]
