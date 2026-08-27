#! /usr/local/bin/red-view
Red [
	Title:   "Flir PiP"
	Author:  "ldci"
	File: 	 %pip.red
	needs:   view
]
;--picture in picture FLIR mode
; required lib
#include %lib/rcvFlir.red			;--Flir camera module

flirFile: none
isFile?: false

loadImage: does [
	isFile?: false
	flirFile: request-file 
	if not none? flirFile [
		canvas1/image: canvas2/image: canvas3/image: none
		clear f0/text
		clear f1/text
		clear model/text
		clear lens/text
		clear iscale/text
		rcvGetFlirMetaData flirFile		;--mandatory 
		thermal: load flirFile			;--IR source image
		canvas1/image: thermal
		scaleFactor: 4					;--EmbeddedImage is 4 larger than RawThermalImage
		w: to-integer select meta 'embedded-image-width
		h: to-integer select meta 'raw-thermal-image-height
		imgRatio: round/floor (w / h / scaleFactor)
		if imgRatio = 0.0 [imgRatio: 1.0] 	;--avoid division by 0 error
		pipX1: to-integer select meta 'pip-x1
		pipX2: to-integer select meta 'pip-x2
		pipY1: to-integer select meta 'pip-y1
		pipY2: to-integer select meta 'pip-y2
		pipPos:  as-pair (pipX1 + pipX2) (pipY1 + pipY2)
		pipSize: as-pair (pipX1 + pipX2) * imgRatio (pipY1 + pipy2) * imgRatio
		canvas2/image: copy/part at thermal pipPos pipSize
		f0/text: form canvas1/image/size
		f1/text: form canvas2/image/size
		model/text: meta/camera-model 
		lens/text: meta/lens-model
		iscale/text: form round/to imgRatio 0.01
		canvas3/image: load rcvGetFlirPalette flirFile
		isFile?: true
		win/text: form flirFile
	]
]
win: layout [
	title "Picture in Picture Mode"
	button "Load" [loadImage]
	text "Camera Model" middle  model: field 70
	text 40 "Lens" middle lens: field 60
	text "Image Scale" middle iscale: field 
	pad 30x0
	button "Quit" [if isFile? [rcvCleanThermal] quit]
	return
	canvas1: base 320x240
	canvas2: base 320x240
	return
	canvas3: base 220x20 f0: field 90
	text 220 "Picture In Picture" f1: field 90
]
view win
