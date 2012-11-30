font [left]
para [wrap?: off]
cursor: context [
	caret: copy/deep [[""] ""]
    highlight-start: copy/deep [[""] ""]
    highlight-end: copy/deep [[""] ""]
 ]
caret: face/cursor/caret
state: copy [focus select copy insert]
dirty?: off

unless face/text [text ""]
either find face/text/text 'caret [
	face/text/text/caret: face/cursor
][
	insert find face/text/text 'scroll
		bind reduce ['caret face/cursor] ctx-evid/cmd-text
]

focus-offset: func [offset][
	unless find face/state 'focus [exit]
	face/caret/1/1: head face/caret/2: first face/caret/1: any [
		offset-to-caret face/text offset
		face/caret/1
	]
	;focus face
]
offset?: does [
	caret-to-offset face/text face/caret/1 face/caret/2
]
select?: shift?: control?: off

start-select: does [
	unless find face/state 'select [exit]
	face/select?: on
	change face/cursor/highlight-start face/caret
	change face/cursor/highlight-end face/caret
]
unselect: does [
	unless find face/state 'select [exit]
	face/select?: off
	clear face/cursor/highlight-start
	clear face/cursor/highlight-end
]
see-text: does [print mold skip find face/text/text 'scroll 2]
delete: func [/local tmp][
	unless find face/state 'insert [exit]
	face/dirty?: on
	either face/select? [
		face/caret/2: remove/part face/cursor/highlight-start/2 face/caret/2
		face/unselect
	][
		face/next?
		remove face/caret/2
	]
	;see-text
]
insert-chars: func [chars][
	unless find face/state 'insert [exit]
	face/caret/2: insert face/caret/2 chars
]
next?: func [/local tmp][
	all [
		tail? face/caret/2
		tmp: find next face/caret/1 string!
		face/caret/2: first face/caret/1: tmp
	]
]
back?: func [/local tmp][
	all [
		head? face/caret/2
		tmp: find/reverse face/caret/1 string!
		face/caret/2: tail first face/caret/1: tmp
	]
]
home?: func [/local tmp] [
	all [
		tmp: find head caret/1 string!
		same? face/caret/1 tmp
		same? face/caret/2 tmp/1
	]
]
end?: func [/local tmp] [
	all [
		tmp: find/last caret/1 string!
		same? face/caret/1 tmp
		same? face/caret/2 tail tmp/1
	]
]
blank: charset " ^-^/"
not-blank: complement blank

tmp: copied: none
when [
	;resize [move y  resize x]
	down [
		face/unselect
		face/focus-offset event/offset - 5x0
		face/start-select
		show
	]
	away [
		;if face/select? [change face/caret [0 0] show]
	]
	over [
		;face/focus-offset event/offset 0x5
		;change face/cursor/end caret
		;show
	]
	up [
		change face/cursor/highlight-end face/caret
		show
	]
	unfocus [
		change face/caret [[""] ""] show
	]

	key [
		;print ["area=>" key event/key event/flags]

		face/shift?: find event/flags [shift]
		if all[face/shift? not face/select?][face/start-select]
		face/dirty?: off
		switch/all key [
			right [
				face/next?
				face/caret/2: next face/caret/2
			]
			left #"^H"	[
				face/back?
				face/caret/2: back face/caret/2
			]
			#"^M"		[key: lf]
			up			[face/focus-offset 0x-18 + face/offset?]
			down		[face/focus-offset 0x18 + face/offset?]
			delete #"^H"[delete]
			#"^H"		[key: none]
			right-word [
				parse face/caret/2 [
					while [
						some not-blank
						| end if (face/next?) :face/caret/2
					]
					while [
						some blank
						| end if (face/next?) :face/caret/2
					] face/caret/2:
				]
				face/next?
			]
			left-word [
				tmp: face/caret/2
				foreach match [blank not-blank][
					until [
						tmp: any [face/back? tmp]
						any [
							head? tmp
							not if find get match tmp/0 [tmp: back tmp]
						]
					]
				]
				face/caret/2: tmp
			]
			copy	[
				copied: if face/select? [
					copy/part face/cursor/start/2 face/caret/2
				]
			]
			paste	[if face/select? [face/delete] key: copied]
			end 	[
				face/caret/2: tail first face/caret/1:
					find/last face/text/text string!
			]
			home 	[
				face/caret/2: first face/caret/1: find face/text/text string!
			]
		]
		if any [char? key string? key] [
			face/dirty?: on
			if face/select? [face/delete]
			face/insert-chars key
		]
		if face/select? [
			either face/shift?
				[change face/cursor/highlight-end face/caret]
				[face/unselect]
		]

		;tmp: offset?
		;if gob/size/y < (tmp/y + 18) [
		;	face/_scroll: face/_scroll - 0x18
		;]
		;if 0 > tmp/y [
		;	face/_scroll: face/_scroll + 0x18
		;]
		show
	]
]