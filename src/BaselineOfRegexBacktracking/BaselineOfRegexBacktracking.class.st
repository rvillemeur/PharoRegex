Class {
	#name : 'BaselineOfRegexBacktracking',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfRegexBacktracking',
	#package : 'BaselineOfRegexBacktracking'
}

{ #category : 'baselines' }
BaselineOfRegexBacktracking >> baseline: spec [

	<baseline>
	spec for: #common do: [
			spec
				package: 'Regex-Backtracking';
				package: 'Regex-Backtracking-Tests'
				with: [ spec requires: #( 'Regex-Backtracking' ) ].
			spec
				group: 'default' with: #( 'Regex-Backtracking' );
				group: 'Tests'
				with: #( 'Regex-Backtracking' 'Regex-Backtracking-Tests' ) ]
]
