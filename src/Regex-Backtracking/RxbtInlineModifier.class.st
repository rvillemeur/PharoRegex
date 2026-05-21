"
AST node for inline flag modifiers (?i), (?-s), (?im:...) etc.
setFlags and clearFlags are Strings of flag letters.
inner is nil for bare (?flags) — affects rest of enclosing group.
inner is an RxbtRegex for (?flags:...) — scoped non-capturing group with flags.
"
Class {
	#name : 'RxbtInlineModifier',
	#superclass : 'RxbtNode',
	#instVars : [
		'setFlags',
		'clearFlags',
		'inner'
	],
	#category : 'Regex-Backtracking-Nodes',
	#package : 'Regex-Backtracking',
	#tag : 'Nodes'
}

{ #category : 'accessing' }
RxbtInlineModifier >> clearFlags [
    ^clearFlags
]

{ #category : 'double dispatch' }
RxbtInlineModifier >> dispatchTo: aCompiler [
    ^aCompiler syntaxInlineModifier: self
]

{ #category : 'accessing' }
RxbtInlineModifier >> inner [
    ^inner
]

{ #category : 'initialize' }
RxbtInlineModifier >> inner: aNode [
    inner := aNode
]

{ #category : 'testing' }
RxbtInlineModifier >> isNullable [
    ^true
]

{ #category : 'testing' }
RxbtInlineModifier >> isScoped [
    ^inner notNil
]

{ #category : 'accessing' }
RxbtInlineModifier >> setFlags [
    ^setFlags
]

{ #category : 'initialize' }
RxbtInlineModifier >> setFlags: s clearFlags: c [
    setFlags   := s.
    clearFlags := c.
    inner      := nil
]
