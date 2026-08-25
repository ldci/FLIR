#!/usr/local/bin/r3
Rebol [
]
;--same as Red
cv: import 'opencv			;--opencv R3 module
do %lib/rcvFlir.r3			;--Flir camera module

;--********************** Main Program *****************************
;--Real2IR, offsetX and offsetY come from rcvGetFlirMetaData function
;--if offsetX and offsetY = "+0" alignement is not necessary
;-- The code is perfect now
axes: function [file [file!]]
[
	img: load file
	cx: img/size/x / 2
	cy: img/size/y / 2
	change/dup skip img as-pair 0 cy white as-pair img/size/x 1
	repeat i img/size/y [
		offset: as-pair cx i
		img/:offset: white
	]
	img
]

fileName: to-string request-file	;--get file as a string
rcvGetFlirMetaData fileName			;--get metadata
rcvGetVisibleImage fileName			;--binary values in rgbjpg file
rgb: load rgbjpg 					;--Load RGB image
offsetX: to integer! offsetX
offsetY: to integer! offsetY
imgRatio: 1.0 - (1.0 / Real2IR)
cropXY:  to-pair rgb/size * imgRatio 
offXY:  as-pair OffsetX OffsetY	
imgOff:  to-pair cropXY / 2 + offXY	                        	
imgSz:   rgb/size - cropXY
aLigned: reduce [imgOff imgSz]

with cv [
	mat1: imread fileName			;--IR image
	mat2: imread rgbjpg				;--RGB image
	mat3: Matrix [:mat2 :aLigned]	;--RGB alignement
	imwrite %irtmp/axes.jpg mat3
	print ["IR:" mat1/size "RGB:" mat2/size "Aligned:" mat3/size]
	mat1: axes to-file fileName
	mat2: axes to-file rgbjpg
	mat3: axes %irtmp/axes.jpg
	mat1: resize mat1 320x240 6		;--Same size (INTER_NEAREST_EXACT)
	mat2: resize mat2 320x240 6		;--Same size (INTER_NEAREST_EXACT)
	mat3: resize mat3 320x240 6		;--Same size (INTER_NEAREST_EXACT) 
	imshow/name mat1 "Source IR" 
	imshow/name mat2 "RGB"
	imshow/name mat3 "Aligned RGB-IR"
	moveWindow "Source IR" 10x10
	moveWindow "RGB"  as-pair (mat1/size/x + 15) 10
	moveWindow "Aligned RGB-IR" as-pair (mat1/size/x * 2 + 20) 10
	waitkey 0
]
delete-dir %irtmp



