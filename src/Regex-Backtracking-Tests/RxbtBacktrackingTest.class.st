"
Validates that RxbtMatcher implements true backtracking semantics.

Each test exercises a pattern requiring the engine to abandon a partial match
and retry with a different path — the core property of a backtracking engine.

Note: Pharo's built-in RxMatcher (greedy NFA) handles most standard patterns
correctly. Patterns that truly require features beyond standard NFA — lazy
quantifiers, backreferences, possessive quantifiers — are tested in
RxbtLazyTest, RxbtBackreferenceTest, and RxbtPossessiveTest respectively.

Run with: RxbtBacktrackingTest suite run
"
Class {
	#name : 'RxbtBacktrackingTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests',
	#package : 'Regex-Backtracking-Tests'
}

{ #category : 'helpers' }
RxbtBacktrackingTest >> assertPattern: pattern doesNotMatch: string [
	self
		deny: ((self matcherFor: pattern) search: string)
		description: pattern , ' should NOT match ' , string
]

{ #category : 'helpers' }
RxbtBacktrackingTest >> assertPattern: pattern matches: string [
	self
		assert: ((self matcherFor: pattern) search: string)
		description: pattern , ' should match ' , string
]

{ #category : 'helpers' }
RxbtBacktrackingTest >> assertPattern: pattern matches: string groups: expected [
	| m |
	m := self matcherFor: pattern.
	self assert: (m search: string) description: pattern , ' should match ' , string.
	1 to: expected size // 2 do: [ :i |
		| idx val |
		idx := expected at: 2 * i - 1.
		val := expected at: 2 * i.
		self
			assert: (m subexpression: idx) = val
			description: 'Group ' , idx printString , ' of ' , pattern]
]

{ #category : 'helpers' }
RxbtBacktrackingTest >> assertRxMatcherFails: pattern on: string [
	"Documents cases where RxbtMatcher surpasses RxMatcher (lazy, backrefs, possessive)."
	self
		deny: ((RxMatcher forString: pattern) search: string)
		description: 'RxMatcher should fail on ' , pattern , ' / ' , string
]

{ #category : 'helpers' }
RxbtBacktrackingTest >> matcherFor: pattern [
	^RxbtMatcher forString: pattern
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testAlternationBacktrack [
	"(a|ab)c on abc: first alt a matches, but continuation c fails at pos 2.
	Engine must backtrack and try second alt ab, then c succeeds."
	self assertPattern: '(a|ab)c' matches: 'abc' groups: #(2 'ab')
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testAlternationBacktrackLongerString [
	"Same pattern embedded in longer string to exercise search."
	self assertPattern: '(a|ab)c' matches: 'xx abc yy' groups: #(2 'ab')
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testCatastrophicPatternTerminates [
	"(a+)+b must fail on aaaa without exponential blowup, and succeed on aaab."
	self assertPattern: '(a+)+b' doesNotMatch: 'aaaa'.
	self assertPattern: '(a+)+b' matches: 'aaab'
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testGreedyStarBacktrack [
	"(a*)a on aaa: greedy a* takes all three, then a fails.
	Backtracks: a* gives up one, literal a matches last."
	self assertPattern: '(a*)a' matches: 'aaa' groups: #(2 'aa')
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testNestedQuantifierBacktrack [
	"(a+)(a+) on aaaa: first a+ greedy takes all 4, second a+ fails.
	Backtracks until first a+=aaa, second a+=a."
	self assertPattern: '(a+)(a+)' matches: 'aaaa' groups: #(2 'aaa' 3 'a')
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testOptionalBacktrack [
	"a?ab on ab: greedy a? takes the a, then a fails (sees b).
	Backtracks: a? matches empty, then a matches, then b matches."
	self assertPattern: 'a?ab' matches: 'ab'.
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testOverlappingAlternatives [
	"(a|aa)(a|aa)b on aaab: backtracks until second group takes aa."
	self assertPattern: '(a|aa)(a|aa)b' matches: 'aaab' groups: #(2 'a' 3 'aa')
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testQuantifierBacktrackOnContinuation [
	"x*xy on xxxy: greedy x* takes all three x chars, then x fails.
	Backtracks until x*=xx, literal x matches, then y matches."
	self assertPattern: 'x*xy' matches: 'xxxy'.
	self assertPattern: 'x*xy' doesNotMatch: 'xxxx'
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testRegressionAllOriginalTestsPass [
	"Ensure Phase 1 compatibility is intact."
	| result |
	result := RxbtMatcherTest suite run.
	self assert: result failures isEmpty
		description: 'Phase 1 regressions detected'.
	self assert: result errors isEmpty
		description: 'Phase 1 errors detected'
]

{ #category : 'tests' }
RxbtBacktrackingTest >> testThreeQuantifiersBacktrack [
	"(a+)(a+)(a+) on aaaaaa: backtracking distributes chars across all three groups."
	| m |
	m := self matcherFor: '(a+)(a+)(a+)'.
	m search: 'aaaaaa'.
	self assert:
		(m subexpression: 2) size + (m subexpression: 3) size + (m subexpression: 4) size = 6
]
