#!/usr/local/bin/red-view
Red [
]
#include %lib/rcvFlir.red			;--Flir camera module (redCV is not required)

;--********************** Main Program *****************************
;--Real2IR, offsetX and offsetY come from rcvGetFlirMetaData function
;--if offsetX and offsetY = "+0" alignement is not necessary
;--fileName: "images/Building.jpg" 

flirFile: 	none

loadImage: does [
	tmp: request-file 
	unless none? tmp [
		canvas1/image: canvas2/image: canvas3/image: none	
		clear f0/text
		clear f1/text
		clear f2/text
		clear model/text
		clear lens/text
		clear iscale/text
		do-events/no-wait
		flirFile: to-string tmp
		rcvGetFlirMetaData flirFile 
		canvas1/image: load tmp
		rcvGetVisibleImage flirFile
		rgb: load rgbjpg 
		canvas2/image: rgb
		offsetX: to integer! offsetX
		offsetY: to integer! offsetY
		imgRatio: 1.0 - (1.0 / Real2IR)
		cropX: to integer! rgb/size/x * imgRatio
		cropY: to integer! rgb/size/y * imgRatio
		cropXX: round/down cropX / 2 + offsetX
		cropYY: round/down cropY / 2 + offsetY
		;cropXX: (cropX // 2) + offsetX ;(r3 // is now used as integer-divide)
		;cropYY: (cropY // 2) + offsetY ;(r3 // is now used as integer-divide)
		aStart: as-pair cropXX cropYY
		aEnd: as-pair rgb/size/x - cropXX rgb/size/y - cropYY
		;--from Red/Sensei
		;img: copy/part skip rgb aStart aEnd - aStart
		;img: copy/part at rgb aStart aEnd - aStart
		canvas3/image: copy/part at rgb aStart aEnd - aStart
		;--end 
		f0/text: form canvas1/image/size
		f1/text: form canvas2/image/size
		f2/text: form canvas3/image/size
		model/text: CameraModel
		lens/text: LensModel
		iscale/text: form round/to imgRatio 0.01
	]
]


win: layout [
	title "FLIR align"
	button "Load IR Image" [loadImage]
	text "Camera Model" 
	model: field 70
	text 40 "Lens"
	lens: field 60
	text "Image Scale"
	iscale: field 
	pad 300x0
	button "Quit" [rcvCleanThermal quit]
	return
	canvas1: base 320x240
	canvas2: base 320x240
	canvas3: base 320x240
	return
	;canvas4: base 220x20 
	text 220 "FLIR Image" f0: field 90
	text 220 "Visible RGB Image" f1: field 90
	text 220 "Visible Image Alignement" f2: field 90
	at as-pair canvas1/offset/x + 160 canvas1/offset/y base 1x240 white
	at as-pair canvas1/offset/x canvas1/offset/y + 120 base 320x1 white
	at as-pair canvas2/offset/x + 160 canvas1/offset/y base 1x240 white
	at as-pair canvas2/offset/x canvas1/offset/y + 120 base 320x1 white
	at as-pair canvas3/offset/x + 160 canvas3/offset/y base 1x240 white
	at as-pair canvas3/offset/x canvas3/offset/y + 120 base 320x1 white
	
]
view win
;delete-dir %irtmp




