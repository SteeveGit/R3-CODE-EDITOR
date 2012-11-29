REBOL [
	file: %misc.r3
]
misc.r3: true	;-- already loaded

resolve*: :resolve

defined?: func [
	{set words to false if not already defined}
	words [block!]
][
	foreach word words [
		unless value? word [set word false]
	]
]

to-apply: func ['fun][
	assert [any-function? get fun]
	reduce ['apply to-get-word fun to-block trim/with form words-of get fun #"/"]
]

change-if: func words-of :change reduce ['if 'series to-apply change]

words-of*: func[obj [object!]][bind words-of obj obj]

running?: does [system/script/header/file = last split-path system/options/script]

; *** strange bug: native insert reuses free cells in the pane if any,
;     instead of doing exactly what's asked for.
insert-gob: funco [parent [gob!] child [gob! block!]][
	insert head parent child
	;sort-gob parent
]
append-gob: funco [parent [gob!] child [gob! block!]][
	append parent child
	;sort-gob parent
]

; *dummy gnome sort
gnomesort-gob: funco [gob /local sav i j swap][
	if 2 > length? gob [exit]
	while [1 < length? gob][
			sav: gob
			while [(i: gob/1/data/idx) > j: gob/2/data/idx][
				swap: gob/1
				remove gob
				insert next gob swap
				if head? gob [break]
				gob: back gob
			]
			gob: next sav
	]
]

;- halt only the launched script
halt-script: does [
	if running? [
		print ["*** HALT:" system/options/script]
		halt
	]
]



halt-script
