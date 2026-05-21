Class {
	#name : 'RxbtSyntaxError',
	#superclass : 'RxbtError',
	#instVars : [
		'position'
	],
	#category : 'Regex-Backtracking-Exceptions',
	#package : 'Regex-Backtracking',
	#tag : 'Exceptions'
}

{ #category : 'instance creation' }
RxbtSyntaxError class >> signal: anErrorMessage at: errorPosition [
    ^self new
        position: errorPosition;
        signal: anErrorMessage
]

{ #category : 'accessing' }
RxbtSyntaxError >> position [
    ^position
]

{ #category : 'accessing' }
RxbtSyntaxError >> position: anInteger [
    position := anInteger
]
