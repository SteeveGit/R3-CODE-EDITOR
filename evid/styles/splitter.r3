; Splitter (horizontal by default)
; axis: 0x1 -> horizontal
; axis: 1x0 -> vertical
;
; usage:
; VSPLIT: has [axis: 1x0 is styles/splitter]
; VSPLIT/dock1: has [...]
; VSPLIT/dock2: has [...]

DOCK1: DOCK1	; 2 faces moved/resized by the splitter
DOCK2: DOCK2
is drag-bar
when [
	resize [
		with face/DOCK1 [
			; above/before the split bar
			size full * (reverse caller/axis) + (caller/axis * till caller)
		]
		with face/DOCK2 [
			; below/after the split bar
			offset face/offset * (reverse caller/axis) + (caller/axis * below caller)
			size full
		]
	]
]