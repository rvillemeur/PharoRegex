Class {
	#name : 'RxbtNonCapturingTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests',
	#package : 'Regex-Backtracking-Tests'
}

{ #category : 'tests' }
RxbtNonCapturingTest >> testBasicNonCapturing [
    | m |
    m := RxbtMatcher forString: '(?:cat|dog)s'.
    self assert: (m matches: 'cats').
    self assert: (m matches: 'dogs').
    self deny:   (m matches: 'birds').
    self assert: m subexpressionCount = 1
]

{ #category : 'tests' }
RxbtNonCapturingTest >> testNestedCaptureInsideNonCapturing [
    | m |
    m := RxbtMatcher forString: '(?:(a)|(b))'.
    m search: 'b'.
    self assert: (m subexpression: 2) isNil.
    self assert: (m subexpression: 3) = 'b'
]

{ #category : 'tests' }
RxbtNonCapturingTest >> testNonCapturingVsCapturing [
    | nc c |
    nc := RxbtMatcher forString: '(?:a)(b)'.
    c  := RxbtMatcher forString: '(a)(b)'.
    nc search: 'ab'. c search: 'ab'.
    self assert: nc subexpressionCount = 2.
    self assert: c  subexpressionCount = 3.
    self assert: (nc subexpression: 2) = 'b'.
    self assert: (c  subexpression: 2) = 'a'
]

{ #category : 'tests' }
RxbtNonCapturingTest >> testNonCapturingWithQuantifier [
    | m |
    m := RxbtMatcher forString: '(?:ab)+'.
    self assert: (m matches: 'ab').
    self assert: (m matches: 'ababab').
    self deny:   (m matches: 'a')
]
