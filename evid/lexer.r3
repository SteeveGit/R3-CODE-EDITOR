REBOL []

lexer: context [
	value: none
	bracket: context [
		level: 0
		opener: closer:
		parent: none
	]
	line: context [
		id: 1
		tokens: make block! 7
		bra: bracket
	]
	lines: make block! 127

	push: func [value] bind [
		parent: copy bracket
		append  line/tokens: tail append line/tokens <open> :value
		++ level
		opener: copy line
		opener/bra: none
		set closer: copy line none
		rule: switch :value rules
	] bracket

	pop: func [value] bind [
		append line/tokens: tail append line/tokens <close> :value
		resolve/all closer line
		resolve/all bracket parent
	] bracket

	ctx: context [
		OPEN-CHAR: [value: (push to char! value/0)]
		CLOSE-CHAR: [value: (pop to char! value/0)]
		str: none
		open-str: [(push to string! str)]
		load-value: [
			source: (
				set [value next-source] transcode/next/error source
				;*******************************
				;*** transcode BUG or not??? ***
				; path errors are returned built inside a path
				if all [path? :value find :value error!][
					value: first find :value error!
					next-source: next next-source
				]

				switch/default type?/word :value [
					tag! [repend line/tokens [<tag> :value]]
					error! [
						repend line/tokens [
							<error> to-string copy/part source next-source
							<help> ajoin [
								">>> "
								reduce bind/copy
									system/catalog/errors/(value/type)/(value/id)
									to-object :value
							]
						]
					]
				][
						append/only line/tokens :value
				]
			) if (next-source) :next-source
		]
		spaces: [
			space (append line/tokens space)
			| tab (append line/tokens tab)
		]
		emit-str: func [tag][
			if all [STR not empty? STR][
				append append line/tokens tag to string! str
			]
		]
	]
	select-rule: does [
		switch first any [select bracket/opener 'tokens [#[none]]] rules
	]
	source: next-source: none
	set-rule: func [i][rules: bind i ctx]
	rules: rule: [to lf | to end]
	token: [
		  end break
		| crlf break
		| rule
	]
	create-line: bind [
		(append lines copy/types line object!)
		(rule: select-rule)
		any token (tokens: make block! 7)
		opt [lf (++ id) ]
	] line
	all-lines: does [parse source [any create-line]]
	set-line: func [idx][
		if line/id <> idx [
			resolve/all line lines/:idx
			resolve/all bracket line/bra
			rule: select-rule
		]
	]
	rebuild: func [idx blk][
		set-line idx
		bin: clear #{}
		parse blk [any [to string! blk: (append bin blk/1) skip]]
		clear line/tokens
		parse bin [any token]
		line/tokens
	]
	print-lines: does bind [
		forall lines [
			resolve/all line lines/1
			print [
				id ",lv:" bra/level
				"[" select bra/opener 'id
				"-" select bra/closer 'id "]:"
				mold/only new-line head tokens off
			]
		]
	] line
]
