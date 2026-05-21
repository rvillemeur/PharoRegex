"
Tests for inline flag modifiers in RxbtMatcher.
Defaults: multiline=true, dotall=true, ignoreCase=false, extended=false.
(?-m) and (?-s) turn off multiline/dotall; (?i) turns on ignoreCase.
"
Class {
	#name : 'RxbtInlineModifierTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
RxbtInlineModifierTest >> testCombinedModifiers [
    "(?i-m) turns on ignoreCase and off multiline."
    | str |
    str := 'Line1' , (String with: (Character value: 10)) , 'LINE2'.
    self deny: ((RxbtMatcher forString: '(?i-m)^LINE2') search: str).
    self assert: ((RxbtMatcher forString: '(?i)^LINE2') search: str)
]

{ #category : 'tests' }
RxbtInlineModifierTest >> testDotallOff [
    "(?-s) makes . exclude LF; default includes LF."
    | lf |
    lf := String with: (Character value: 10).
    self assert: ((RxbtMatcher forString: 'a.b') matches: 'a' , lf , 'b').
    self deny:   ((RxbtMatcher forString: '(?-s)a.b') matches: 'a' , lf , 'b')
]

{ #category : 'tests' }
RxbtInlineModifierTest >> testExtendedMode [
    "(?x) strips unescaped whitespace from pattern."
    | m |
    m := RxbtMatcher forString: '(?x) h e l l o'.
    self assert: (m matches: 'hello')
]

{ #category : 'tests' }
RxbtInlineModifierTest >> testIgnoreCaseOn [
    | m |
    m := RxbtMatcher forString: '(?i)hello'.
    self assert: (m matches: 'Hello').
    self assert: (m matches: 'HELLO').
    self deny:   (m matches: 'world')
]

{ #category : 'tests' }
RxbtInlineModifierTest >> testIgnoreCaseScoped [
    | m |
    m := RxbtMatcher forString: '(?i:foo)bar'.
    self assert: (m matches: 'FOObar').
    self deny:   (m matches: 'FOOBAR')
]

{ #category : 'tests' }
RxbtInlineModifierTest >> testIgnoreCaseTurnOff [
    | m |
    m := RxbtMatcher forString: '(?i)FOO(?-i)bar'.
    self assert: (m matches: 'foobar').
    self deny:   (m matches: 'fooBAR')
]

{ #category : 'tests' }
RxbtInlineModifierTest >> testMultilineDefault [
    "^ matches at embedded newlines by default."
    | str |
    str := 'line1' , (String with: (Character value: 10)) , 'line2'.
    self assert: ((RxbtMatcher forString: '^line2') search: str)
]

{ #category : 'tests' }
RxbtInlineModifierTest >> testMultilineOff [
    "(?-m) makes ^ match only at absolute start."
    | str |
    str := 'line1' , (String with: (Character value: 10)) , 'line2'.
    self deny: ((RxbtMatcher forString: '(?-m)^line2') search: str)
]
