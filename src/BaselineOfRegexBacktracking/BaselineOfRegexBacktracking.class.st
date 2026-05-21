"
Metacello baseline for the Regex-Backtracking package.
Loads Regex-Backtracking and Regex-Backtracking-Tests from the repository.
"
Class {
	#name : 'BaselineOfRegexBacktracking',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfRegexBacktracking',
	#package : 'BaselineOfRegexBacktracking'
}

{ #category : 'accessing' }
BaselineOfRegexBacktracking class >> version [
    ^'1.0.0'
]

{ #category : 'baselines' }
BaselineOfRegexBacktracking >> baseline: spec [
    <baseline>
    spec for: #common do: [
        spec
            package: 'Regex-Backtracking';
            package: 'Regex-Backtracking-Tests'
                with: [spec requires: #('Regex-Backtracking')]]
]
