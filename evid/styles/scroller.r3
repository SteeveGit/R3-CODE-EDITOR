;----------------------------------------
;- Scroller automaticly shrink the target (from:) to make place.
;  usage: has/hide [from: face! is scroller]

type: 'scroller
width: any [width 13]
axis: any [axis 0x1] ; vertical scroller by default
color from/color
scroll-me: does [
	if axis/x = 1 [do-scroll/x]
	if axis/y = 1 [do-scroll/y]
]
with from: from [
	;-- add actions in the scrolled face
	when copy/deep [					; copy/deep to escape further binding
		;key [with wheel [scroll-me show]]	; Refresh wheel when a key is pressed
		resize [ 						; shrink the sabcrolled face
			face/size: face/size - (width  * reverse axis)
		]
		hscroll [with wheel [scroll-me with parent [show]]]
		vscroll [with wheel [scroll-me with parent [show]]]
	]
	; Append the scroller in the same parent than from.
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
		either face/axis/x = 1 [
			with from [do-scroll/x show]
		][
			with from [do-scroll/y show]
		]
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
			;scroll face/axis; not necessary
			show
		]
		up			[box-color: 0.0.0.255  scroll-me show]
		down		[box-color: sky show]
		over away [
<<<<<<< HEAD
			move xy * face/axis
			from/para/scroll:
				(from/para/scroll * reverse parent/axis)
				+ (face/offset / face/ratio * negate face/axis)
			with from [scroll caller/axis show]
=======
			move xy * axis
			either axis/x = 1 [
				from/para/scroll/x: negate face/offset/x / face/ratio
				with from [do-scroll/x show]
			][
				from/para/scroll/y: negate face/offset/y / face/ratio
				with from [do-scroll/y show]
			]
>>>>>>> insert new lines
		]
		resize [
			face/pane-size: max 1x1 parent-size - (axis * 2 * width)
			either axis/x = 1 [do-scroll/x][do-scroll/y]
		]
		vscroll [
			face/ratio: face/pane-size/y / from/pane-size/y
			size min parent-size
				from/size * 0x1 * face/ratio + (1x2 * parent/width)
			face/box-size: face/size - 2x2
			move/abs from/para/scroll * face/ratio * 0x-1
		]
		hscroll [
			face/ratio: face/pane-size/x / from/pane-size/x
			size min parent-size
				from/size * 1x0 * face/ratio + (1x2 * parent/width)
			face/box-size: face/size - 2x2
			move/abs from/para/scroll * face/ratio * -1x0
		]
	]
]

