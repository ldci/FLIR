#!/usr/local/bin/r3
Rebol [
]

cv: import 'opencv			;--opencv R3 module
do load %lib/rcvFlir.r3		;--Flir camera tools

;--********************** Main Program *****************************
;--Real2IR, offsetX and offsetY come from rcvGetFlirMetaData function
;--if offsetX and offsetY = "+0" alignement is not necessary
;fileName: do %tools/fileSelection.r3  
fileName: "images/Building.jpg" 
rcvGetFlirMetaData fileName
rcvGetVisibleImage fileName
rgb: load rgbjpg 
offsetX: to integer! offsetX
offsetY: to integer! offsetY
imgRatio: 1.0 - (1.0 / Real2IR)
cropX: to integer! rgb/size/x * imgRatio
cropY: to integer! rgb/size/y * imgRatio
aStart: as-pair (round/floor cropX / 2) + offsetX  (round/floor cropY / 2) + offsetY
aEnd: as-pair rgb/size/x - (round/floor cropx / 2) + offsetX rgb/size/y - (round/floor cropy / 2) + offsetY
aligned: reduce [aStart aEnd - aStart]

with cv [
	mat1: imread fileName			;--IR image
	mat2: imread rgbjpg				;--RGB image
	mat3: Matrix [:mat2 :aligned]	;--RGB alignement
	mat1: resize mat1 320x240 6		;--Same size (INTER_NEAREST_EXACT)
	mat2: resize mat2 320x240 6		;--Same size (INTER_NEAREST_EXACT)
	mat3: resize mat3 320x240 6		;--Same size (INTER_NEAREST_EXACT) 
	imshow/name mat1 "Source IR" 
	imshow/name mat2 "RGB"
	imshow/name mat3 "Align RGB-IR"
	moveWindow "Source IR" 10x10
	moveWindow "RGB"  as-pair (mat1/size/x + 15) 10
	moveWindow "Align RGB-IR" as-pair (mat1/size/x * 2 + 20) 10
	waitkey 0
]
delete-dir %irtmp



