#! /usr/local/bin/red-view
Red [
	Title:   "Flir Read"
	Author:  "ldci"
	File: 	 %flirRead.red
	needs:   view
]

;--basic FLIR Images reading
; required libs
#include %lib/rcvFlir.red			;--Flir camera module


flirFile: 	none
isSorted?: 	false
isFile?: false

loadImage: does [
	tmp: request-file 
	isFile?: false
	unless none? tmp [
		clear tempList/data
		clear f0/text
		clear f1/text
		clear f2/text
		cb1/data: isSorted?
		canvas1/image: canvas2/image: none
		canvas3/image: canvas0/image: none
		do-events/no-wait
		flirFile: to-string tmp	
		rcvGetFlirMetaData flirFile 		
		canvas1/image: load tmp
		attempt [canvas0/image: load rcvGetFlirPalette flirFile]
		attempt [canvas2/image: load rcvGetVisibleImage flirFile]
		attempt [canvas3/image: load rcvGetImageTemperatures flirFile]
		b/text: CameraModel
		b2/text: PaletteName
		f0/text: form canvas1/image/size
		f1/text: form canvas2/image/size
		f2/text: form canvas3/image/size
		f3/text: DateTimeOriginal
		isFile?: true
	]
]

ImageTemperatures: does [
	clear tempList/data
	tempBlock:  getTemperatures tempimg
	blk: make block! []		
	repeat i length? tempBlock [append blk form round/to tempBlock/:i 0.01 ]
	if isSorted? [sort blk]
	tempList/data: blk
]

view layout [
	title "FLIR Images Reader"
	button "Load" 	[loadImage]
	text 60 "Camera" middle
	b: field 100
	text 60 "Palette" middle
	b2: field 100 center
	canvas0: base 215x22
	cb1: check 150 "Sort Temperatures" false [isSorted?: face/data]
	button 150 "Show Temperatures" [ImageTemperatures]
	pad 25x0
	button "Quit" 	[if isfile? [rcvCleanThermal] quit]
	return
	canvas1: base 320x240				;--IR image
	canvas2: base 320x240				;--RGB image
	canvas3: base 320x240				;--Raw image
	tempList: text-list 100x240 data []	;--temperatures list
	return
	t: text 220 "FLIR Image "
	f0: field 90x21 center
	text 220 "Visible Embedded Image " f1: field 90x21 center
	text 220 "Grayscale Temperature Image" f2: field 90x21 center
	text 100 "Temperatures"
	return
	text "Date" f3: field 230
]


