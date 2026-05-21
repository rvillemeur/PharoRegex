"
Tests for named capture groups (?<name>...) and named
backreferences \k<name> in RxbtMatcher.
"
Class {
	#name : 'RxbtNamedCaptureTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests',
	#package : 'Regex-Backtracking-Tests'
}

{ #category : 'tests' }
RxbtNamedCaptureTest >> testBasicNamedCapture [
    | m |
    m := RxbtMatcher forString: '(?<year>\d{4})-(?<month>\d{2})'.
    self assert: (m search: '2024-03').
    self assert: (m subexpressionNamed: 'year')  = '2024'.
    self assert: (m subexpressionNamed: 'month') = '03'
]

{ #category : 'tests' }
RxbtNamedCaptureTest >> testNamedBackreference [
    | m |
    m := RxbtMatcher forString: '(?<w>\w+)\s+\k<w>'.
    self assert: (m search: 'hello hello').
    self assert: (m subexpressionNamed: 'w') = 'hello'.
    self deny:   (m search: 'hello world')
]

{ #category : 'tests' }
RxbtNamedCaptureTest >> testNamedCaptureGroupNumber [
    | m |
    m := RxbtMatcher forString: '(?<word>\w+)'.
    m search: 'hello'.
    self assert: (m subexpression: 2) = 'hello'.
    self assert: (m subexpressionNamed: 'word') = 'hello'
]

{ #category : 'tests' }
RxbtNamedCaptureTest >> testNamedVsNumbered [
    | m |
    m := RxbtMatcher forString: '(\d+)-(?<tag>[a-z]+)'.
    m search: '42-abc'.
    self assert: (m subexpression: 2) = '42'.
    self assert: (m subexpressionNamed: 'tag') = 'abc'
]

{ #category : 'tests' }
RxbtNamedCaptureTest >> testSubexpressionNames [
    | m |
    m := RxbtMatcher forString: '(?<a>\w)(?<b>\d)'.
    self assert: (m subexpressionNames asSortedCollection asArray) = #('a' 'b')
]

{ #category : 'tests' }
RxbtNamedCaptureTest >> testUnknownName [
    | m |
    m := RxbtMatcher forString: '(?<x>\w+)'.
    m search: 'hi'.
    self assert: (m subexpressionNamed: 'missing') isNil
]
