Class {
	#name : 'RxbtOptimizerTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtOptimizerTest >> testAlternationPrefixes [
    | m |
    m := RxbtMatcher forString: 'cat|dog'.
    self assert: (m search: 'I have a dog').
    self assert: (m search: 'the cat sat').
    self deny:   (m search: 'no pets here')
]

{ #category : 'tests' }
RxbtOptimizerTest >> testAnchoredPattern [
    | m |
    m := RxbtMatcher forString: '^hello'.
    self assert: (m search: 'hello world').
    self deny:   (m search: 'say hello')
]

{ #category : 'tests' }
RxbtOptimizerTest >> testCharSetPrefix [
    | m |
    m := RxbtMatcher forString: '[\de]+'.
    self assert: (m search: 'zzz01234').
    self assert: (m subexpression: 1) = '01234'
]

{ #category : 'tests' }
RxbtOptimizerTest >> testLiteralPrefixSkip [
    | m |
    m := RxbtMatcher forString: 'foo'.
    self assert: (m search: 'xxxfooyyy').
    self assert: (m subexpression: 1) = 'foo'
]

{ #category : 'tests' }
RxbtOptimizerTest >> testNullableHead [
    | m |
    m := RxbtMatcher forString: 'a*b'.
    self assert: (m search: 'xxxb').
    self assert: (m search: 'aaab')
]

{ #category : 'tests' }
RxbtOptimizerTest >> testOptimizerRegressionFull [
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty
]

{ #category : 'tests' }
RxbtOptimizerTest >> testPredicatePrefix [
    | m |
    m := RxbtMatcher forString: '\d+'.
    self assert: (m search: 'abc123def').
    self assert: (m subexpression: 1) = '123'
]
