#! /usr/local/bin/r3
REBOL [
]
getFile: func [] [
	fileName: ""
	prog: "zenity"
	commands: [
		" --file-selection"
		" --title 'Select an image'"
	] 
	append prog commands
	call/shell/output prog fileName
	filename: trim/lines fileName
]
