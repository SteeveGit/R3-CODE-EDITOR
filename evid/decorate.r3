REBOL []
decorate: context [
	out: make block! 7
	trailer: make block! 7
	last-color: none
	ctx: context [
		color: func [color [tuple!]][
			if color <> last-color [
				flush-text
				append append out 'color last-color: color
			]
		]
	]
	value: none
	work: make string! 63
	flush-text: does [
		unless empty? work [append append out 'text copy work clear work]
	]
	gen: func [tokens rule /local void][
		clear out
		clear trailer
		last-color: none
		bind rule ctx
		parse tokens [
			(clear work)
			any [
				  and [and <tag> rule] skip set value tag! 
				  	(append work mold :value)
				  ;| and [and <info> rule] skip set value string! 
				  ;	(repend trailer ['text use [err][err: value 'err]])
				| and tag! rule set value skip 
					(append work value )
				| [space (append work space)| tab (append work tab)] 
				| set value rule (append work mold :value)
			]
		]
		flush-text
		if empty? out [append out reduce ['text copy ""]]
		copy append out trailer
	]
]
