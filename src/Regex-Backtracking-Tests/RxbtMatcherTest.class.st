Class {
	#name : 'RxbtMatcherTest',
	#superclass : 'RxMatcherTest',
	#category : 'Regex-Backtracking-Tests',
	#package : 'Regex-Backtracking-Tests'
}

{ #category : 'testing' }
RxbtMatcherTest class >> shouldInheritSelectors [
    "Inherit all RxMatcherTest tests plus our overrides."
    ^true
]

{ #category : 'accessing' }
RxbtMatcherTest >> matcherClass [ ^RxbtMatcher
]

{ #category : 'tests' }
RxbtMatcherTest >> testHenry087 [
    "In RxbtMatcher, a*? is a valid lazy star, not a parse error."
    self runRegex: #('a*?' '' true nil 'aaa' true nil)
]
