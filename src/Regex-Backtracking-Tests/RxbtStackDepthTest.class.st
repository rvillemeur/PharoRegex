Class {
	#name : 'RxbtStackDepthTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtStackDepthTest >> testBoundedRepeatMinMax [
    | m |
    m := RxbtMatcher forString: 'a{2,4}'.
    self assert: (m matches: 'aa').
    self assert: (m matches: 'aaaa').
    self deny:   (m matches: 'a').
    self deny:   (m matches: 'aaaaa')
]

{ #category : 'tests' }
RxbtStackDepthTest >> testGreedyBacktrack [
    | m |
    m := RxbtMatcher forString: 'a*b'.
    self assert: (m matches: 'aaab').
    self assert: (m matches: 'b').
    self deny:   (m matches: 'aaa')
]

{ #category : 'tests' }
RxbtStackDepthTest >> testLazyBacktrack [
    | m |
    m := RxbtMatcher forString: 'a*?b'.
    self assert: (m search: 'aaab').
    self assert: (m subexpression: 1) = 'aaab'
]

{ #category : 'tests' }
RxbtStackDepthTest >> testLongBoundedRepeat [
    | input m |
    input := String new: 5000 withAll: $a.
    m := RxbtMatcher forString: 'a{1,5000}'.
    self assert: (m matches: input)
]

{ #category : 'tests' }
RxbtStackDepthTest >> testLongGreedyPlus [
    | input m |
    input := String new: 5000 withAll: $b.
    m := RxbtMatcher forString: 'b+'.
    self assert: (m matches: input)
]

{ #category : 'tests' }
RxbtStackDepthTest >> testLongGreedyStar [
    | input m |
    input := String new: 5000 withAll: $a.
    m := RxbtMatcher forString: 'a*'.
    self assert: (m matches: input)
]

{ #category : 'tests' }
RxbtStackDepthTest >> testLongLazyStar [
    | input m |
    input := String new: 5000 withAll: $c.
    m := RxbtMatcher forString: 'c*?c'.
    self assert: (m search: input)
]

{ #category : 'tests' }
RxbtStackDepthTest >> testRegressionFull [
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty
]
