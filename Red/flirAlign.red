#!/usr/local/bin/red-view
Red [
	author: ldci
]
#include %lib/rcvFlir.red			;--Flir camera module (redCV is not required)

;--********************** Main Program *****************************
;--Real2IR, offsetX and offsetY come from rcvGetFlirMetaData function
;--if offsetX and offsetY = "+0" alignement is not necessary
;--Thanks to Red/Sensei for alignement optimisation
;-- The code is perfect now

isFile?: false
loadIRImage: does [
	isFile?: false
	tmp: request-file 
	unless none? tmp [
		canvas1/image: canvas2/image: canvas3/image: none	
		clear f0/text clear f1/text clear f2/text
		clear model/text clear lens/text clear iscale/text
		flirFile: to-string tmp
		rcvGetFlirMetaData flirFile 
		rcvGetVisibleImage flirFile
		canvas1/image: load tmp
		canvas2/image: rgb: load rgbjpg 
		imgRatio: 1.0 - (1.0 / Real2IR)
		OffsetX: to-integer OffsetX
		OffsetY: to-integer OffsetY
		cropXY:  to-pair rgb/size * imgRatio 
		offXY:  as-pair OffsetX OffsetY					;-- as-pair is OK 
		imgOff:  to-pair cropXY / 2 + offXY	                        	
		imgSz:   rgb/size - cropXY
		canvas3/image: copy/part at rgb imgOff imgSz 	;--copy/part requires pair values!
		f0/text: form canvas1/image/size
		f1/text: form canvas2/image/size
		f2/text: form canvas3/image/size
		model/text: CameraModel
		lens/text: LensModel
		iscale/text: form round/to imgRatio 0.01
		isFile?: true
	]
]

view win: layout [
	title "FLIR images alignement"
	button "Load IR Image" [loadIRImage]
	text "Camera Model" middle
	model: field 70
	text 40 "Lens" middle
	lens: field 60
	text "Image Scale" middle
	iscale: field 
	pad 300x0
	button "Quit" [if isFile? [rcvCleanThermal] quit]
	return
	canvas1: base 320x240
	canvas2: base 320x240
	canvas3: base 320x240
	return
	text 220 middle "FLIR Image"  f0: field 90 center
	text 220 middle "Visible RGB Image"  f1: field 90 center
	text 220 middle "Aligned Visible Image" f2: field 90 center 
	;--draw axes
	at as-pair canvas1/offset/x + 160 canvas1/offset/y base 1x240 white
	at as-pair canvas1/offset/x canvas1/offset/y + 120 base 320x1 white
	at as-pair canvas2/offset/x + 160 canvas2/offset/y base 1x240 white
	at as-pair canvas2/offset/x canvas2/offset/y + 120 base 320x1 white
	at as-pair canvas3/offset/x + 160 canvas3/offset/y base 1x240 white
	at as-pair canvas3/offset/x canvas3/offset/y + 120 base 320x1 white
]




