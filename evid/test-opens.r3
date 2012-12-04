REBOL []

old: [ <open>  "[" 2 /1 <close> "]" 2 /2 <open> "[" 2 /3]
new: [ <open>  "[" 2 _ <open> "[" 3 _ <close> "]" 2 _ <open> "[" 2 _ ]

take-old: [
	new: :old (num: '*)
	to tag remove [tag! skip set num integer!]
	:new
]
parse new [
	(lvl: 1)
	any [
		to [<open> | <close> ]
		copy SEQ [tag! skip integer!] (? seq)
		[
			if (DATA: find/tail old SEQ) (? data/1)
				change skip DATA/1
				(remove/part skip DATA -3 4)
			| skip
		]
	]
]
probe old
probe new

halt

