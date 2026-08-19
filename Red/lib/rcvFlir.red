#!/usr/local/bin/red-cli
Red [
]
;FLIR = Forward Looking Infra Red
exifTool: "exiftool"		;--exifTool: "/usr/local/bin/exiftool"
convertTool: "magick"		;--convertTool: "/usr/local/bin/magick"	
SourceFile: ""
tmpDir: none	

exifFile:  	%exif.txt		;--for decoding Flir image by exifTool
exifFile2: 	%exif.red		;--to get Rebol words
flirPal: 	copy []			;--for color palette
rgbjpg: 	"rgb.jpg"		;--Flir embedded visible image jpg
rgbpng: 	"rgb.png"		;--Flir embedded visible image png
irimg: 		"irimg.png"		;--Linear corrected Grayscale IR image
palimg: 	"palette.png"	;--Flir palette
rawimg:		"rawimg.png"	;--Corrected linear raw temperatures
tempimg:	"celsius.pgm"	;--For temperatures export 
tempBlock: 	copy []			;--For temperatures storing


rcvGetFlirMetaData: func [
"Get all Flir file metadata values as Red/Rebol words"
	fileName	[string!]	;--original Flir image
][
	;tmpDir: to-file rejoin [first split-path to-file filename "irtmp/"]
	tmpDir: %irtmp/
	if not exists? tmpDir [make-dir tmpDir]
	exifFile: to-file rejoin [tmpDir "exif.txt"]
	exifFile2: to-file rejoin [tmpDir "exif.red"]
	rgbjpg:  rejoin [tmpDir "rgb.jpg"]
	rgbpng:  rejoin [tmpDir "rgb.png"]
	irimg:   rejoin [tmpDir "irimg.png"]	
	palimg:  rejoin [tmpDir "palette.png"]
	rawimg:	 rejoin [tmpDir "rawimg.png"]
	tempimg: rejoin [tmpDir "celsius.pgm"]
	prog: copy rejoin [exifTool " -php -flir:all -q " to-local-file fileName " > " to-local-file exifFile]
	ret: call/shell/wait prog
	var: read/lines exifFile
	n: length? var
	i: 2
	write/lines exifFile2 "Red ["
	write/lines/append exifFile2 "]"
	while [i < n] [
		str: trim/with var/:i ","
		ss: split str " => "
		s: trim ss/1
		s: trim/with s #"^"" 
		vs: rejoin [s ": " ss/2]
		write/lines/append exifFile2 vs
		i: i + 1
	]
	do exifFile2
]

rcvGetVisibleImage: function [
"Get embedded visible RGB image"
	fileName	[string!]
	return: 	[image!]
][
	binstr: copy #{}
	prog: copy rejoin [exifTool " -EmbeddedImage -b " to-local-file fileName]
	ret: call/wait/shell/output prog binstr
	switch EmbeddedImageType [ 
		"PNG"  [write/binary to-file rgbpng binstr rgb: rgbpng]
		"JPG"  [write/binary to-file rgbjpg binstr rgb: rgbjpg]			
		"DAT"  [imgsize: as-pair EmbeddedImageWidth EmbeddedImageHeight
				img: make image! reduce [imgsize binstr]
				save to-file rgbjpg img rgb: rgbjpg]
	]
	rgb
]



rcvGetFlirRawData: function [
"Get Flir RAW thermal data"
	fileName	[string!]
	return:		[image!]
][
	if RawThermalImageType = "TIFF" [
		prog: copy rejoin [
			exifTool " -RawThermalImage " to-local-file fileName 
			" | " convertTool " " to-local-file rawimg
		]
	]
	;16-bit PNG JPG OR DAT format: change byte order
	if RawThermalImageType <> "TIFF" [
		size: rejoin [form RawThermalImageWidth "x" form RawThermalImageHeight]
		prog: copy rejoin [
				exifTool " -b -RawThermalImage " to-local-file fileName 
				" | " convertTool " - gray:- | " 
				convertTool " -depth 16 -endian MSB -size " size " gray:- " 
				to-local-file rawimg
			]
	]
	ret: call/shell/wait prog
	extracted?: true
	;load to-file rawimg
	rawimg
]

