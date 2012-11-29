REBOL [
	file: %evid-events.r
	description: {Evid events handler}
]
unless value? 'misc.r3 [do %misc.r3]

system/ports/system/awake: funco [
    sport "System port (State block holds events)"
    ports "Port list (Copy of block passed to WAIT)"
    /local move income event port waked
][
    waked: sport/data
    income: sport/state
    loop 8 [
    	; eat move events
        if all [event: take income event/type = 'move][
			while [all [move: first income move/type = 'move]][
				event: move remove income
			]
        ]
        unless event [break]
        port: event/port
        if wake-up port event [
            unless find waked port [append waked port]
        ]
    ]
    unless block? ports [return none]
    forall ports [
        if find waked first ports [return true]
    ]
    false
]

;--------------
;- some globals
;--------------
;screen: system/view/screen-face

vue: func [
	style [block!]
	/stop {Private: Avoid recursive calls on errors}
	/new
][
	unless catch/name [
		with screen [with has style [resize]] on
	] 'next-event [exit]
	*sys/show screen/gob
	recycle/ballast 100000
	unless new [do-events]
]

;------------------
;- Some Prototypes
;------------------
;*edge: make system/words/face/edge [size: 1x1 color: none]
*edge: context [
    color: none
    image: none
    effect: none
    size: 1x1
]
;*para: make system/words/face/para [origin: margin: 0x0]
*para: make system/standard/para [
    origin:
    margin: 0x0
    wrap?: false
    align: 'left
    valign: 'center
]
;*font: make system/words/face/font []
*font: make system/standard/font []
*fonts: context [
	normal: make system/standard/font []
	big: make normal [size: 20]
	console: make normal [name: "lucida console" size: 14 offset: 0x0 wrap?: off]
	;console: make normal [name: "courier new" size: 14 offset: 0x0 wrap?: off]
	;console: make normal [name: "Miriam" size: 12 offset: 0x0]
]
;-----------------------------
;- Generic Face handler (feel)
;-----------------------------
;proto-face: make system/words/face [
proto-face: context [
	type: 'default
	gob: none
	offset: 0x0
	size: 100x100
	pane-size: 1x1
	text: color: draw: none
	;image:
	;effect:
	data: none
	edge: none
	font: *font ; object!   [name style size color offset space align valign s...
	para: *para ; object!   [origin margin indent tabs wrap? scroll]
	when: [] ; feel object!   [redraw detect over engage]
	init: []
	;options: none
]
screen: system/view/screen-gob
screen: make proto-face [
	gob: screen
	gob/data: self
	offset: screen/offset
	size: screen/size
	flags: screen/flags

]
init screen/gob
;-----------------------
;- System Events handler
;-----------------------
drag?: off

trigger?: funco [
	{Check if a gob contains some actions}
	gob [gob!] actions [block!]
][
	if block? select gob/data 'when [
		not empty? intersect actions collect-words gob/data/when
	]
]

new-upward: funco [ ;upward
	{build function propagating action thru hierachy of gobs}
	body [block!]
][
	funct [gob offset] compose/deep [
		(body/start) until [
			(body/loop)
			not all [
				offset: offset + gob/offset
				gob: gob/parent
				not same? gob screen/gob
			]
		] (body/end)
	]
]

do-event: funco [gob action offset][do-action gob/data action]

entering: [] entered: [] away: none clicked: []

do-scroll-line: new-upward [
	loop [
		if trigger? gob [scroll-down scroll-up][
			do-event gob
				pick [scroll-up scroll-down] positive? global/offset/y
				offset
			break
		]
	]
]
do-leave-enter: new-upward [
	start [clear entering]
	loop [
		either at: find/tail entered gob [
			unless away [away: last at]
			remove-each gob at [
				do-event gob 'leave offset
				on
			]
			break
		][
			if trigger? gob [enter over away leave key]
				[insert entering gob]
		]
	]
	end [
		forall entering [do-event entering/1 'enter offset]
		append entered entering
	]
]
do-up-click: funco [offset][
	foreach gob reverse copy entered [
		do-event gob 'up offset
		if find clicked gob [
			do-event gob 'click offset
		]
	]
	clear clicked
]
do-over-away: funco [offset][
	if away [do-event away 'away offset]
	forall entered [do-event entered/1 'over offset]
]

upward: new-upward [loop [do-action gob/data action]]
sav-offset: none
event-port: system/view/event-port ;: open [scheme: 'event]
event-port/awake: funco [e][
	either find [scroll-line scroll-page] e/type [
		global: e
		action: e/type
	][
		global: e
		error: none
		;print [e/type e/offset e/flags]
		if gob? e/gob [event: map-event e]
		gob: either object? event/gob/data [event/gob][event/gob/parent]
		action: event/type
		unless object? face: gob/data [action: 'no-face]
	]
	catch/name [
		switch/default action [
			move [
				if 0x0 = rel-offset: global/offset - any [sav-offset global/offset][
					sav-offset: global/offset
					return false
				]
				do-leave-enter gob event/offset
				if drag? [do-over-away gob event/offset]
				sav-offset: global/offset
			]
			key [
				if key-face [
					key: event/key
					face: key-face
				]
				do-action face 'key
			]
			down [
				append clear clicked entered
				focus face
				upward gob event/offset
				drag?: on
			]
			up [
				away: none
				drag?: off
				do-up-click event/offset
			]
			close [
				unview 'all
			]
			right-word left-word [
				;** should be a key not an action
				key: action
				upward gob action: 'key  event/offset
			]
			key-up []
			resize [
				with global/gob/data [
					size event/offset
					resize show
				]
			]
			scroll-line [
				do-scroll-line gob e/offset
			]
		][
			print ["not taken:" action e/type e/key e/flags]
		]
		show-now
	] 'next-event
	empty? screen/gob
]

;halt-script