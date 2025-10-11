#!/usr/local/bin/r3
REBOL [
]
;--Color map types: a block of words
maps: [
	COLORMAP_AUTUMN
	COLORMAP_BONE
	COLORMAP_JET
	COLORMAP_WINTER
	COLORMAP_RAINBOW
	COLORMAP_OCEAN
	COLORMAP_SUMMER
	COLORMAP_SPRING
	COLORMAP_COOL
	COLORMAP_HSV
	COLORMAP_PINK
	COLORMAP_HOT
	COLORMAP_PARULA
	COLORMAP_MAGMA
	COLORMAP_INFERNO
	COLORMAP_PLASMA
	COLORMAP_VIRIDIS
	COLORMAP_CIVIDIS
	COLORMAP_TWILIGHT
	COLORMAP_TWILIGHT_SHIFTED
	COLORMAP_TURBO
	COLORMAP_DEEPGREEN
]

cv: import 'opencv								;--opencv module
do %lib/rcvFlir.r3								;--Flir module
isFilter?: yes									;--sharp filter (3x3)
filter5x5?: no									;--5x5 filter ?
delete?: no										;--suppress all temporary files
save?: no
fileName: to-string request-file				;--get file as a string
print fileName									;--file name
saveName: copy fileName
replace saveName suffix? saveName ".txt"
print saveName
rcvGetFlirMetaData fileName						;--get metadata
rcvGetVisibleImage fileName						;--binary values in rgbjpg file
rcvGetImageTemperatures fileName				;--get temperatures
rgb: load rgbjpg 								;--load RGB image
temperatures: getTemperatures tempimg			;--get temperatures as block
f: load %irtmp/celsius.pgm						;--raw data 16-bit values
ftype: f/1 rawW: f/2 rawH: f/3 cmax: f/4		;--raw image header
print ["RGB Image Size:" EmbeddedImageWidth EmbeddedImageHeight]
print ["Raw Image Size:" rawW rawH]
;--all we need for alignement from FLIR meta data
offsetX: to integer! offsetX
offsetY: to integer! offsetY
imgRatio: 1.0 - (1.0 / Real2IR)
cropX: to integer! rgb/size/x * imgRatio
cropY: to integer! rgb/size/y * imgRatio
aStart: as-pair (round/floor cropX / 2) + offsetX  (round/floor cropY / 2) + offsetY
aEnd: as-pair rgb/size/x - (round/floor cropx / 2) + offsetX rgb/size/y - (round/floor cropy / 2) + offsetY
aLigned: reduce [aStart aEnd - aStart]
print ["Aligned RGB:" aStart aEnd]
with cv [
	mat1: imread fileName						;--IR image
	mat2: imread rgbjpg							;--RGB image
	mat3: Matrix [:mat2 :aLigned]				;--use RGB aligned image
	width: first get-property mat3 MAT_SIZE		;--RGB aligned width
	height: second get-property mat3 MAT_SIZE 	;--RGB aligned height
	r: selectRoi :mat3							;--select ROI
	roi: Matrix [:mat3 :r]						;--make ROI matrix
	print ["ROI position and size in RGB image" roi1: r/1 roi2: r/2]
	if any [width <> rawW height <> rawH][
		roi1/x:  round r/1/x / width * rawW
		roi1/y:  round r/1/y / height * rawH
		roi2/x:  round r/2/x / width * rawW
		roi2/y:  round r/2/y / height * rawH
	]
	print ["ROI position and size in Raw Image" roi1 roi2]
	i: 1
	blk: copy []
	y: 0												
	while [y < rawH][
		x: 0
		while [x < rawW][
			pos: as-pair x y
			;--get temperature only in ROI according to position and size	
			if all [pos/x > roi1/x pos/y > roi1/y pos/x < (roi1/x + roi2/x) pos/y < (roi1/y + roi2/y)]
			[append blk temperatures/:i]
			++ i
			++ x
		]
		++ y 
	]
	roi: resize roi 250% 6						;--a big zoom
	applyColorMap :roi :roi COLORMAP_HOT		;--IR color map
	;--Sharp filter with a 5x5 or 3x3 kernel
	if isFilter? [
		either filter5x5? [
			kernel: #(f32! [-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 25 
			-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1])
			filter: Matrix [CV_32FC1 5x5 :kernel]
		][
			kernel: #(f32! [-1 -1 -1 -1 9 -1 -1 -1 -1])
			filter: Matrix [CV_32FC1 3x3 :kernel]
		]
		filter2D :roi :roi -1 filter -1x-1 0
	]
	
	;--minMaxLoc requires a single channel image
	imwrite %irtmp/roi.png roi				;--save ROI image
	roiImg: imread/image %irtmp/roi.png 	;--read as a Rebol image
	img: Matrix :roiImg						;--create a RGB matrix
	im: get-property :img MAT_IMAGE
	cMin: first find-min im
	cMax: first find-max im
	print [cMin cMax]
	gs:  Matrix :img						;--and a gs matrix
	cvtColor :img :gs COLOR_RGB2GRAY		;--a grayscale image for minMaxLoc
	b: minMaxLoc gs							;--get min max in gs image (a block)
	minLoc: b/3 maxLoc: b/4					;--get Min Max location
	change/dup at roiImg maxLoc white 10x10	;--update image max value
	;imwrite %irtmp/roi.png roiImg			;--save the result image
	namedWindow mat2: "ROI"
	imshow/name roiImg mat2
	moveWindow mat2 as-pair (mat1/size/x + 150) 0
	;--we use a float vector for stats
	v: make vector! compose/only [f32! (length? blk) (blk)]
	;probe v
	print ["Min: 	 " round/to v/minimum 0.01]					;--minimal value
	print ["Max: 	 " round/to v/maximum 0.01]					;--maximal value
	print ["Delta: 	 " round/to v/range 0.01]					;--delta
	print ["Mean:    " round/to v/mean 0.01]					;--mean
	print ["Median:  " round/to v/median 0.01]					;--median
 	print ["STDs:    " round/to v/sample-deviation 0.01]		;--STD sample
	print ["STDp:    " round/to v/population-deviation 0.01]	;--STD Population
	print "Any key to close"
	waitkey 0
]
if save? [
print "Saving data"
saveName: to-file saveName
write/lines saveName "Forward Looking Infra Red"
write/append/lines saveName ajoin ["Model:  " CameraModel]
write/append/lines saveName ajoin ["Serial: " CameraSerialNumber]
write/append/lines saveName ajoin ["Lens:   " LensModel]
write/append/lines saveName DateTimeOriginal
write/append/lines saveName ajoin ["Pixels: " v/length]
write/append/lines saveName ajoin ["ROI:    " r]
write/append/lines saveName ajoin ["Min:    " round/to v/minimum 0.01]
write/append/lines saveName ajoin ["Max:    " round/to v/maximum 0.01]
write/append/lines saveName ajoin ["Delta:  " round/to v/range 0.01]
write/append/lines saveName ajoin ["Mean:   " round/to v/mean 0.01]
write/append/lines saveName ajoin ["Median: " round/to v/median 0.01]
write/append/lines saveName ajoin ["STD:    " round/to v/sample-deviation 0.01]
]

if delete? [delete-dir %irtmp]


