#!/usr/local/bin/r3
Rebol [
]

cv: import 'opencv			;--opencv R3 module
do load %lib/rcvFlir.r3		;--Flir camera tools

;--********************** Main Program *****************************

;fileName: do %tools/fileSelection.r3	;--request file with Zenity
fileName: "images/RaspberryPi3.jpg"
rcvGetFlirMetaData fileName				;--Flir meta data
rcvGetVisibleImage fileName				;--IR RGB 
rcvGetImageTemperatures fileName		;--temperatures are stored in tempimg file
temperatures: getTemperatures tempimg	;--get temperatures
print ["Minimum temperature:" first find-min temperatures]
print ["Maximun temperature:" first find-max temperatures]

with cv [
	mat1: imread fileName				;--IR image
	mat2: imread rgbjpg					;--RGB image
	mat2: resize mat2 mat1/size 		;--Same size
	mat3: imread irimg					;--Grayscale image
	mat3: resize mat3 mat1/size			;--Same size
	imshow/name mat1 "IR Source" 
	imshow/name mat2 "IR RGB"
	imshow/name mat3 "IR Graysale"
	moveWindow "IR Source" 10x10
	moveWindow "IR RGB"  as-pair (mat1/size/x + 15) 10
	moveWindow "IR Graysale" as-pair (mat1/size/x * 2 + 20) 10
	waitkey 0
]

delete-dir %irtmp