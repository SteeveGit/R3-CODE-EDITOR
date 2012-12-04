REBOL [
	file: %evid.r3
]
unless value? 'misc.r3 [do %misc.r3]

;------------------
;- Private context
;  Should not be accessed by user's code or styles

ctx-evid: context [

	cmd-text: import 'text
	cmd-draw: import 'draw
	cmd-shape: import 'shape
	proto-face: none
	show-queue: make block! 50
	error: none					; current error!
	errors: []					; stacked errors
	bound-err: func [][throw make error! "Word not bound (face/ prefix is missing)"]
	*edge: *para: *font: none	; prototypes
	new-lvl: 0					; if > 0, creation mode activated.
	clicked: off				; for buttons
	sav-offset: 0x0
	rel-offset: 0x0
	global:	none				; system event (issued by the system)

	on-error: func [
		quiet {do not trace Exit}
		run [block!] body
		/local res args
	][
		if error? set/any 'res try run [
			for i 5 (-7 + stack/depth 1) 1 [
				if value? in evid stack/word i [
					args: stack/args i
					print switch/default stack/word i [
						with [[i "with (face =" args/1/type ")" copy/part mold/flat args/2 40]]
						do-action [[i "do-action(face=" args/1/type ",action="args/2 ")"]]
					][
						[
							i "]" stack/word i ":"
							copy/part trim/with mold stack/block i "^M^/^t" 60
						]
					]
				]
			]
			print reform bind compose [
				"*ERROR*:"
				(system/catalog/errors/(res/type)/(res/id))
				lf "Where: " trim/with copy/part mold :where 60 lf
				lf "Near: " trim/with copy/part mold :near 60 lf
			] to-object get/any 'res
			throw/name false 'next-event
		]
		:res
	]

	do-safe: func [body [block!] /quiet][
		on-error quiet body body
	]

	;---------------------
	;- Protect the methods
	foreach w words-of* self [if any-function? get w [protect w]]

]

