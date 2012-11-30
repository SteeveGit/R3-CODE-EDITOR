REBOL []
decorate: context [
	out: make block! 7
	trailer: make block! 7
	last-color: none
	bold?: underline?: off
	ctx: context [
		color: func [color [tuple!]][
			if color <> last-color [
				flush-text
				append append out 'color last-color: color
			]
		]
		bold: does [
			append out [bold on]
			bold?: on
		]
		newline: does [append out 'NEWLINE]
		underline: does [
			append out [underline on]
			underline?: on
		]
	]
	value: none
	work: make string! 63
	flush-text: does [
		unless empty? work [append append out 'text copy work clear work]
	]
	gen: func [tokens rule /local item void start][
		clear out
		clear trailer
		last-color: none
		bind rule ctx
		item: [
			  and [and <tag> rule] skip set value tag!
				(append work mold :value)
			| and [and <help> (start: tail out) rule]
				skip set value string!
			   (	append trailer start
					clear start
					repend trailer ['text use [err][err: value 'err]]
				)
			| and tag! rule set value skip
				(append work value )
			| [space (append work space)| tab (append work tab)]
			| set value rule (append work mold :value)
		]
		parse tokens [
			(clear work)
			any [item (
				if underline? [
					flush-text
					append out [underline off]
					underline?: off
				]
				if bold? [
					flush-text
					append out [bold off]
					bold?: off
				]
			)]
		]
		flush-text
		if empty? out [append out reduce ['text copy ""]]
		copy append out trailer
	]
]
