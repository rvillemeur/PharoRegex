Class {
	#name : 'RxbtMatcherTest',
	#superclass : 'TestCase',
	#category : 'Regex-Backtracking-Tests-Tests',
	#package : 'Regex-Backtracking-Tests',
	#tag : 'Tests'
}

{ #category : 'testing' }
RxbtMatcherTest class >> shouldInheritSelectors [
    "Inherit all RxMatcherTest tests plus our overrides."
    ^true
]

{ #category : 'running' }
RxbtMatcherTest >> compileRegex: aString [
    "Use RxbtParser so all inherited tests run through the independent implementation."
    | tree |
    tree := RxbtParser safelyParse: aString.
    ^tree ifNotNil: [self matcherClass for: tree]
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> henryReadme [
	self error: 'The tests in this category are based on the ones in Henry Spencer''s regexp.c package.'
]

{ #category : 'accessing' }
RxbtMatcherTest >> matcherClass [ ^RxbtMatcher
]

{ #category : 'private' }
RxbtMatcherTest >> runMatcher: aMatcher with: aString expect: aBoolean withSubexpressions: anArray [
    | copy got |
    copy := aMatcher
        copy: aString
        translatingMatchesUsing: [:each | each].
    self assert: copy equals: aString.
    got := aMatcher search: aString.
    self assert: got equals: aBoolean.
    (anArray isNil or: [aMatcher supportsSubexpressions not])
        ifTrue: [^self].
    1 to: anArray size by: 2 do: [:index |
        | sub subExpect subGot |
        sub       := anArray at: index.
        subExpect := anArray at: index + 1.
        subGot    := aMatcher subexpression: sub.
        self assert: subGot equals: subExpect]
]

{ #category : 'utilties' }
RxbtMatcherTest >> runRegex: anArray [

	"Run a clause anArray against a set of tests. Each clause is an array with a regex source string followed by sequence of 3-tuples. Each three-element group is one test to try against the regex, and includes: 1) test string; 2) expected result; 3) expected subexpression as an array of (index, substring), or nil."

	| source matcher |

	source := anArray first.
	matcher := self compileRegex: source.
	matcher
		ifNil: [ ( anArray at: 2 )
				ifNotNil: [ self signalFailure: 'Compilation failed, should have succeeded: ' , source printString ]
			]
		ifNotNil: [ ( anArray at: 2 )
				ifNil: [ self signalFailure: 'Compilation succeeded, should have failed: ' , source printString ]
				ifNotNil: [ 2 to: anArray size by: 3 do: [ :index |
						self
							runMatcher: matcher
							with: ( anArray at: index )
							expect: ( anArray at: index + 1 )
							withSubexpressions: ( anArray at: index + 2 )
						]
					]
			]
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testCaseInsensitive [
	| matcher |
	matcher := self matcherClass forString: 'the quick brown fox' ignoreCase: true.
	self
		assert: (matcher search: 'the quick brown fox');
		assert: (matcher search: 'The quick brown FOX');
		assert: (matcher search: 'What do you know about the quick brown fox?');
		assert: (matcher search: 'What do you know about THE QUICK BROWN FOX?')
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testCaseSensitive [
	| matcher |
	matcher := self matcherClass forString: 'the quick brown fox' ignoreCase: false.
	self assert: (matcher search: 'the quick brown fox').
	self deny: (matcher search: 'The quick brown FOX').
	self assert: (matcher search: 'What do you know about the quick brown fox?').
	self deny: (matcher search: 'What do you know about THE QUICK BROWN FOX?')
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testCopyReplacingMatches [
	"See that the match context is preserved while copying stuff between matches:"

	| matcher |
	matcher := self matcherClass forString: '\<\d\D+'.
	self
		assert: (matcher copy: '9aaa1bbb 8ccc' replacingMatchesWith: 'foo') equals: 'foo1bbb foo'
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testCopyTranslatingMatches [
	| matcher |
	matcher := self matcherClass forString: '\w+'.
	self assert: (matcher copy: 'now is  the   time    ' translatingMatchesUsing: [ :each | each reversed ]) equals: 'won si  eht   emit    '
]

{ #category : 'tests - empty' }
RxbtMatcherTest >> testEmptyStringAtBeginningOfLine [
	| matcher |
	matcher := self matcherClass forString: '^'.
	self
		assert: (matcher copy: 'foo1 bar1' , String cr , 'foo2 bar2' replacingMatchesWith: '*')
			= ('*foo1 bar1' , String cr , '*foo2 bar2')
		description: 'An empty string at the beginning of a line'
]

{ #category : 'tests - empty' }
RxbtMatcherTest >> testEmptyStringAtBeginningOfWord [
	| matcher |
	matcher := self matcherClass forString: '\<'.
	self
		assert: (matcher copy: 'foo bar' replacingMatchesWith: '*')
			= '*foo *bar'
		description: 'An empty string at the beginning of a word'
]

{ #category : 'tests - empty' }
RxbtMatcherTest >> testEmptyStringAtEndOfLine [
	"Functionality depends on RxMatcher>>#atEndOfLine supporting #lf such that #crlf is considered as one line ending.
	The whole approach of RxMatcher to deal with line endings might be worth a discussion.
	Before this test was introduced, only #cr and #crlf would have worked, the latter one only because #lf had not been considered as related to line endings at all"
	
	| matcher |
	matcher := self matcherClass forString: '$'.
	
	{ String cr. String lf. String crlf } do: [ :eol |
		self
			assert: (matcher copy: 'foo1 bar1' , eol , 'foo2 bar2' replacingMatchesWith: '*')
				= ('foo1 bar1*', eol , 'foo2 bar2*')
			description: 'An empty string at the end of a line'
	]
]

{ #category : 'tests - empty' }
RxbtMatcherTest >> testEmptyStringAtEndOfWord [
	| matcher |
	matcher := self matcherClass forString: '\>'.
	self
		assert: (matcher copy: 'foo bar' replacingMatchesWith: '*')
			= 'foo* bar*'
		description: 'An empty string at the end of a word'
]

{ #category : 'tests - empty' }
RxbtMatcherTest >> testEmptyStringAtWordBoundary [
	| matcher |
	matcher := self matcherClass forString: '\b'.
	self
		assert: (matcher copy: 'foo bar' replacingMatchesWith: '*')
			= '*foo* *bar*'
		description: 'An empty string at a word boundary'
]

{ #category : 'tests - empty' }
RxbtMatcherTest >> testEmptyStringNotAtWordBoundary [
	| matcher |
	matcher := self matcherClass forString: '\B'.
	self
		assert: (matcher copy: 'foo bar' replacingMatchesWith: '*')
			= 'f*o*o b*a*r'
		description: 'An empty string not at a word boundary'
]

{ #category : 'tests' }
RxbtMatcherTest >> testEscapedLineEndings [ 

	self assert: (
		((ClyRegexPattern with: '^bb\ncc') matches: 
				(String streamContents: [ :s | #( 'aa' 'bb' 'cc') do: [ :e | s << e; lf] ]))
			&
		((ClyRegexPattern with: '^bb\rcc') matches: 
				(String streamContents: [ :s | #( 'aa' 'bb' 'cc') do: [ :e | s << e; cr] ]))
			&
		((ClyRegexPattern with: '^bb\r\ncc') matches: 
			(String streamContents: [ :s | #( 'aa' 'bb' 'cc') do: [ :e | s << e; cr; lf] ]))
	)

]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry001 [
	self runRegex: #('abc'
		'abc' true (1 'abc')
		'xbc' false nil
		'axc' false nil
		'abx' false nil
		'xabcy' true (1 'abc')
		'ababc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry002 [
	self runRegex: #('ab*c'
		'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry003 [
	self runRegex: #('ab*bc'
		'abc' true (1 'abc')
		'abbc' true (1 'abbc')
		'abbbbc' true (1 'abbbbc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry004 [
	self runRegex: #('ab+bc'
		'abbc' true (1 'abbc')
		'abc' false nil
		'abq' false nil
		'abbbbc' true (1 'abbbbc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry005 [
	self runRegex: #('ab?bc'
		'abbc' true (1 'abbc')
		'abc' true (1 'abc')
		'abbbbc' false nil
		'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry006 [
	self runRegex: #('^abc$'
		'abc' true (1 'abc')
		'abcc' false nil
		'aabc' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry007 [
	self runRegex: #('^abc'
		'abcc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry008 [
	self runRegex: #('abc$'
		'aabc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry009 [
	self runRegex: #('^'
		'abc' true nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry010 [
	self runRegex: #('$'
		'abc' true nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry011 [
	self runRegex: #('a.c'
		'abc' true (1 'abc')
		'axc' true (1 'axc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry012 [
	"Need to get creative to include the null character..."
	self runRegex: #('a.*c'
		'axyzc' true (1 'axyzc')
		'axy zc' true (1 'axy zc') "testing that a dot matches a space"
		), (Array with: 'axy', (String with: 0 asCharacter), 'zc'), #(false nil "testing that a dot does not match a null"
		'axyzd' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry013 [
	self runRegex: #('.a.*'
		'1234abc' true (1 '4abc')
		'abcd' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry014 [
	self runRegex: #('a\w+c'
		' abbbbc ' true (1 'abbbbc')
		'abb bc' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry015 [
	self runRegex: #('\w+'
		'  	foobar	quux' true (1 'foobar')
		' 	~!@#$%^&*()-+=\|/?.>,<' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry016 [
	self runRegex: #('a\W+c'
		'a   c' true (1 'a   c')
		'a bc' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry017 [
	self runRegex: #('\W+'
		'foo!@#$bar' true (1 '!@#$')
		'foobar' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry018 [
	self runRegex: #('a\s*c'
		'a   c' true (1 'a   c')
		'a bc' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry019 [
	self runRegex: #('\s+'
		'abc3457 sd' true (1 ' ')
		'1234$^*^&asdfb' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry020 [
	self runRegex: #('a\S*c'
		'aqwertyc' true (1 'aqwertyc')
		'ab c' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry021 [
	self runRegex: #('\S+'
		'     	asdf		' true (1 'asdf')
		'
			' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry022 [
	self runRegex: #('a\d+c'
		'a0123456789c' true (1 'a0123456789c')
		'a12b34c' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry023 [
	self runRegex: #('\d+'
		'foo@#$%123ASD #$$%^&' true (1 '123')
		'foo!@#$asdfl;' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry024 [
	self runRegex: #('a\D+c'
		'aqwertyc' true (1 'aqwertyc')
		'aqw6ertc' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry025 [
	self runRegex: #('\D+'
		'1234 abc 456' true (1 ' abc ')
		'1234567890' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry026 [
	self runRegex: #('(f|o)+\b'
		'foo' true (1 'foo')
		' foo ' true (1 'foo'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry027 [
	self runRegex: #('\ba\w+' "a word beginning with an A"
		'land ancient' true (1 'ancient')
		'antique vase' true (1 'antique')
		'goofy foobar' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry028 [
	self runRegex: #('(f|o)+\B'
		'quuxfoobar' true (1 'foo')
		'quuxfoo ' true (1 'fo'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry029 [
	self runRegex: #('\Ba\w+' "a word with an A in the middle, match at A and further"
		'land ancient' true (1 'and')
		'antique vase' true (1 'ase')
		'smalltalk shall overcome' true (1 'alltalk')
		'foonix is better' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry030 [
	self runRegex: #('fooa\>.*'
		'fooa ' true nil
		'fooa123' false nil
		'fooa bar' true nil
		'fooa' true nil
		'fooargh' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry031 [
	self runRegex: #('\>.+abc'
		' abcde fg' false nil
		'foo abcde' true (1 ' abc')
		'abcde' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry032 [
	self runRegex: #('\<foo.*'
		'foo' true nil
		'foobar' true nil
		'qfoobarq foonix' true (1 'foonix')
		' foo' true nil
		' 12foo' false nil
		'barfoo' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry033 [
	self runRegex: #('.+\<foo'
		'foo' false nil
		'ab foo' true (1 'ab foo')
		'abfoo' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry034 [
	self runRegex: #('a[bc]d'
		'abc' false nil
		'abd' true (1 'abd'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry035 [
	self runRegex: #('a[b-d]e'
		'abd' false nil
		'ace' true (1 'ace'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry036 [
	self runRegex: #('a[b-d]'
		'aac' true (1 'ac'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry037 [
	self runRegex: #('a[-b]'
		'a-' true (1 'a-'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry038 [
	self runRegex: #('a[b-]'
		'a-' true (1 'a-'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry039 [
	self runRegex: #('a[a-b-c]' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry040 [
	self runRegex: #('[k]'
		'ab' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry041 [
	self runRegex: #('a[b-a]' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry042 [
	self runRegex: #('a[]b' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry043 [
	self runRegex: #('a[' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry044 [
	self runRegex: #('a]'
		'a]' true (1 'a]'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry045 [
	self runRegex: #('a[]]b'
		'a]b' true (1 'a]b'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry046 [
	self runRegex: #('a[^bc]d'
		'aed' true (1 'aed')
		'abd' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry047 [
	self runRegex: #('a[^-b]c'
		'adc' true (1 'adc')
		'a-c' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry048 [
	self runRegex: #('a[^]b]c'
		'a]c' false nil
		'adc' true (1 'adc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry049 [
	self runRegex: #('[\de]+'
		'01234' true (1 '01234')
		'0123e456' true (1 '0123e456')
		'0123e45g78' true (1 '0123e45'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry050 [
	self runRegex: #('[e\d]+' "reversal of the above, should be the same"
		'01234' true (1 '01234')
		'0123e456' true (1 '0123e456')
		'0123e45g78' true (1 '0123e45'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry051 [
	self runRegex: #('[\D]+'
		'123abc45def78' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry052 [
	self runRegex: #('[[:digit:]e]+'
		'01234' true (1 '01234')
		'0123e456' true (1 '0123e456')
		'0123e45g78' true (1 '0123e45'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry053 [
	self runRegex: #('[\s]+'
		'2  spaces' true (1 '  '))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry054 [
	self runRegex: #('[\S]+'
		'  word12!@#$  ' true (1 'word12!@#$'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry055 [
	self runRegex: #('[\w]+'
		' 	foo123bar	45' true (1 'foo123bar'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry056 [
	self runRegex: #('[\W]+'
		'fii234!@#$34f' true (1 '!@#$'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry057 [
	self runRegex: #('[^[:alnum:]]+'
		'fii234!@#$34f' true (1 '!@#$'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry058 [
	self runRegex: #('[%&[:alnum:]]+'
		'foo%3' true (1 'foo%3')
		'foo34&rt4$57a' true (1 'foo34&rt4')
		'!@#$' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry059 [
	self runRegex: #('[[:alpha:]]+'
		' 123foo3 ' true (1 'foo')
		'123foo' true (1 'foo')
		'foo1b' true (1 'foo'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry060 [
	self runRegex: #('[[:cntrl:]]+'
		' a 1234asdf' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry061 [
	self runRegex: #('[[:lower:]]+'
		'UPPERlower1234' true (1 'lower')
		'lowerUPPER' true (1 'lower'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry062 [
	self runRegex: #('[[:upper:]]+'
		'UPPERlower1234' true (1 'UPPER')
		'lowerUPPER ' true (1 'UPPER'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry063 [
	self runRegex: #('[[:space:]]+'
		'2  spaces' true (1 '  '))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry064 [
	self runRegex: #('[^[:space:]]+'
		'  word12!@#$  ' true (1 'word12!@#$'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry065 [
	self runRegex: #('[[:graph:]]+'
		'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry066 [
	self runRegex: #('[[:print:]]+'
		'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry067 [
	self runRegex: #('[^[:punct:]]+'
		'!hello,world!' true (1 'hello'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry068 [
	self runRegex: #('[[:xdigit:]]+'
		'  x10FCD  ' true (1 '10FCD')
		' hgfedcba0123456789ABCDEFGH '
			true (1 'fedcba0123456789ABCDEF'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry069 [
	self runRegex: #('ab|cd'
		'abc' true (1 'ab')
		'abcd' true (1 'ab'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry070 [
	self runRegex: #('()ef'
		'def' true (1 'ef' 2 ''))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry071 [
	self runRegex: #('()*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry072 [
	self runRegex: #('*a' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry073 [
	self runRegex: #('^*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry074 [
	self runRegex: #('$*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry075 [
	self runRegex: #('(*)b' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry076 [
	self runRegex: #('$b'	'b' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry077 [
	self runRegex: #('a\' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry078 [
	self runRegex: #('a\(b'
		'a(b' true (1 'a(b'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry079 [
	self runRegex: #('a\(*b'
		'ab' true (1 'ab')
		'a((b' true (1 'a((b'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry080 [
	self runRegex: #('a\\b'
		'a\b' true (1 'a\b'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry081 [
	self runRegex: #('abc)' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry082 [
	self runRegex: #('(abc' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry083 [
	self runRegex: #('((a))'
		'abc' true (1 'a' 2 'a' 3 'a'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry084 [
	self runRegex: #('(a)b(c)'
		'abc' true (1 'abc' 2 'a' 3 'c'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry085 [
	self runRegex: #('a+b+c'
		'aabbabc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry086 [
	self runRegex: #('a**' nil)
]

{ #category : 'tests' }
RxbtMatcherTest >> testHenry087 [
    "In RxbtMatcher, a*? is a valid lazy star, not a parse error."
    self runRegex: #('a*?' '' true nil 'aaa' true nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry088 [
	self runRegex: #('(a*)*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry089 [
	self runRegex: #('(a*)+' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry090 [
	self runRegex: #('(a|)*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry091 [
	self runRegex: #('(a*|b)*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry092 [
	self runRegex: #('(a+|b)*'
		'ab' true (1 'ab' 2 'b'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry093 [
	self runRegex: #('(a+|b)+'
		'ab' true (1 'ab' 2 'b'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry094 [
	self runRegex: #('(a+|b)?'
		'ab' true (1 'a' 2 'a'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry095 [
	self runRegex: #('[^ab]*'
		'cde' true (1 'cde'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry096 [
	self runRegex: #('(^)*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry097 [
	self runRegex: #('(ab|)*' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry098 [
	self runRegex: #(')(' nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry099 [
	self runRegex: #('' 'abc' true (1 ''))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry100 [
	self runRegex: #('abc' '' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry101 [
	self runRegex: #('a*'
		'' true '')
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry102 [
	self runRegex: #('abcd'
		'abcd' true (1 'abcd'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry103 [
	self runRegex: #('a(bc)d'
		'abcd' true (1 'abcd' 2 'bc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry104 [
	self runRegex: #('([abc])*d'
		'abbbcd' true (1 'abbbcd' 2 'c'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry105 [
	self runRegex: #('([abc])*bcd'
		'abcd' true (1 'abcd' 2 'a'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry106 [
	self runRegex: #('a|b|c|d|e' 'e' true (1 'e'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry107 [
	self runRegex: #('(a|b|c|d|e)f'
		'ef' true (1 'ef' 2 'e'))
	"	((a*|b))*	-	c	-	-"
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry108 [
	self runRegex: #('abcd*efg'
		'abcdefg' true (1 'abcdefg'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry109 [
	self runRegex: #('ab*'
		'xabyabbbz' true (1 'ab')
		'xayabbbz' true (1 'a'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry110 [
	self runRegex: #('(ab|cd)e' 'abcde' true (1 'cde' 2 'cd'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry111 [
	self runRegex: #('[abhgefdc]ij' 'hij' true (1 'hij'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry112 [
	self runRegex: #('^(ab|cd)e' 'abcde' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry113 [
	self runRegex: #('(abc|)def' 'abcdef' true nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry114 [
	self runRegex: #('(a|b)c*d' 'abcd' true (1 'bcd' 2 'b'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry115 [
	self runRegex: #('(ab|ab*)bc' 'abc' true (1 'abc' 2 'a'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry116 [
	self runRegex: #('a([bc]*)c*' 'abc' true (1 'abc' 2 'bc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry117 [
	self runRegex: #('a([bc]*)(c*d)' 'abcd' true (1 'abcd' 2 'bc' 3 'd'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry118 [
	self runRegex: #('a([bc]+)(c*d)' 'abcd' true (1 'abcd' 2 'bc' 3 'd'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry119 [
	self runRegex: #('a([bc]*)(c+d)' 'abcd' true (1 'abcd' 2 'b' 3 'cd'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry120 [
	self runRegex: #('a[bcd]*dcdcde' 'adcdcde' true (1 'adcdcde'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry121 [
	self runRegex: #('a[bcd]+dcdcde' 'adcdcde' false nil)
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry122 [
	self runRegex: #('(ab|a)b*c' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry123 [
	self runRegex: #('((a)(b)c)(d)' 'abcd' true (1 'abcd' 3 'a' 4 'b' 5 'd'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry124 [
	self runRegex: #('[ -~]*' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry125 [
	self runRegex: #('[ -~ -~]*' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry126 [
	self runRegex: #('[ -~ -~ -~]*' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry127 [
	self runRegex: #('[ -~ -~ -~ -~]*' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry128 [
	self runRegex: #('[ -~ -~ -~ -~ -~]*' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry129 [
	self runRegex: #('[ -~ -~ -~ -~ -~ -~]*' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry130 [
	self runRegex: #('[ -~ -~ -~ -~ -~ -~ -~]*' 'abc' true (1 'abc'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry131 [
	self runRegex: #('[a-zA-Z_][a-zA-Z0-9_]*' 'alpha' true (1 'alpha'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry132 [
	self runRegex: #('^a(bc+|b[eh])g|.h$' 'abh' true (1 'bh' 2 nil))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry133 [
	self runRegex: #('(bc+d$|ef*g.|h?i(j|k))'
		'effgz' true (1 'effgz' 2 'effgz' 3 nil)
		'ij' true (1 'ij' 2 'ij' 3 'j')
		'effg' false nil
		'bcdd' false nil
		'reffgz' true (1 'effgz' 2 'effgz' 3 nil))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry134 [
	self runRegex: #('(((((((((a)))))))))' 'a' true (1 'a'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry135 [
	self runRegex: #('multiple words of text'
		'uh-uh' false nil
		'multiple words of text, yeah' true (1 'multiple words of text'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry136 [
	self runRegex: #('(.*)c(.*)' 'abcde' true (1 'abcde' 2 'ab' 3 'de'))
]

{ #category : 'tests - henry' }
RxbtMatcherTest >> testHenry137 [
	self runRegex: #('\((.*), (.*)\)' '(a, b)' true (2 'a' 3 'b'))
]

{ #category : 'tests' }
RxbtMatcherTest >> testLineEndings [ 

	self assert: ((ClyRegexPattern with: '^b') matches: 
		(String streamContents: [ :s | #( 'aa' 'bb' 'cc') do: [ :e | s << e; cr] ])).
	self assert: ((ClyRegexPattern with: '^b') matches: 
		(String streamContents: [ :s | #( 'aa' 'bb' 'cc') do: [ :e | s << e; lf] ])).
	self assert: ((ClyRegexPattern with: '^b') matches: 
		(String streamContents: [ :s | #( 'aa' 'bb' 'cc') do: [ :e | s << e; cr; lf] ])).

]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatches [
	| matcher |
	matcher := self matcherClass forString: '\w+'.
	self assert: (matcher matches: 'now').
	self deny: (matcher matches: 'now is')
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchesIn [
	| matcher |
	matcher := self matcherClass forString: '\w+'.
	self assert: (matcher matchesIn: 'now is the time') asArray equals: #('now' 'is' 'the' 'time')
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchesInCollect [
	| matcher |
	matcher := self matcherClass forString: '\w+'.
	self assert: (matcher matchesIn: 'now is the time' collect: [ :each | each reversed ]) asArray equals: #('won' 'si' 'eht' 'emit')
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchesInDo [
	| matcher expected |
	matcher := self matcherClass forString: '\w+'.
	expected := #('now' 'is' 'the' 'time') asOrderedCollection.
	matcher matchesIn: 'now is the time' do: [ :each | self assert: each equals: expected removeFirst ].
	self assertEmpty: expected
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchesOnStream [
	| matcher |
	matcher := self matcherClass forString: '\w+'.
	self assert: (matcher matchesOnStream: 'now is the time' readStream) asArray equals: #('now' 'is' 'the' 'time')
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchesOnStreamCollect [
	| matcher |
	matcher := self matcherClass forString: '\w+'.
	self assert: (matcher matchesOnStream: 'now is the time' readStream collect: [ :each | each reversed ]) asArray equals: #('won' 'si' 'eht' 'emit')
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchesOnStreamDo [
	| matcher expected |
	matcher := self matcherClass forString: '\w+'.
	expected := #('now' 'is' 'the' 'time') asOrderedCollection.
	matcher matchesOnStream: 'now is the time' readStream do: [ :each | self assert: each equals: expected removeFirst ].
	self assertEmpty: expected
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchesStream [
	| matcher |
	matcher := self matcherClass forString: '\w+'.
	self assert: (matcher matchesStream: 'now' readStream).
	self deny: (matcher matchesStream: 'now is' readStream)
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testMatchingRangesIn [
	| matcher expected |
	matcher := self matcherClass forString: '\w+'.
	expected := #(1 3 5 6 8 10 12 15) asOrderedCollection.
	(matcher matchingRangesIn: 'now is the time')
		do: [ :range |
			self assert: range first equals: expected removeFirst.
			self assert: range last equals: expected removeFirst ].
	self assertEmpty: expected
]

{ #category : 'tests' }
RxbtMatcherTest >> testRegex001 [
	self runRegex: #('^.*$'
		'' true (1 '')
		'a' true (1 'a')
		'abc' true (1 'abc'))
]

{ #category : 'tests' }
RxbtMatcherTest >> testRegex002 [
	self runRegex: #('a\w+c'
		' abb_bbc ' true (1 'abb_bbc')
		'abb-bc' false nil)
]

{ #category : 'tests' }
RxbtMatcherTest >> testRegex003 [
	self runRegex: #('a\W+c'
		' abb_bbc ' false nil
		'abb-bc' false nil
		'a.,:;-&!"#%/()={[]}+?\~*''c' true (1 'a.,:;-&!"#%/()={[]}+?\~*''c'))
]

{ #category : 'tests' }
RxbtMatcherTest >> testRegex004 [
	self runRegex: #(':isVowel:'
		'aei' true nil
		'xyz' false nil)
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringAllRangesOfRegexMatches [
	| result |
	result := 'aabbcc' allRangesOfRegexMatches: 'b+'.
	self
		assert: result size equals: 1;
		assert: result first first equals: 3;
		assert: result first last equals: 4
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringAllRegexMatches [
	| result |
	result := 'aabbcc' allRegexMatches: 'b+'.
	self
		assert: result size equals: 1;
		assert: result first equals: 'bb'
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringAsRegex [

	self assert: 'b+' asRegex class equals: RxParser preferredMatcherClass
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringAsRegexIgnoringCase [

	self assert: 'b+' asRegexIgnoringCase class equals: RxParser preferredMatcherClass
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringCopyWithRegexMatchesReplacedWith [

	self assert: ('aabbcc' copyWithRegex: 'b+' matchesReplacedWith: 'X') equals: 'aaXcc'
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringCopyWithRegexMatchesTranslatedUsing [
	self assert: ('aabbcc'
		copyWithRegex: 'b+'
		matchesTranslatedUsing: [ :each |
			self assert: each equals: 'bb'.
			'X' ]) equals: 'aaXcc'
]

{ #category : 'tests' }
RxbtMatcherTest >> testStringGreedyMatchesRegex [

	self assert: ('199' matchesRegex: '([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])').
	self assert: ('25' matchesRegex: '([0-9]|[1-9][0-9])').
	self assert: ('25' matchesRegex: '([1-9][0-9]|[0-9])').
	self assert: ('25' matchesRegex: '(\d\d|\d)').
	self assert: ('25' matchesRegex: '(\d|\d\d)').
	self assert: ('bb' matchesRegex: '([a-z]|[b-z][a-z])').
	self assert: ('b' matchesRegex: '([b-z][a-z]|[a-z])').
	self assert: ('15' matchesRegex: '[1-9]|1[0-9]').
	self assert: ('b' matchesRegex: '(b|bb)').
	self assert: ('b' matchesRegex: '(bb|b)').
	self assert: ('fooABCD' matchesRegex: '.*(ABCD|BC)').
	self assert: ('fooBC' matchesRegex: '.*(ABCD|BC)').
	self assert: ('fooB' matchesRegex: '.*(ABC|B)').
	self assert: ('fooABC' matchesRegex: '.*(ABC|B)')
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringMatchesRegex [
	self deny: ('aabbcc' matchesRegex: 'a+').
	self deny: ('aabbcc' matchesRegex: 'b+c+').
	self assert: ('aabbcc' matchesRegex: 'a+b+c+')
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringMatchesRegexIgnoringCase [
	self deny: ('AABBCC' matchesRegexIgnoringCase: 'a+').
	self deny: ('AABBCC' matchesRegexIgnoringCase: 'b+c+').
	self assert: ('AABBCC' matchesRegexIgnoringCase: 'a+b+c+')
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringPrefixMatchesRegex [
	self assert: ('aabbcc' prefixMatchesRegex: 'a+').
	self deny: ('aabbcc' prefixMatchesRegex: 'b+')
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringPrefixMatchesRegexIgnoringCase [
	self assert: ('AABBCC' prefixMatchesRegexIgnoringCase: 'a+').
	self deny: ('AABBCC' prefixMatchesRegexIgnoringCase: 'b+')
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringRegexMatchesCollect [
	| result |
	result := 'aabbcc' regex: 'b+' matchesCollect: [ :each | each asUppercase ].
	self
		assert: result size equals: 1;
		assert: result first equals: 'BB'
]

{ #category : 'tests - extensions' }
RxbtMatcherTest >> testStringRegexMatchesDo [
	| result |
	result := OrderedCollection new.
	'aabbcc' regex: 'b+' matchesDo: [ :each | result add: each ].
	self
		assert: result size equals: 1;
		assert: result first equals: 'bb'
]

{ #category : 'tests - protocol' }
RxbtMatcherTest >> testSubexpressionCount [
	| matcher |
	#(('a' 1) ('a(b)' 2) ('a(b(c))' 3) ('(a)(b)' 3) ('(a(b))*' 3)) do: [ :pair |
		matcher := self matcherClass forString: pair first.
		matcher supportsSubexpressions
			ifTrue: [ self assert: matcher subexpressionCount equals: pair last ] ]
]
