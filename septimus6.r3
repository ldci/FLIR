#!/usr/local/bin/r3
REBOL [
]
cv: import 'opencv								;--opencv module
b2d: import 'blend2d							;--blend2d module
do %lib/rcvFlir.r3								;--Flir module
delete?: no										;--suppress all temporary files ?
save?: no										;--save results?
fileName: request-file/title/filter "Select an image" [%jpg %jpeg];--get file  
print fileName									;--file name
saveName: copy fileName
replace saveName suffix? saveName ".txt"
print saveName
saveRoiFile: copy fileName
replace saveRoiFile suffix? saveRoiFile ".png"
print saveRoiFile
rShortName: second split-path filename
rcvGetFlirMetaData to string! fileName			;--get FLIR metadata
rcvGetVisibleImage to string! fileName			;--binary values in rgbjpg file
rcvGetImageTemperatures to string! fileName		;--get temperatures
temperatures: getTemperatures tempimg			;--get temperatures as block
f: load %irtmp/celsius.pgm						;--raw data 16-bit values
ftype: f/1 rawW: f/2 rawH: f/3 cmax: f/4		;--raw image header
rgb: load %irtmp/rgb.jpg 
shortName: copy filename
replace shortName suffix? shortName ""
rgbName: rejoin [shortName "_rgb"".jpg"]

cspace: 2 ;1 ou 2
with cv [
	img: imread fileName						;--IR image
	print ["mat size    :" size: get-property img MAT_SIZE]
	width: size/x height: size/y
	vect: get-property img MAT_VECTOR
	
	;--IR Pseudo Color (1)
	m3: copy []  ;--3 channels image
	knl: #(f32! [
    	0.5 0.0 0.5 
    	0.0 0.5 0.0 
    	0.5 0.0 0.5
	])
	
	foreach [r g b] vect [
		xf: (r * knl/1) + (g *  knl/2) + (b * knl/3)
    	yf: (r * knl/4) + (g *  knl/5) + (b * knl/6)
    	zf: (r * knl/7) + (g *  knl/8) + (b * knl/9)	
		append m3  to integer! xf
		append m3  to integer! yf
		append m3  to integer! zf
	]
	im: make image! reduce [size to-binary m3]
    mat1: Matrix :im
    
    ;--YCrCb color (2)
	mat2: Matrix [:size CV_8UC3]
	cvtColor :img :mat2 COLOR_RGB2YCrCb  
	
	if cspace = 1 [r: selectRoi :mat1 roi: Matrix [:mat1 :r]]	
	if cspace =	2 [r: selectRoi :mat2 roi: Matrix [:mat2 :r]]
	print ["ROI position and size in image" roi1: r/1 roi2: r/2]
	
	;--calculate coordinates for raw image
	roi1/x: round r/1/x / width * rawW
	roi1/y: round r/1/y / height * rawH
	roi2/x: round r/2/x / width * rawW
	roi2/y: round r/2/y / height * rawH
	print ["ROI position and size in Raw Image" roi1 roi2]					
	
	;--now get temperatures in ROI 
	blk: copy []
	line: to integer! roi1/y - 1				;--first Roi line
	idx: to integer! line * rawW + roi1/x		;--index of °value in Rawdata
	repeat j roi2/y [
		repeat i roi2/x [
		;print [line i idx]
			append blk round/to temperatures/:idx 0.01
			++ idx								;--increment idx
		]
		++ line									;--next Roi line
		idx: to integer! line * rawW + roi1/x	;--new idx for the new line
	]
	
	;--we use a 64-bit float vector for statistics
	v: make vector! compose/only [f64! (length? blk) (blk)]
	roi: resize roi 400% 4						;--a big zoom
	;roi: bilateralFilter :roi none 5 20.0 20.0	;--apply bilateral filter
	;--minMaxLoc requires a single channel image
	imwrite %irtmp/roi.png roi					;--save ROI image
	roiImg: imread/image %irtmp/roi.png 		;--read as a Rebol image
	img: Matrix :roiImg							;--create a RGB matrix from ROI
	gs:  Matrix :img							;--and a gs matrix
	cvtColor :img :gs COLOR_RGB2GRAY			;--a grayscale image for minMaxLoc (1 channel)
	b: minMaxLoc gs								;--get min max in gs image (a block)
	minLoc: b/3 maxLoc: b/4						;--get Min Max location

	;--use blend2d code
	texture: b2d/image %irtmp/roi.png roiImg
	code: [
		font %/System/Library/Fonts/Geneva.ttf
		fill :texture
		box 0x0 roi/size
		fill blue pen blue circle minLoc 8 
		fill red pen red circle maxLoc 8
		line-width 3 pen white
		line 
	]
	append code reduce [minLoc maxLoc]
	str0: form rShortName
	str1: rejoin ["Mini:" v/minimum]
	str2: rejoin ["Maxi:" v/maximum]
	append code reduce ['fill white 'text 10x20 10 str0]
	append code reduce ['fill blue 'text 10x35 12 str1]
	append code reduce ['fill red  'text 10x50 12 str2]
	tRoi: b2d/draw roi/size :code			;--draw the result image
	;--use openCV
	imwrite %irtmp/roi.png tRoi				;--save the result image
	namedWindow matR: rShortName
	imshow/name tRoi matR
	moveWindow matR as-pair 325 0
	
	print ["Min: 	 " v/minimum]								;--minimal value
	print ["Max: 	 " v/maximum]								;--maximal value
	print ["Delta: 	 " v/range]									;--delta
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
	write/append/lines saveName ajoin ["Min:    " v/minimum]
	write/append/lines saveName ajoin ["Max:    " v/maximum]
	write/append/lines saveName ajoin ["Delta:  " v/range]
	write/append/lines saveName ajoin ["Mean:   " round/to v/mean 0.01]
	write/append/lines saveName ajoin ["Median: " round/to v/median 0.01]
	write/append/lines saveName ajoin ["STD:    " round/to v/sample-deviation 0.01]
	saveRoiFile: to-file saveRoiFile
	cv/imwrite saveRoiFile tRoi
	print rgbName
	cv/imwrite rgbName rgb
	print "Done"
]

if delete? [delete-dir %irtmp]