rcvGetPlanckValues: func [
"All the values we need for temperature computation"
][
	str: 		copy ReflectedApparentTemperature
	tmpREF: 	to-float trim/with str " C"
	RAWmax: 	RawValueMedian + (RawValueRange / 2)
	RAWmin: 	RAWmax - RawValueRange
	Kelvin: 	273.15
	;--calculate the amount of radiance of reflected objects ( Emissivity < 1 )	
	;--formula decomposition for easier arguments 
	v0: PlanckB / (tmpREF + Kelvin)
	v1: exp v0
	v1: v1 - PlanckF 
	v2: (PlanckR2 * v1) 
	RAWrefl: (PlanckR1 / v2) - PlanckO
	;--raw object min/max temperatures
	em: 1.0 - Emissivity
	RAWmaxobj: RAWmax - (em * RAWrefl) / Emissivity
	RAWminobj: RAWmin - (em * RAWrefl) / Emissivity	
	;--min and max ° values as float
	v0: log-e (PlanckR1 / (PlanckR2 * (RAWminobj + PlanckO))+ PlanckF)
	imgMinTemp: (PlanckB / v0) - Kelvin
	v0: log-e (PlanckR1 / (PlanckR2 * (RAWmaxobj + PlanckO))+ PlanckF)
	imgMaxTemp: (PlanckB / v0) - Kelvin
]

rcvGetImageTemperatures: function [
"Get a grayscale image of temperatures"
	fileName	[string!]
	return:		[image!]
][
	rcvGetFlirRawData fileName		;--we need raw data
	rcvGetPlanckValues				;--and constants
	
	;convert every rawimg-16-Bit pixel with Planck law to a temperature grayscale value
	;--Planck Law
	sMax: PlanckB / log-e (PlanckR1 / (PlanckR2 * (RAWmax + PlanckO)) + PlanckF)
	sMin: PlanckB / log-e (PlanckR1 / (PlanckR2 * (RAWmin + PlanckO)) + PlanckF)
	sDelta: sMax - sMin
	;--string form for creating mathExp as argument for convert
	R1: form PlanckR1 R2: form PlanckR2 B: form PlanckB O: form PlanckO F: form PlanckF
	ssMin: form sMin ssDelta: form sDelta
	mathExp: rejoin ["("B"/ln("R1"/("R2"*(65535*u+"O"))+"F")-"ssMin")/"ssDelta]
	;#"^"" for inserting " in convert argument
	prog: rejoin [convertTool " " to-local-file rawimg " -fx " #"^"" mathExp #"^"" " " to-local-file irimg]
	ret: call/shell/wait prog
	;--convert linear gray IR image to pgm format for temperature reading
	prog: rejoin [convertTool " " to-local-file irimg " -compress none " to-local-file tempimg]
	ret: call/shell/wait prog
	;load to-file irimg
	irimg
]

getTemperatures: func [
	fileName	[file!] ;--tempimg (format pgm)
	return:		[block!]
][
	clear tempBlock
	delta: imgMaxTemp - imgMinTemp
	f: load tempimg
	cMax: f/4
	f: skip f 4
	n: length? f
	foreach v f [
		celsius: round/to v / cMax * delta + imgMinTemp 0.0001
		append tempBlock celsius
	]
	tempBlock
]

rcvGetFlirPalette: function [
"Extract color table, swap Cb Cr and expand pal color table from [16,235] to [0,255]"
	fileName	[string!]
	return:		[image!]
][
	img: make image! reduce [224x1 gray]
	size: form img/size
	prog:  rejoin [
		exifTool  " " to-local-file fileName " -b -Palette" 
		" | " convertTool " -size " size 
		" -depth 8 YCbCr:- -separate -swap 1,2"
		" -set colorspace YCbCr -combine -colorspace RGB -auto-level " 
		to-local-file palimg
	]
	ret: call/shell/wait prog 
	;--some files don't have palette
	either ret = 0 [palimg] [img]
]

rcvMakeRedPalette: function [
"Export Flir palette values as a block"
	return:		[block!]
][
	;--make scale image for Red
	pimg: load to-file palimg
	clear flirPal	
	repeat i PaletteColors [append flirPal pimg/:i]
	flirPal		
]

rcvCleanThermal: does [
	if exists? to-red-file rgbjpg 		[delete to-file rgbjpg]
	if exists? to-red-file rgbpng 		[delete to-file rgbpng]
	if exists? to-red-file irimg  		[delete to-file irimg]
	if exists? to-red-file palimg 		[delete to-file palimg]
	if exists? to-red-file rawimg 		[delete to-file rawimg]
	if exists? to-red-file tempimg 		[delete to-file tempimg]
	if exists? to-red-file exifFile 	[delete to-file exifFile]
	if exists? to-red-file exifFile2 	[delete to-file exifFile2]
	if exists? to-red-file tmpDir 		[delete to-file tmpDir]
]



