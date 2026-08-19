#!/usr/local/bin/r3
REBOL [
]
cv: import opencv
do %lib/rcvFlir.r3				;--Flir camera module
;********************** Main Program *****************************

;fileName: "images/FLIR0075.jpg"
fileName: to-string request-file		;--get file as a string
thermal: load to-file fileName			;--IR source
rcvGetFlirMetaData fileName				;--Flir data
rcvGetVisibleImage fileName				;--IR RGB 
rcvGetImageTemperatures fileName		;--get temperatures
temperatures: getTemperatures tempimg	;--get temperatures 
probe length? temperatures

with cv [
	mat: 		imread/with to-file filename 1
	width: 		first get-property mat MAT_SIZE
	height:		second get-property mat MAT_SIZE 
	imgSize: 	width * height
	r: selectRoi :mat
	roi: Matrix [:mat :r]
	print ["ROI" r/1 r/2]
	sz: mat/size
	namedWindow win2: "ROI"
	imshow/name roi win2
	moveWindow win2 as-pair (sz/x + 15) 10
	
	;--now Roi temperatures
	roiTemperature: copy []
	line: r/1/y
	print line
	idx: to integer! ((line * width + r/1/x) / imgSize) * length? temperatures
	j: 0
	while [j < r/2/y][
		i: 0
		while [i < r/2/x][
			;print idx
			append roiTemperature temperatures/:idx
			++ idx 
			++ i 
		]
		++ j
		++ line
		idx: to integer! ((line * width + r/1/x) / imgSize) * length? temperatures 
	]
	;probe roiTemperature
	print ["Minimum temperature:" first find-min roiTemperature]
	print ["Maximun temperature:" first find-max roiTemperature]
	waitKey 0
]
delete-dir %irtmp
