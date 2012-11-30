REBOL [
	file: %desk.r
]

do %evid/evid.r3
do %evid/lexer.r3
do %evid/decorate.r3

;*** Load R3 lexer
open-b: charset "[({"
close-b: charset "])"
digit: charset "0123456789"
hexa: union charset "abcdefABCDEF" digit
escape: [#"^^" skip]
lexer/set-rule [
	#[none] #"[" #"(" "#[" [[
		  SPACES
		| open-b OPEN-CHAR
		| close-b CLOSE-CHAR
		| copy STR ["#{" | "2#{" | "16#{" | "64#{" | "#["] OPEN-STR
		| copy STR [#";" [to crlf | to end]] (EMIT-STR <comment>)
		| LOAD-VALUE
	]]
	#"{" [[
			copy STR any [
				  and [end | crlf | #"}"] break
				| #"{" OPEN-CHAR
				| escape | skip
			] (EMIT-STR <multi-string>)
			opt [#"}" CLOSE-CHAR]
	]]
	"2#{" [[
		8[#"0" | #"1"] | #"}" CLOSE-CHAR
	]]
	"#{" "16#{"	[[
		2 hexa | #"}" CLOSE-CHAR
	]]

]

lexer/source: read %code-editor.r3 ; test
lexer/all-lines

;*** set syntax coloring
any-set!: to-typeset [set-word! set-path!]
beautify: [
	any-set! (color maroon)
	| and tag! [
		  <comment> (color blue)
		| <multi-string> (color leaf)
		| <tag> tag! (color leaf)
		| <error> (color red underline)
		| <help> (NEWLINE bold color red)
	]
	| [string! | char!] (color leaf)
	| url! (color orange)
	| skip (color black)

]

;*** defines new styles
;    When functional, migrate to %/styles
TEXT-MSG: [
	size-of-text: func [gob [gob!] /local len][
		len: 0
		foreach item gob/text [
			if string? item [len: len + length? item]
		]
		either len = 0 [
			gob/text/text: " "
			also size-text gob gob/text/text: copy ""
		][
			size-text gob
		]
	]
	tmp: none
	override-key: [
		left left-word [
			if face/home? [
				show
				with parent [face/focus-upper]
				with key-face [do-key 'end]
				if key = 'left [exit]
			]
		]
		right right-word [
			if face/end? [
				show
				with parent [face/focus-lower]
				with key-face [do-key 'home]
				if key = 'right [exit]
			]
		]
		down [
			tmp: key-face/offset? + 0x5
			with parent [face/focus-lower]
			with key-face [face/focus-offset tmp show]
			exit
		]
		up [
			tmp: key-face/offset? + 0x5
			with parent [face/focus-upper]
			with key-face [face/focus-offset tmp show]
			exit
		]
	]
	when [
		key [switch key override-key]
	]
	is styles/area

	; scroll text horizontally
	face/text/text/scroll: in face/container 'scroll-text

	when [
		resize [
			text/extend parent/data
			size 1x0 * parent/size

			; expand the height of the line
			size max face/size face/pane-size
			; expand the width of list container
			grow/x face/container face/pane-size
			with parent [
				size [full caller/pane-size]
			]
		]
		down [
			print [parent/idx mold next find/tail face/text/text 'scroll]
		]
		key [
			if face/dirty? [
				; rebuil the line (lexer + decorate)
				face/focus-offset also
					face/offset?
					container/data/update parent
			]
		]
	]
]
;*** container of text lines
MSG-LIST: [
	goto: 1
	width: 14
	tmp: none
	when [
		resize [
			;*** DON'T PUT a resize-childs below (added by is styles/v-list)
			print ["resize list" parent/size]
			size [full full]
		]
	]
	scroll-text: 0x0
	text-font: make *fonts/console [color: black]
	para [wrap?: off origin: indent: 0x0 margin: 0x2]
	child-style: [
		container: caller
		line: has [
			container: caller/container
			offset 35x0
			face/font: container/text-font
			face/para: container/para
			is TEXT-MSG
			;color green
			when [
				focus [color 245.240.220]
				unfocus [color none]
			]
		]
		num: has [ ; line number
			;color blue
			face/font: container/text-font
			face/para: container/para
			para [origin: 0x0]
			text compose [para (face/para) font (face/font) color gray right text ""]
			size 30x16
			when [
				resize [text form parent/idx]
			]
		]
		focus-upper: does [
			if same? gob first parent/gob [
				do-action parent 'scroll-up
			]
			focus upper
			show
		]
		focus-lower: does [
			if same? gob last parent/gob [
				do-action parent 'scroll-down
			]
			focus lower
			show
		]
		when [
			resize [
				size [full 0x20]
				resize-childs
				grow/x parent face/pane-size
				show
			]
			focus [focus face/line]
		]
	]
	is styles/v-list
	data: make data [
		data: lexer/lines
		length?: does [*sys/length? data]
		pick: func [idx][
			decorate/gen data/:idx/tokens beautify
		]
		poke: func [idx data][
			lexer/rebuild idx data
		]
		empty?: does [*sys/empty? data]
		update: func [child /local idx tmp][	; a child
			idx: child/idx
			poke idx child/line/text/text
			child/data: pick idx
			with child/line [
				tmp: face/size/y
				resize
				if face/size/y <> tmp [
					print ['size tmp face/size/y]
					do-action parent/container 'realign
				]
			]
		]
	]
	when [
		hscroll [face/scroll-text/x: face/para/scroll/x show]
	]
]

editor: [
	offset 450x50
	size 500x500
	color 255.250.240
	flags [resize] ; allow 'resize windows event to be captured
	when [
		resize [resize-childs show]
		close [unview 'all halt]
	]

	;- info box
	INFO: has [
		color gray
		font [bold white]
		text "R3 Code editor"
		when [
			resize [size [full 20]]
		]
	]
	list: has [
		offset 0x21
		is MSG-LIST
	]
	vscroll: has [ ; vertical scroller
		from: list
		is styles/scroller
	]
	hscroll: has [ ; horizontal scroller
		axis: 1x0
		from: list
		is styles/scroller
	]


]

vue editor
halt