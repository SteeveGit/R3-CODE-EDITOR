;----------------------------------------
;- Scroller automaticly shrink the target (from:) to make place.
;  usage: has/hide [from: face! is scroller]

type: 'scroller
width: any [width 13]
axis: any [axis 0x1] ; vertical scroller by default
color from/color
with from: from [
	;-- add actions in the scrolled face
	when copy/deep [					; copy/deep to escape further binding
		key [with wheel [scroll show]]	; Refresh wheel when a key is pressed
		resize [ 						; shrink the sabcrolled face
			face/size: face/size - (width  * reverse axis)
		]
		hscroll [with wheel [scroll face/axis with parent [show]]]
		vscroll [with wheel [scroll face/axis with parent [show]]]
	]
	; Append the scroller in the same parent than from.
	; Because this style is invoked with has/hide instead of has
	append parent/gob caller/gob
	;caller/parent-face: parent
]
when [
	resize [
		offset from/offset + (from/size * reverse face/axis)
		size from/size * face/axis + (face/width * reverse face/axis)
		resize-childs
	]
	down [
		; reject the action if the wheel already does it
		unless targeted? [exit]
		; scroll a page
		from/para/scroll: from/para/scroll - face/axis + (
			face/size * (face/axis * min 1x1 max -1x-1 face/wheel/offset - event/offset)
		)
		with from [scroll caller/axis show]
		;with wheel [scroll face/axis show]
	]
]
wheel: has [
	axis: parent/axis
	box-size: 0x0
	box-color: 0.0.0.255
	draw copy [pen sky fill-pen box-color box 0x0 box-size 4]
	ratio: 1
	when copy/deep [;copy/deep to escape binding (improve code readability)
		enter [
			scroll face/axis; not necessary
			show
		]
		up			[box-color: 0.0.0.255  scroll face/axis show]
		down		[box-color: sky show]
		over away [
			move xy * face/axis
			from/para/scroll:
				(from/para/scroll * reverse parent/axis)
				+ (face/offset / face/ratio * negate face/axis)
			with from [scroll caller/axis show]
		]
		resize [
			face/pane-size: max 1x1 parent-size - (face/axis * 2 * width)
			scroll face/axis
		]
		vscroll [
			;print ["pane-size:" "from" from/pane-size "scroller" face/pane-size]

			face/ratio: face/pane-size/y / from/pane-size/y
			size min parent-size
				from/size * 0x1 * face/ratio + (1x2 * parent/width)
			face/box-size: face/size - 2x2
			move/abs from/para/scroll * face/ratio * 0x-1
		]
		hscroll [
			;print ["pane-size:" "from" from/pane-size "scroller" face/pane-size]

			face/ratio: face/pane-size/x / from/pane-size/x
			size min parent-size
				from/size * 1x0 * face/ratio + (1x2 * parent/width)
			face/box-size: face/size - 2x2
			move/abs from/para/scroll * face/ratio * -1x0
		]
	]
]

