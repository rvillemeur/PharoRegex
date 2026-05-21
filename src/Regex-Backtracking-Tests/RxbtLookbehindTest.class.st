Class {
	#name : 'RxbtLookbehindTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtLookbehindTest >> testLookbehindAtStart [
    | m |
    m := RxbtMatcher forString: '(?<=a)b'.
    self deny: (m search: 'b')
]

{ #category : 'tests' }
RxbtLookbehindTest >> testLookbehindZeroWidth [
    | m |
    m := RxbtMatcher forString: '(?<=\d)px'.
    m search: '12px'.
    self assert: (m subexpression: 1) = 'px'
]

{ #category : 'tests' }
RxbtLookbehindTest >> testNegativeLookbehind [
    | m |
    m := RxbtMatcher forString: '(?<!foo)bar'.
    self deny:   (m search: 'foobar').
    self assert: (m search: 'xyzbar')
]

{ #category : 'tests' }
RxbtLookbehindTest >> testNegativeLookbehindAtStart [
    | m |
    m := RxbtMatcher forString: '(?<!a)b'.
    self assert: (m search: 'b')
]

{ #category : 'tests' }
RxbtLookbehindTest >> testPositiveLookbehind [
    | m |
    m := RxbtMatcher forString: '(?<=foo)bar'.
    self assert: (m search: 'foobar').
    self deny:   (m search: 'xyzbar')
]

{ #category : 'tests' }
RxbtLookbehindTest >> testVariableLengthLookbehind [
    | m |
    m := RxbtMatcher forString: '(?<=a+)b'.
    self assert: (m search: 'aaab').
    self deny:   (m search: 'b')
]
