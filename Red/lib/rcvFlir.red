#!/usr/local/bin/red-cli
Red [
]
;FLIR = Forward Looking Infra Red
exifTool: "exiftool"		;--exifTool: "/usr/local/bin/exiftool"
convertTool: "magick"		;--convertTool: "/usr/local/bin/magick"	
tmpDir: none	
flirPal: 	copy []			;--for color palette
rgbjpg: 	"rgb.jpg"		;--Flir embedded visible image jpg
rgbpng: 	"rgb.png"		;--Flir embedded visible image png
irimg: 		"irimg.png"		;--Linear corrected Grayscale IR image
palimg: 	"palette.png"	;--Flir palette
rawimg:		"rawimg.png"	;--Corrected linear raw temperatures
tempimg:	"celsius.pgm"	;--For temperatures export 
tempBlock: 	copy []			;--For temperatures storing
AllMeta?: 	false			;--just FLIR metadata

;--Thanks to Red/Sensei for get-flir-meta function
parse-exif: func [
    "Convertit une sortie texte ExifTool en map! (clés en word!)"
    str [string!]
    /local out line key val
][
    out: make map! 100
    ; Charset des caractères valides pour un mot (lettres, chiffres, tiret)
    valid-chars: charset [#"a" - #"z" #"A" - #"Z" #"0" - #"9" #"-"]
    process-line: func [line][
        line: trim/head/tail line
        if parse line [
            copy key to " : " 
            " : " 
            copy val to end
        ][
            key: trim/head/tail key
            ; Remplace les espaces par des tirets
            replace/all key " " "-"
            ; Remplace tout caractère non valide par un tiret
            replace/all key complement valid-chars "-"
            ; Convertit en word! (en minuscules pour faire joli)
            put out to-word lowercase key trim/head/tail val
        ]
    ]
    
    parse str [
        any [
            copy line thru "^/" (process-line line)
        ]
        copy line to end (process-line line)
    ]
    out
]

; --- Fonction globale combinant l'appel et le parsing ---
get-flir-meta: func [
    "Extrait et parse les métadonnées FLIR d'une image"
    img [file!]
    /local cmd out
][
    ; Buffer pour capturer la sortie d'exiftool
    out: make string! 10'000
    ; Construction de la commande (to-local-file gère les chemins Windows)
    cmd: rejoin ["exiftool -flir:all -q " to-local-file img] 	;--only FLIR
   	if allMeta? [cmd: rejoin ["exiftool " to-local-file img]]	;--All  metadata   
    ; Appel système
    call/output cmd out
    ; On transforme le texte brut en map! structuré
    parse-exif out
]

rcvGetFlirMetaData: func [
"Get all Flir file metadata values as Red words"
	fileName	[file!]	;--original Flir image
][
	tmpDir: %irtmp/
	if not exists? tmpDir [make-dir tmpDir]
	rgbjpg:  rejoin [tmpDir "rgb.jpg"]
	rgbpng:  rejoin [tmpDir "rgb.png"]
	irimg:   rejoin [tmpDir "irimg.png"]	
	palimg:  rejoin [tmpDir "palette.png"]
	rawimg:	 rejoin [tmpDir "rawimg.png"]
	tempimg: rejoin [tmpDir "celsius.pgm"]
	meta: get-flir-meta fileName
]

rcvGetVisibleImage: function [
"Get embedded visible RGB image"
	fileName	[file!]
	return: 	[image!]
][
	binstr: copy #{}
	prog: copy rejoin [exifTool " -EmbeddedImage -b " to-local-file fileName]
	ret: call/wait/shell/output prog binstr
	switch meta/embedded-image-type [ 
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
	fileName	[file!]
	return:		[image!]
][
	if meta/raw-thermal-image-type = "TIFF" [
		prog: copy rejoin [
			exifTool " -RawThermalImage " to-local-file fileName 
			" | " convertTool " " to-local-file rawimg
		]
	]
	;16-bit PNG JPG OR DAT format: change byte order
	if meta/raw-thermal-image-type <> "TIFF" [
		size: rejoin [form meta/raw-thermal-image-width "x" form meta/raw-thermal-image-height]
		prog: copy rejoin [
				exifTool " -b -RawThermalImage " to-local-file fileName 
				" | " convertTool " - gray:- | " 
				convertTool " -depth 16 -endian MSB -size " size " gray:- " 
				to-local-file rawimg
			]
	]
	ret: call/shell/wait prog
	extracted?: true
	rawimg
]

rcvGetPlanckValues: func [
"All the values we need for temperature computation"
][
	str: 		copy meta/reflected-apparent-temperature
	tmpREF: 	to-float trim/with str " C"
	RawValueMedian: to-float select meta 'raw-value-median
	RawValueRange: to-float select meta 'raw-value-range
	RAWmax: 	RawValueMedian + (to-float RawValueRange / 2)
	emissivity: to-float select meta 'emissivity
	RAWmin: 	RAWmax - to-float meta/raw-value-range
	Kelvin: 	273.15
	PlanckR1: to-float select meta 'Planck-R1
	PlanckR2: to-float select meta 'Planck-R2
	PlanckB:  to-float select meta 'Planck-B
	PlanckO:  to-float select meta 'Planck-O
	PlanckF:  to-float select meta 'Planck-F
	;--calculate the amount of radiance of reflected objects ( Emissivity < 1 )	
	;--formula decomposition for easier arguments 
	v0: PlanckB / (tmpREF + Kelvin)
	v1: exp v0
	v1: v1 - PlanckF 
	v2: (PlanckR2 * v1) 
	RAWrefl: (PlanckR1 / v2) - PlanckO
	;--raw object min/max temperatures
	em: 1.0 - emissivity
	RAWmaxobj: RAWmax - (em * RAWrefl) / emissivity
	RAWminobj: RAWmin - (em * RAWrefl) / emissivity	
	;--min and max ° values as float
	v0: log-e (PlanckR1 / (PlanckR2 * (RAWminobj + PlanckO))+ PlanckF)
	imgMinTemp: (PlanckB / v0) - Kelvin
	v0: log-e (PlanckR1 / (PlanckR2 * (RAWmaxobj + PlanckO))+ PlanckF)
	imgMaxTemp: (PlanckB / v0) - Kelvin
]

rcvGetImageTemperatures: function [
"Get a grayscale image of temperatures"
	fileName	[file!]
	return:		[image!]
][
	rcvGetFlirRawData fileName		;--mandatory
	rcvGetPlanckValues				;--and Planck's constants
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
	fileName	[file!]
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
	fileName	[file!]
	return:		[block!]
][
	;--make scale image for Red
	pimg: rcvGetFlirPalette fileName
	;pimg: load to-file tempo
	clear flirPal	
	repeat i length? pimg [append flirPal pimg/:i]
	flirPal		
]

rcvCleanThermal: does [
	if exists? to-red-file rgbjpg 		[delete to-file rgbjpg]
	if exists? to-red-file rgbpng 		[delete to-file rgbpng]
	if exists? to-red-file irimg  		[delete to-file irimg]
	if exists? to-red-file palimg 		[delete to-file palimg]
	if exists? to-red-file rawimg 		[delete to-file rawimg]
	if exists? to-red-file tempimg 		[delete to-file tempimg]
	if exists? tmpDir 					[delete tmpDir]
]

