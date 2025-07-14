#!/usr/local/bin/r3
Rebol [
]
cv: import 'opencv

fileName: "video_input.mp4"

with cv [
    movie: VideoCapture %video/video_input.mp4 
    print ["Width :" w: get-property :movie CAP_PROP_FRAME_WIDTH]
    print ["Height:" h: get-property :movie CAP_PROP_FRAME_HEIGHT]
    print ["FPS   :" fps: get-property :movie CAP_PROP_FPS]
    print ["Frames:" nbFrames: to integer! get-property :movie CAP_PROP_FRAME_COUNT]
    print ["Format:" get-property :movie CAP_PROP_FORMAT]
    delay: 1.0 / fps
    minutes: to integer! nbFrames / fps / 60
    seconds: nbFrames / fps % 60
    ms: rejoin [form minutes ":" form seconds]
    print["Duration [M:S]:" ms]
    unless movie [quit]
    frame: read :movie      ;? frame ;; should be a cvMat handle
    if frame [
    	count: 1
        forever [
            read/into :movie :frame ;; reusing existing frame
            mat1: cvtColor :frame none COLOR_BGR2RGB	
            mat2: cvtColor :frame none COLOR_RGB2GRAY	;--1 channel CV_8UC1 grayscale
            mat3: threshold :mat2 none 0 255 THRESH_BINARY
            m1: round/to (mean :mat2) 0.01
            m2: round/to (mean :mat3) 0.01
            fahr: (m2 - m1) / 3.15 				;--depending upon the camera hardware
            cent: (5.0 / 9.0) * (fahr - 32.0)	;--degrees Celsius
            print[ rejoin ["Frame: " count ": " round/to cent 0.01] ] 
            applyColorMap :mat2 :mat2 COLORMAP_HOT	;--3 channels mat
            imshow :mat2
            k: pollKey            ;; check if there was any key pressed
            if k = 27 [break]     ;; exit on ESC key
            wait delay            ;; let Rebol breath as well
            count: count + 1
            if count = nbFrames [break]
        ]  
    ]
   	waitKey 0
    print "closing.."
    free :movie
    print "done"
]
