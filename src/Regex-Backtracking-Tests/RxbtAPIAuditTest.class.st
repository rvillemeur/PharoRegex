"
Verifies RxbtMatcher implements the full public API of RxMatcher with identical behaviour.
"
Class {
	#name : 'RxbtAPIAuditTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtAPIAuditTest >> testCopyReplacingMatches [
    | m result |
    m := RxbtMatcher forString: '\d+'.
    result := m copy: 'abc123def456' replacingMatchesWith: 'N'.
    self assert: result equals: 'abcNdefN'
]

{ #category : 'tests' }
RxbtAPIAuditTest >> testCopyTranslatingMatches [
    | m result |
    m := RxbtMatcher forString: '\d+'.
    result := m copy: 'abc123' translatingMatchesUsing: [:s | s reversed].
    self assert: result equals: 'abc321'
]

{ #category : 'tests' }
RxbtAPIAuditTest >> testMatchesIdentical [
    #('foo' '\d+' 'a*b' '^hello' '(cat|dog)') do: [:pat |
        #('foobar' 'hello' 'aaab' 'dog' '') do: [:str |
            | rm rbt |
            rm  := [RxMatcher  forString: pat] on: Error do: [:e | nil].
            rbt := [RxbtMatcher forString: pat] on: Error do: [:e | nil].
            (rm notNil and: [rbt notNil]) ifTrue: [
                self
                    assert: (rm search: str) = (rbt search: str)
                    description: '/' , pat , '/ on ' , str printString]]]
]

{ #category : 'tests' }
RxbtAPIAuditTest >> testMatchingRangesIn [
    | m ranges |
    m := RxbtMatcher forString: '\d+'.
    ranges := m matchingRangesIn: 'abc123def456'.
    self assert: ranges size equals: 2.
    self assert: ranges first equals: (4 to: 6).
    self assert: ranges last  equals: (10 to: 12)
]

{ #category : 'tests' }
RxbtAPIAuditTest >> testNoMissingPublicMethods [
	"Every documented public RxMatcher instance method must exist on RxbtMatcher."

	| publicApi rxbtMethods missing |
	publicApi := #( #matches: #matchesPrefix: #matchesStream:
	                #matchesStreamPrefix: #search: #searchStream:
	                #subexpression: #subexpressionCount
	                #supportsSubexpressions #subexpressionNamed:
	                #subexpressionNames #matchesIn: #matchesIn:collect:
	                #matchesIn:do: #matchesOnStream: #matchesOnStream:collect:
	                #matchesOnStream:do: #matchingRangesIn:
	                #copy:replacingMatchesWith:
	                #copy:translatingMatchesUsing:
	                #copyStream:to:replacingMatchesWith:
	                #copyStream:to:translatingMatchesUsing:
	                #split:indicesDo: #groupNames #registerGroupName:at:
	                #inputString #inputAt: #inputSize #captures #captures: )
		             asSet.
	rxbtMethods := RxbtMatcher methodDict keys asSet.
	missing := publicApi reject: [ :sel | rxbtMethods includes: sel ].
	self
		assert: missing isEmpty
		description:
		'Missing methods: ' , missing asSortedCollection printString
]

{ #category : 'tests' }
RxbtAPIAuditTest >> testRegressionFull [
    | r |
    r := RxbtMatcherTest suite run.
    self assert: r failures isEmpty.
    self assert: r errors isEmpty
]

{ #category : 'tests' }
RxbtAPIAuditTest >> testSubexpressionCount [
    | m |
    m := RxbtMatcher forString: '(a)(b(c))'.
    self assert: m subexpressionCount equals: 4
]

{ #category : 'tests' }
RxbtAPIAuditTest >> testSupportsSubexpressions [
    self assert: (RxbtMatcher forString: 'x') supportsSubexpressions
]
