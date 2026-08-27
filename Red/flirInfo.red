#!/usr/local/bin/red-view
Red [
	author: ldci
]
#include %lib/rcvFlir.red			;--Flir camera module (redCV is not required)
getMetadata: does [
	clear tl/data
	meta: rcvGetFlirMetaData flirFile 	;--mandatory
	lines: make block! length? meta
	foreach key keys-of meta [
    	append lines rejoin [key ": " select meta key]
	]
	tl/data: lines
]

loadIRImage: does [
	flirFile: request-file 
	unless none? flirFile [
		canvas/image: load flirFile
		getMetadata
	]
	win/text: form flirFile
]

view win: layout [
	title "FLIR metadata"
	button "Load IR Image" [
		tt: dt [loadIRImage] 
		ft/text: rejoin [form round/to (third tt) 0.01 " sec"]
	]
	check "All metadata" [AllMeta?: face/data getMetadata]
	text middle "Processed in:"
	ft: field 102 center
	pad 150x0
	button "Quit" [quit]
	return
	canvas: base 320x240
	tl: text-list 320x240 font-color white data []
]