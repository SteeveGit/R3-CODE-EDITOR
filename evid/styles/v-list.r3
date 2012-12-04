;--------------------------------
;- V-LIST Polymorphic Vertical List
;
;  Build a vertival list of sub-faces.
;  Sub-faces are defined by a user style and may have varying sizes.
;  This style is optimized so that it can manage huge lists with a small footprint.
;  Only the visible sub-faces are actually showed.
;  The REBOL's graphic engine will go faster and it also saves memory.
;  Hidden sub-faces are kept in a small cache so that,
;   sub-faces which play the 'hide and seek' game a lot
;   are simply stacked/unstacked (without the need to reconstruct them each time).
;  Another optimization is related to the recycling of the sub-faces not needed anymore.
;  These are not destroyed but go in a pool instead.
;  When a new sub-face must be created, a free one is taken from the pool.
;  This way, the creation of sub-faces is faster and memory safer (no endless recycling).
;
;  INPUT:
;	child-style [block!]: the user style of the sub-faces (optionnal)
;	data [block!]:	data container from which the sub-faces pick their content (optionnal)
;
;  A legit user's child-style must contain a RESIZE action which is called
;  by V-LIST to refresh the content of any sub-face when required.
;  The face/data of a sub-face must be used to reflect the content modification.
;  The resize action must also contain code which refresh the size of the sub-face,
;   even if the size does not vary.
;  For instance:
;  ... resize [
;				;(V-LIST automaticly reset face/text and face/size)
;				text mold face/data/pick 1	; reflect any modification of the data content
;				size 100x20					; size must also be refreshed.
;      ]
;
;  USAGE:
;    has [data: [...] child-style: [...] is v-list]
;    has [data: [...] child-style: [...] goto: length? data  is v-list] ; start showing the tail
;
;  TO-DO: To be able to build H-LIST from it (all the /y become /x)

REBOL [
	file: %v-list.r
]

width: any [width 30] ; 40 ??? magical number
para [] ; copy or create a new face/para
old-scroll: face/para/scroll
hidden-above: make block! 31	; gob container for hidden childs (cached sub-faces)
hidden-below: make block! 31	; gob container for hidden childs (cached sub-faces)
pool: make block! 63			; pool of free to use child protos
data: any [data copy []]	; array of data used to construct the childs
goto: any [goto 1]			; data index to start with to show

tmp: tmp1: tmp2: tmp3: none	; temporaries
; BEWARE: The temporaries are not prefixed with face/ when they are used in this script.
; It could cause problems if recursive calls were done
;  or if another V-LIST is constructed by any sub-face.
; Because the context would be shared.
; Using face/ prefix would be safer, but the code readability is better as it is.

trace_: []
trace: 'func [b [block!]][
	append trace_ try/except [probe reduce b][
		? tmp1 probe b halt
	]
]
correct: 0
;dprint: :print dprin: :prin
dprint: dprin: none

; data iterator
data: context [
	data: copy []
	length?: does [*sys/length? data]
	pick: func [idx][*sys/pick data idx]
	empty?: does [*sys/empty? data]
]

hidden-to-pool: does [
	append face/pool face/hidden-above
	append face/pool face/hidden-below
	clear face/hidden-above
	clear face/hidden-below
]

; refresh below a child
refresh-below: func [child /local gob][

	; print ["refresh below" child/idx]

	; clear gobs below
	gob: next find face/gob child/gob
	;prin ["index:" index? gob " "]
	while [not empty? gob][
		append face/pool gob/1
		;prin "-"
		remove gob
	]
	print ""
	append face/pool face/hidden-below
	clear face/hidden-below
	do-scroll/y
]
;- Default child style (used if the user one is none!)
child-style: any [child-style [
	font [left sky "arial"]	para [wrap?: true]
	when [
		resize [
			text reform [
				face/idx #" " face/offset #" "
				face/offset/y + face/size/y  #" " face/data
			]
		]
	]
]]
assert [block? child-style]

; helper
refresh-child: [
	face/gob/size: face/size: 0x0
	face/pane-size: 1x1
	if caller [face/data: caller/data/pick face/idx]
	resize
	if face/size = 0x0 [
		size parent-size * 1x0
		; auto expand the height if text gob
		size [face/size max face/pane-size face/size]
	]
]
scroll-line: func [y][
	face/para/scroll/y: face/para/scroll/y + y
	switch/all 'vscroll face/when
	show
]

