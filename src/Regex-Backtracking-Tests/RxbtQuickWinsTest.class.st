Class {
	#name : 'RxbtQuickWinsTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtQuickWinsTest >> testInlineCommentAtStart [
    | m |
    m := RxbtMatcher forString: '(?#skip)\d+'.
    self assert: (m search: 'abc123').
    self assert: (m subexpression: 1) equals: '123'
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testInlineCommentIgnored [
    | m |
    m := RxbtMatcher forString: 'foo(?#comment)bar'.
    self assert: (m matches: 'foobar')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testInlineCommentInAlternation [
    | m |
    m := RxbtMatcher forString: 'foo(?#note)|baz'.
    self assert: (m search: 'baz')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testKeepStartBasic [
    | m |
    m := RxbtMatcher forString: 'foo\Kbar'.
    self assert: (m search: 'foobar').
    self assert: (m subexpression: 1) equals: 'bar'
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testKeepStartNoMatch [
    | m |
    m := RxbtMatcher forString: 'foo\Kbar'.
    self deny: (m search: 'foobaz')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testKeepStartWithSearch [
    "Fixed prefix before \K — reports only the part after \K."
    | m |
    m := RxbtMatcher forString: 'prefix_\K\w+'.
    self assert: (m search: 'prefix_hello').
    self assert: (m subexpression: 1) equals: 'hello'
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testPosixAlpha [
    | m |
    m := RxbtMatcher forString: '[[:alpha:]]+'.
    self assert: (m matches: 'hello').
    self deny:   (m matches: '123')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testPosixBlank [
    | m |
    m := RxbtMatcher forString: '[[:blank:]]+'.
    self assert: (m matches: ' ').
    self assert: (m matches: (String with: (Character value: 9))).
    self deny:   (m matches: 'a')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testPosixDigit [
    | m |
    m := RxbtMatcher forString: '[[:digit:]]+'.
    self assert: (m matches: '42').
    self deny:   (m matches: 'abc')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testPosixMixedWithLiteral [
    | m |
    m := RxbtMatcher forString: '[[:alpha:]0-9]+'.
    self assert: (m matches: 'abc123')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testPosixNegated [
    | m |
    m := RxbtMatcher forString: '[^[:digit:]]+'.
    self assert: (m matches: 'abc').
    self deny:   (m matches: '123')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testPosixWord [
    | m |
    m := RxbtMatcher forString: '[[:word:]]+'.
    self assert: (m matches: 'hello_42').
    self deny:   (m matches: '!!')
]

{ #category : 'tests' }
RxbtQuickWinsTest >> testRegressionFull [
    | r |
    r := (Smalltalk at: #RxbtMatcherTest) suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty
]
