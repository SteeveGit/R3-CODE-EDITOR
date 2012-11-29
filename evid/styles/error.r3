Show Errors
Used by the EVID engine only.
Need complete rewrite, old code for R2.

REBOL []

use [
	errors where near pos tmp tmp1 len search sub end-word find-near
	form-rule tab-size ender
][
	;-----------------------------------
	;- internal helpers

	end-word: charset "[]^-^/()^"{} "
	tab-size: 4 ; tab-size used by mold
	nl: [any #" " lf any #" "]
	ender: [opt nl [end | #"]" | #")"]]
	find-near: func [a b][
		all [
			parse/all a [
				any [to b/1 a: [b to end | b/1 ]]
			]
			a
		]

	]

	form-rule: func [blk [block!] /local add-ender][
		if 5 > length? blk [add-ender: true]
		blk: remove head remove back tail mold blk
		blk: parse/all entab/size blk tab-size "^-^/"
		parse blk [
			any [
				blk: "" (blk/1: 'nl) any [""]
				| string! (blk/1: trim blk/1)
				| skip
			]
		]
		if add-ender [append blk 'ender]
		head blk
	]

	;-------------------------------------------------------
	;- The style (open a new window, must be used with VUE)

	[
		offset 0x150 size 500x400
		color gray
		options: [resize]	; allow 'resize windows event to be captured
		when [
			resize [resize-childs show]
		]
		text "EVID ERROR!"

		(; Because of the (), these words are not added in the face.
			errors: head ctx-evid/errors
			where: errors/1/where
			sub: none
		)

		info: has [; Info box with error! text
			color yellow
			font [red bold 14]
			text form-error errors/1
			size [full 50]
			when [resize [size [full face/size/y]]]
		]

		forskip errors 4 [
			sub: has/hide [
				color either sub [sub/color + 8][black + 34]
				para [wrap?: off] font ["verdana" sky 12 left]
				origin: 0x0

				text mold/only errors/4
				near: mold/only errors/3
				search: form-rule errors/3
				if lf = face/text/1 [remove face/text]

				if any [
					tmp: find-near face/text search
					;all [edge [1x1 red] false] ;*** NOT FOUND***
					tmp: find-near face/text search: reduce [mold where]
				][
					if parse/all tmp1: copy/part face/text tmp [some[:tmp1 thru lf tmp1: 6 [thru lf]]][
						; cut long head
						insert remove/part face/text offset? face/text tmp1 "...^/"
						tmp: find-near face/text search
					]
					unless sub [
						parent/info/size/y: 20
						parse/all tmp1: tmp [any [end-word break | skip tmp1: ] to lf tmp1:]
						len: (caret-to-offset face tmp1) - (pos: caret-to-offset face tmp) + 2x0
						has [ ; Add a color box to hilight the error
							;edge yellow
							offset origin: pos - 1x0
							size [len 16]
						]
						parse/all tmp [ 5 [thru lf] tmp: (append clear tmp " ...")] ; cut long tail
						size face/size
					]
				]
				unless tmp [
					face/text: tmp: near
				]
				if sub [
					append tmp lf
					parse/all tmp [ any lf thru lf any tab tmp: (clear tmp)] ; make room
					pos: caret-to-offset face tail tmp
					append-child sub
					with sub [
						offset face/origin: pos	+ 40x2
					]
				]
				when [
					resize [
						size full
						resize-childs
						face/size: max face/size face/pane-size
						parent/pane-size: max parent/pane-size (face/offset + face/size)
					]
				]
			]
		]
		append-child sub
		with sub [
			; replace WHEN block of the sub face with:
			face/when: [
				resize [
					face/offset/y: parent/info/size/y	;below the info box
					size full
					resize-childs
					scroll
				]
				scroll [
					foreach child face/pane [
						with child [offset face/origin + parent/para/scroll show]
					]
				]
			]
		]

		has/hide [from: sub is styles/scroller]
	]
]
