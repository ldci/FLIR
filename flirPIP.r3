#!/usr/local/bin/r3
REBOL [
]
;--for all Flir images (320x240 or 640x480)

;--********************** Main Program *****************************
do load %lib/rcvFlir.r3				;--Flir camera tools
;fileName: do %tools/fileSelection.r3 
fileName: "images/FLIR0042.jpg"
thermal: load to-file fileName		;--IR source image
rcvGetFlirMetaData fileName			;--get FLIR data
scaleFactor: 4						;--EmbeddedImage is 4 larger than RawThermalImage
imgRatio: round/floor (EmbeddedImageWidth / RawThermalImageWidth / scaleFactor) 
pipPos:  as-pair (PiPX1 + PiPX2) (PiPY1 + PiPY2)
pipSize: as-pair (PiPX1 + PiPX2) * imgRatio (PiPY1 + PiPY2) * imgRatio
if any 	[pipPos/x + pipSize/x > thermal/size/x pipPos/y + pipSize/y > thermal/size/y]
		[pipPos: 0x0 pipSize: thermal/size]
pip: reduce [pipPos pipSize]

;--use opencv module
cv: import 'opencv
with cv [
	mat1: imread fileName
	mat2: Matrix [:mat1 :pip]
	imshow/name mat1 fileName
	imshow/name mat2 "PiP"
	moveWindow fileName 10x10
	moveWindow "PiP" as-pair (mat1/size/x + 15) 10
    waitKey 0
]
delete-dir %irtmp
