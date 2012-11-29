
shrink: any [shrink [.10 .90]] ; min-max displacement ( 2 percentages between 0-1)
axis: any [axis 0x1] ; horizontal bar by default
width: any [width 4]
assert [pair? axis]
old-psize: 0x0	; previous parent size
saved-index: none
when [
	resize [
		do-action face 'over	; confine offset
		if face/old-psize <> 0x0 [
			; proportional rescale
			offset	face/offset * parent-size / face/old-psize * face/axis
					+ (face/offset * reverse face/axis)
		]
		face/old-psize: parent-size
		size parent-size - face/offset * (reverse face/axis) + (face/axis * face/width)
	]
	drag [
		offset (face/offset * reverse face/axis) +
			min (face/axis * parent-size * face/shrink/2)
			max (face/axis * parent-size * face/shrink/1) face/offset + (xy * face/axis)
		show
	]
	down [
		; place the face above the other childs and save old position
		face/saved-index: index? find parent/gob gob
		append parent/gob gob
		show
	]
	up [
		; restore the saved position
		insert at parent/gob face/saved-index gob
		with parent [resize show]
	]
]
