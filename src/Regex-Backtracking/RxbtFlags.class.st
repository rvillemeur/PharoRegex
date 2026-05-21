"
Immutable value object holding active regex flags during
RxbtCompiler AST traversal. Flags: ignoreCase (i), dotall (s), multiline (m), extended (x).
Defaults: ignoreCase false, dotall true, multiline true, extended false —
matching Pharo RxMatcher base behaviour. Use applySet:clear: to derive modified copies.
"
Class {
	#name : 'RxbtFlags',
	#superclass : 'Object',
	#instVars : [
		'ignoreCase',
		'dotall',
		'multiline',
		'extended'
	],
	#category : 'Regex-Backtracking-Base',
	#package : 'Regex-Backtracking',
	#tag : 'Base'
}

{ #category : 'instance creation' }
RxbtFlags class >> caseInsensitive [
    ^self new ignoreCase: true dotall: true multiline: true extended: false
]

{ #category : 'instance creation' }
RxbtFlags class >> default [
    ^self new ignoreCase: false dotall: true multiline: true extended: false
]

{ #category : 'operations' }
RxbtFlags >> applySet: setStr clear: clearStr [
    | f |
    f := self.
    setStr do: [:ch |
        ch = $i ifTrue: [f := f withIgnoreCase: true].
        ch = $s ifTrue: [f := f withDotall: true].
        ch = $m ifTrue: [f := f withMultiline: true].
        ch = $x ifTrue: [f := f withExtended: true]].
    clearStr do: [:ch |
        ch = $i ifTrue: [f := f withIgnoreCase: false].
        ch = $s ifTrue: [f := f withDotall: false].
        ch = $m ifTrue: [f := f withMultiline: false].
        ch = $x ifTrue: [f := f withExtended: false]].
    ^f
]

{ #category : 'accessing' }
RxbtFlags >> dotall [
    ^dotall
]

{ #category : 'accessing' }
RxbtFlags >> extended [
    ^extended
]

{ #category : 'accessing' }
RxbtFlags >> ignoreCase [
    ^ignoreCase
]

{ #category : 'initialize' }
RxbtFlags >> ignoreCase: i dotall: s multiline: m extended: x [
    ignoreCase := i.
    dotall     := s.
    multiline  := m.
    extended   := x
]

{ #category : 'accessing' }
RxbtFlags >> multiline [
    ^multiline
]

{ #category : 'copying' }
RxbtFlags >> withDotall: s [
    ^RxbtFlags new ignoreCase: ignoreCase dotall: s multiline: multiline extended: extended
]

{ #category : 'copying' }
RxbtFlags >> withExtended: x [
    ^RxbtFlags new ignoreCase: ignoreCase dotall: dotall multiline: multiline extended: x
]

{ #category : 'copying' }
RxbtFlags >> withIgnoreCase: i [
    ^RxbtFlags new ignoreCase: i dotall: dotall multiline: multiline extended: extended
]

{ #category : 'copying' }
RxbtFlags >> withMultiline: m [
    ^RxbtFlags new ignoreCase: ignoreCase dotall: dotall multiline: m extended: extended
]
