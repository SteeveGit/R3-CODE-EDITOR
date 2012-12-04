REBOL []

lexer: context [
	value: none
	bracket: context [
		level: 0
		opener: closer:
		parent: none
	]
	line: context [
		raw: copy #{}
		id: 1
		tokens: make block! 7
		bra: bracket
	]
	lines: make block! 127

	push: func [value] bind [
		parent: copy bracket
		++ level
		reduce/into [:value level '_]
			line/tokens: tail append line/tokens <open>
		opener: copy line
		opener/bra: none
		set closer: copy line none
		rule: switch :value rules
	] bracket

	pop: func [value] bind [
		reduce/into [:value level '_]
			line/tokens: tail append line/tokens <close>
		if parent [
			resolve/all closer line
			resolve/all bracket parent
		] ;**** else missing opening bracket
	] bracket

	ctx: context [
		OPEN-CHAR: [value: (push to char! value/0)]
		CLOSE-CHAR: [value: (pop to char! value/0)]
		str: none
		OPEN-STR: [(push to string! str)]
		DATA-TYPE: [
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
								"  >> "
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
	skip-lf: [opt [crlf | lf]]
	token: [
		  end break
		| and crlf break
		| and lf break
		| rule
	]
	raw: none
	create-line: bind [
		(append lines copy/types line object!)
		(rule: select-rule)
		copy raw [any token] skip-lf (
			lines/:id/raw: raw
			tokens: make block! 7
		)
		opt [lf (++ id) ]
	] line
	change-line: func [idx bin] bind [
		set-line idx
		id: idx
		tokens: clear head tokens
		parse bin [copy raw [any token] bin:]
		resolve/all lines/:idx line
		bin
	] line
	new-line: func [bin] bind [
		++ id
		tokens: make block! 11
		insert at lines id copy/types line object!
		parse bin [skip-lf copy raw [any token] bin:]
		resolve/all lines/:id line
		bin
	] line
	all-lines: does [parse source [any create-line]]
	set-line: func [idx][
		if line/id <> idx [
			resolve/all line lines/:idx
			resolve/all bracket line/bra
			rule: select-rule
		]
	]

	blank: charset " ^-"
	auto-indent: func [l1 l2 /local beg][
		parse l1 [copy beg some blank (insert l2 beg)]
	]
	rebuild: func [idx blk /local bin source][
		set-line idx
		bin: clear #{}
		parse blk [any [to string! blk: (append bin blk/1) skip]]
		either not find bin #{0A} [
			change-line idx bin
			line/tokens
		][
			;*** Too slow, currently when a newline is inserted, all the lines
			;    below are reconstructed.
			unless empty? bin: change-line idx bin [
				until [
					print to-string line/raw
					print ["new-line" line/id + 1]
					empty? bin: new-line bin
				]
			]
			false ; inform caller of the reconstruction
		]
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