when [
	;---------------
	;- Resize Action

	resize [
		face/trace_: clear head face/trace_

		;- Move hidden childs to the free pool
		hidden-to-pool

		;- if nothing to show, go to a line index
		if all [empty? gob not face/data/empty?][
			face/goto: any [face/goto 1]
		]

		;- if last line showed, be certain one stay at the end
		all [
			tmp: last gob
			tmp: tmp/data
			tmp/idx = face/data/length?
			face/goto: face/data/length?
		]

		face/pane-size/y: max 1 face/width * face/data/length?

		;- go to a requested line
		if integer? face/goto [face/goto: max 0 min face/goto face/data/length?]
		if all [integer? face/goto  face/goto > 0][
			trace ['goto face/goto]
			append face/pool gob/pane
			tmp: any [
				take/last face/pool ;; pick a free child
				has/hide [idx: 1 is caller/child-style] ;; or create a new one
			]
			if gob? tmp [tmp: tmp/data]
			;- refresh it
			tmp/idx: face/goto
			tmp/gob/offset/y: tmp/offset/y: 0
			append gob tmp/gob
			with tmp refresh-child
			;- compute the scrolling offset based on the child index
			face/para/scroll/y: face/old-scroll/y:
				negate  tmp/idx / (face/data/length?) * face/pane-size/y
		]
		face/goto: none

		face/trace_: tail face/trace_

		;- Resize only the visible childs
		unless empty? gob [
			foreach child gob/pane [
				if object? child/data [with child/data refresh-child]
			]
			do-scroll/y
		]
	]
	realign [
		tmp: gob/1/offset/y + gob/1/size/y
		foreach child next gob/pane [
			child/data/offset/y: child/offset/y: tmp + correct
			tmp: child/size/y + tmp + correct
		]
		show
	]
	;---------------
	;- Scroll Action
	scroll-up [face/scroll-line 30]
	scroll-down [face/scroll-line -30]
	vscroll [

		if face/data/empty? [exit]
		clear face/trace_

		;- Join showed and hidden childs, in order
		insert-gob gob face/hidden-above
		append-gob gob face/hidden-below
		clear face/hidden-above
		clear face/hidden-below

		;- Recompute sub-face offsets with new para/scroll
		;  Childs which are out of the window are moved in face/hidden
		tmp: face/para/scroll/y - face/old-scroll/y  + gob/1/offset/y
		tmp1: clear []
		tmp2: clear []
		foreach child gob/pane [
			child/data/offset/y: child/offset/y:  tmp
			tmp: child/size/y + tmp + correct
			case [
				tmp < 0 [
					dprint ["hide above" child/data/idx]
					append tmp2 child
					remove find gob child
				]
				child/offset/y > face/size/y [
					dprint ["hide below" child/data/idx]
					append tmp1 child
					remove find gob child
				]
				; childs which are already inside the window are only scrolled
			]
		]
		unless empty? tmp1 [insert face/hidden-below tmp1 clear tmp1]
		unless empty? tmp2 [append face/hidden-above tmp2 clear tmp2]

		;- If all childs are out of the window, move them from face/hidden to face/pool
		all [
			not tmp1: gob/1
			any [trace ['repos] on]
			tmp1: any [first face/hidden-above first face/hidden-below]
			hidden-to-pool
			tmp1/offset/y < 0
			insert face/pool take/last face/pool		; replaced at the top of the pool (not visible)
		]
		unless tmp1 [; should never happen

			print ["*** Error in V-LIST style: no sub-face to show ***"]

			dump-face face
			exit
		]

		;- Insert new childs at the top of the window
		tmp1: tmp1/data

		;trace ['head tmp1/idx]

		tmp2: none
		tmp: clear []
		while [true][
			if tmp1/idx = 1 [
				face/para/scroll/y: tmp1/offset/y
				if tmp1/offset/y > 0 [
					; correct the wrong shift of the first child (rescroll)
					trace ['Bad-shift1 tmp1/idx 'shift tmp1/offset/y tmp1/offset]
					face/para/scroll/y: 0
					face/old-scroll: tmp1/offset
					if empty? gob [
						; May happen if the scrolling gap is too wide
						trace ['Empty-pane]
						hidden-to-pool
						remove find face/pool tmp1/gob
						append-gob gob tmp1/gob
					]

					face/trace_: tail face/trace_
					do-scroll/y ;rescroll
					exit
				]
				break
			]
			if tmp1/offset/y <= 0 [break]
			tmp2: any [
				tmp2
				take/last face/pool
				take/last face/hidden-below
				take face/hidden-above
				has/hide [idx: 1 is caller/child-style] ; create a new child
			]
			if gob? tmp2 [tmp2: tmp2/data]
			tmp2/idx: tmp1/idx - 1
			with tmp2 refresh-child
			tmp2/gob/offset/y: tmp2/offset/y: tmp1/offset/y - tmp2/size/y + correct
			tmp1: tmp2
			if tmp2/offset/y < face/size/y [
				; inside the window, show it
				append tmp tmp2/gob
				tmp2: none
			]
		]
		unless empty? tmp [insert-gob gob reverse tmp clear tmp]

		;- Append new childs at the bottom of the window

		tmp1: any [last gob tmp1]
		if gob? tmp1 [tmp1: tmp1/data]

		;trace ['tail tmp1/idx]

		tmp: clear []
		while [true][
			if tmp1/idx = face/data/length? [
				if face/para/scroll/y < 0 [
					if  0 < tmp: face/size/y - tmp1/offset/y - tmp1/size/y  - 1 [
						; correct the wrong shift of the last child (re-scroll)

						print ['Bad-shift2 tmp1/idx 'shift tmp tmp1/offset]

						face/para/scroll/y: face/size/y - face/pane-size/y
						face/old-scroll/y: face/para/scroll/y - tmp
						if empty? gob [
							; May happen if the scrolling gap is too wide
							trace ['empty-pane]
							hidden-to-pool
							remove find face/pool tmp1/gob
							append-gob gob tmp1/gob
						]

						face/trace_: tail face/trace_
						do-scroll/y ; re-scroll
						exit
					]
					tmp: []
				]
				break
			]
			if tmp1/offset/y + tmp1/size/y > face/size/y [break]
			; pick a free child
			tmp2: any [
				tmp2
				take/last face/pool
				take face/hidden-above
				take/last face/hidden-below
				has/hide [idx: 1 is caller/child-style] ; create a new child
			]
			if gob? tmp2 [tmp2: tmp2/data]
			; refresh it
			tmp2/idx: tmp1/idx + 1
			with tmp2 refresh-child
			tmp2/gob/offset/y: tmp2/offset/y: tmp1/offset/y + tmp1/size/y + correct
			tmp1: tmp2
			if tmp2/offset/y + tmp2/size/y > 0 [
				; inside the window, show it
				append tmp tmp2/gob
				tmp2: none
			]
		]
		unless empty? tmp [append-gob gob tmp clear tmp]

		;- resize the pool (0.5 to 1 times the number of visible sub-faces
		;  (Not sure it's doing what is claimed !!!)
		if (length? face/pool) + (length? face/hidden-above) + (length? face/hidden-below)
				* 2 < length? gob [
			loop tmp: 2 + to-integer (length? gob) / 2 [
				tmp: has/hide [idx: 1 is caller/child-style] ; create a new child
				append face/pool tmp/gob
			]
			trace ['Add-pool tmp/gob 'total (length? face/pool) + (length? face/hidden-above) + (length? face/hidden-below)]
		]

		;-------------------------------------------------------------------------
		; *** Well! It was a pain in the ass to find out the correct following adjustements.
		; *** So, forget changing anything here if you care for your life smart ass!
		; The idea is to speed up or slow down the scrolling
		; depending how far is the wheel from the destination.
		; Remember, neither the scroller, neither the list know
		;  the real size of the list (in pixels),
		; because the sub-faces of the list may have dynamic varying sizes,
		; and their real size is only discovered during the scrolling
		;  when they are actually showed.
		; So, one has to correct these parameters on the fly.

		;- Adjust the pane-size
		tmp: last gob	; last sub-face currently showed
		tmp: tmp/data
		dprint ["last showed gob idx used for pane-size:" tmp/idx]
		face/pane-size/y: (face/size/y  + abs face/para/scroll/y) * (face/data/length?)
				/ (tmp/idx - 1 + (face/size/y - tmp/offset/y / tmp/size/y))
		trace ['pane-size face/pane-size/y 'size face/size/y]

		;- Adjust the scrolling offset
		tmp: first gob ; first sub-face currently showed
		tmp: tmp/data
		face/old-scroll/y: face/para/scroll/y:
			negate min max 0 (face/pane-size/y - face/size/y)
				(tmp/idx - (tmp/offset/y / tmp/size/y)) * face/pane-size/y / (face/data/length?)

		face/trace_: head face/trace_
		;*sys/trace/function on
	] ; end scroll
] ;end when