;--------------------------------------
;- Public interface of the EVID dialect
;--------------------------------------
EVID: context bind [
	;- public properties (not protected to go a little faster, worth it ?)

	faces: []					; stack of faces
	face: 						; current face (alias gob/data)
	gob:						; current gob (alias face/gob)
	event:						; current event belonging to the face
	key:
	key-face:					; receive key events
	caller:						; caller of the current face (a face!)
	parent: none				; parent of the face (a face!)
	*sys: bind? 'insert
	*show: :*sys/show
	action: none

	;- public methods (protected)

	as-face: func [it [gob! object!]][
		case [
			object? it [it]
			object? it/data [it/data]
			it/parent [it/parent/data] ; promote the container
		]
	]
	resize: does [switch/all 'resize face/when]
	show-now: does [
		unless empty? show-queue [
			foreach gob show-queue [
				'print ["*SHOW*" gob/parent/size ":" gob/offset gob/size "-"
					min max parent/size (gob/offset + gob/size) gob/offset
				]
				unless find show-queue gob/parent [*show gob]
			]
			clear show-queue
		]
	]
	do-action: func [
		face [object! none!] action [word!]
		/show {show now!}
	][
		unless face [exit]
		;print ["action:" action key face/type face/offset face/size]
		with face [switch/all action face/when]
		if show [show-now]
	]

	show: does [unless find show-queue gob [append show-queue gob]]
	parent-size: does [
		either parent [
			parent/size - either parent/edge [parent/edge/size * 2][0x0]
		][0x0]
	]
	append-child: func [new [object!]][all [face gob append gob new/gob]]
	resize-childs: funco[/local face] [
		foreach gob gob/pane [do-action gob/data 'resize]
	]
	with: func [ face* [object!] body [block!] /quiet /local save][
		faces: change faces caller: face	; push faces
		face: face* gob: face/gob
		parent: any [all [gob/parent gob/parent/data] caller]
		on-error quiet body body
		set [caller face] back faces: back faces ; pop faces
		gob: face/gob
		parent: any [all [gob/parent gob/parent/data] caller]
	]
	is: func [
		{Current face inherits from a block!}
		spec [block!] /words at
	][
		unless empty? words: collect-words/set/ignore spec words-of face [
			append face body-of foreach :words words compose [
				set words: copy bind? (to-lit-word words/1) none words
			]
		]
		do-safe bind bind spec face self
	]
	track: does [
		out: new-line/all copy/part back stack/block 2 3 off
		if out/3 [out/3: copy/part mold out/3 20]
		print mold out
	]
	has: func [
		{build a new face based on a block! constructor}
		spec [block!]
		/hide
		/local new
	][
		;track
		; activate the creation mode
		++ new-lvl ;if  zero? ++ new-lvl [bind spec evid]

		new: copy proto-face
		new/gob: make gob! [size: 0x0]
		new/gob/data: new
		new/init: spec
		unless hide [append-child new] 	; append new face inside its parent

		with new [is spec]
		-- new-lvl
		:new
	]
	when: func [
		{add/replace actions in the WHEN block! of the face}
		body [block!]
		/before
		/local when pos
	][
		; WHEN blocks are inherited and cumulative.
		; So, when an action is triggered, several code blocks may be executed for the same action.
		; It's the purpose of the switch/all in do-action
		either empty? when: face/when [
			face/when: body
		][
			if before [return face/when: head insert copy when body]
			if new-lvl > 0 [return append face/when: copy when body] ; if creation mode, cumulative copy.
			; if not in creation mode: the action is replaced.
			; *** Actually, I'm not sure of the interest.
			; More obvious for the coder to directly access the action in the when block!, like for:
			; face/when/click: [do this...]
			; Moreover, there is a case not managed by the following code (several actions for one code block!)
			foreach [action code] body [
				all [
					remove pos: find/reverse tail when action	; remove the action word!
					block? pick pos 1		; followed by an action block! ?
					not word? pick pos -1	; and not shared by another action word! ?
					remove pos				; safe! one can remove the action block!
				]
				repend when [action code]
			]
		]
	]
	yx: xy: does [rel-offset] 	; alias 'rel-offset "xy" alias 'rel-offset "yx"
	x: does [rel-offset * 1x0]
	y: does [rel-offset * 0x1]

	color: func [color [tuple! none!]][
		gob/color: face/color: color
	]
	draw: func [draw [block! none!]][
		unless face/draw [
			face/type: 'container
			append gob face/draw: make gob! [offset: 0x0 size: gob/size]
		]
		face/draw/draw: if draw [bind bind draw cmd-shape cmd-draw]
	]
	font: func [
		body [block! word! pair! tuple! string! object!]
		/local font rule
	][
		if object? body [face/font: body exit]
		font: face/font
		if all[new-lvl > 0 font][font: face/font: copy face/font]
		unless font [face/font: font: make *font [] ]
		body: either block? body [copy body][to-block body]
		rule: bind [
			  set align ['left | 'right | 'center | 'top | 'bottom]
			| set style ['bold | 'none | 'italic | 'underline]
			| set name string!
			| set size integer!
			| set shadow pair!
			| set color tuple!
			| and set-word! do skip
			| and word! do rule
			| skip
		] font
		parse bind body font [any rule]
	]
	para: func [
		body [block!]
		/local para rule
	][
  		para: face/para
		if all [new-lvl > 0 para][para: face/para: copy face/para]
		unless para [face/para: para: make *font [] ]
		body: either block? body [copy body][to-block body]
		rule: bind [
			  set align ['left | 'right | 'center | 'top | 'bottom]
			| set valign ['center | 'top | 'bottom]
			| set origin pair! | 'origin set origin pair!
			| 'margin set margin pair!
			| 'indent set indent pair!
			| 'scroll set scroll pair!
			| set tabs integer!
			| set wrap? logic!
			| and set-word! do skip
			| and word! do rule
			| skip
		] para
		parse bind body para [any rule]
	]
	text: func [text /extend][
		unless gob? face/text [
			face/type: 'container
			append gob face/text: make gob! [offset: 0x0 size: gob/size]
			face/text/text: bind
				reduce ['anti-alias on 'para face/para 'font face/font 'scroll 0x0 'text "..."] cmd-text
			unless in face 'size-of-text [
				append face reduce [
					'size-of-text :size-text
					'state copy []
				]
			]
		]
		text: switch type?/word text [
			block! [
				bind text cmd-text
				either extend
					[clear change next find/tail face/text/text 'scroll text]
					[face/text/text: text]
			]
			string! [text]
			'else [form text]
		]
		if string? text [change-if find face/text/text string! text]
	]
	offset: func [pair [pair! block!]][
		if block? pair [
			pair: reduce pair
			pair: 1x0 * pair/1 + (0x1 * pair/2)
		]
		gob/offset: face/offset: pair
	]
	rescale: func [para [object!] new [pair!] old [pair!]][
		para/scroll:  max
			para/scroll * new / max 1x1 old
			negate max 0x0 new - face/size ; - edge !?
	]
	size: func [pair [pair! block!] /local para][
		if block? pair [
			pair: reduce pair
			pair: 1x0 * pair/1 + (0x1 * pair/2)
		]
		gob/size: face/size: pair
		if all [face/type = 'container gob][
			foreach child gob/pane [
				unless child/data [child/size: gob/size]
			]
		]
		if face/text [ ;text gob
			face/pane-size: either para: face/para [
				pair: max 1x1 para/origin + para/margin + face/size-of-text face/text
				rescale para pair face/pane-size
				pair
			][
				max 1x1 face/size-of-text face/text
			]

		]
	]
	grow: func [face offset /x /y][
		case [
			x [face/pane-size/x: max face/pane-size/x offset/x]
			y [face/pane-size/y: max face/pane-size/y offset/y]
		]
	]
	move: func [
		pair [pair!]
		/abs
	][
		pair: max 0x0 either abs [pair][face/offset + pair]
		pair: min pair parent-size - face/size
		gob/offset: face/offset: pair
	]
	full: does [parent-size - face/offset]
	till: func [this [object!]][max 0x0 this/offset - face/offset]
	targeted?: does [same? event/gob/data face]
	do-scroll: func [/offset pair [pair!] /x /y][
		if offset [
			face/para/scroll: face/para/scroll + pair
		]
		case/all [
			x [switch/all 'hscroll face/when]
			y [switch/all 'vscroll face/when]
		]
	]

	flags: func [body [block!]][gob/flags: body]
	form-error: func [
		error [object!] /local msg
	][
		all [
			msg: get in system/error error/type
			msg: get in msg error/id
			block? msg
			msg: trim/with mold/only reduce bind copy msg error "^/^""
		]
		ajoin [
			msg "^/Near:" trim/with copy/part mold error/near 50 lf
			"^/Where:" trim/with mold error/where lf
		]
	]
	previous: does [all [1 < length? gob/parent pick find gob/parent gob 0]]
	below: func [gob [gob! object! none!]][
		if object? gob [gob: gob/gob]
		either gob [gob/offset + gob/size][0x0]
	]
	do-key: func [this [word!]][
		key: also key all [
			key: this
			switch/all 'key key-face/when
		]
	]
<<<<<<< HEAD
	focus: func [face [object! none!]][
		unless face [exit]
		unless empty? intersect [unfocus focus key] collect-words face/when [
			if key-face [unfocus key-face]
			do-action key-face: face 'focus
=======
	focus: func [this [object! none!]][
		unless this [exit]
		unless empty? intersect [unfocus focus key] collect-words this/when [
			all [key-face not same? key-face this unfocus key-face]
			key-face: this
			do-action this 'focus
>>>>>>> insert new lines
		]
		key-face
	]
	unfocus: func [face][
		;if in face 'idx [print ["*** unfocus" face/idx]]
		do-action face 'unfocus
	]
	upper: func [/local this][
		if this: pick find parent/gob gob 0 [this/data]
	]
	lower: func [/local this][
		if this: pick find parent/gob gob 2 [this/data]
	]
	;---------------------
	;- Protect the methods
	foreach w words-of* self [if any-function? get w [protect w]]

] ctx-evid

;-------------------------
;- Helpers

find-parent: func [gob [object! gob!]][
	if object? gob [gob: gob/gob]
	until [
		not all [gob: gob/parent object? gob/data gob/data/type = 'container]
	]
	gob
]
path-name: func [face /local path idx][
	path: clear []
	until [
		append path ajoin [
			face/type
			either 1 < idx: index? any [
				all [face/gob/parent find face/gob/parent face/gob]
				[]
			][join "-" idx][""]
			"/"
		]
		not all [face/gob/parent face: face/gob/parent/data]
	]
	head clear back tail rejoin reverse path
]

;--------------------------------------
;- configure system dependent handlers
do bind bind load %evid-events.r3 evid ctx-evid

;--------------
;- init EVID data
evid/face: screen
evid/gob: screen/gob
evid/faces: next reduce [screen]

unless value? 'load-all-styles.r3 [do %load-all-styles.r3]