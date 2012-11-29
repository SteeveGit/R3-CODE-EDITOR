REBOL [
	file: %styles.r3
	description: {
		Load default styles. Styles are blocks
	}
]
styles: context [
	set 'load-style func [file [file!]][bind load join %styles/ file self]

	AREA:		load-style %area.r3
	SCROLLER:	load-style %scroller.r3
	DRAG-BAR:	load-style %drag-bar.r3
	V-LIST:		load-style %v-list.r3
	;H-LIST:	do load-style %h-list.r3 ; built from v-list
	;ERROR:		do load-style %error.r3
	SPLITTER:	load-style %splitter.r3
	;ICONS:		load-style %icons.r3
]
