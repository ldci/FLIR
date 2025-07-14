## FLIR Images with Rebol3 or Red

In many medical applications, I have to process IR images from FLIR cameras such as the 650sc, which provides a 640x480 image.

**THE FLIR MODULE**

This module has been tested with different FLIR cameras. Its main function is to decode the metadata contained in any radiometric file and to extract the visible image (RGB), the infrared image (IR), the color palette associated with the IR image as well as the temperatures (in degrees °C) associated to each pixel.

This module uses two external programs :

**ExifTool** ([https://exiftool.org]()), written and maintained by Phil Harvey, is a fabulous program written in Perl that allows you to read and write the metadata of many computer files. ExifTool supports FLIR files. It works on MacOs, Linux and Windows platforms.

**ImageMagick** ([https://imagemagick.org/index.php]()) is a free software, including a library, as well as a set of command line utilities, allowing to create, convert, modify, and display images in a very large number of formats. 

**The OPENCV MODULE**

For Rebol3 users, you need OpenCV extension to play with images. [https://github.com/Oldes/Rebol-OpenCV]()

**The REDCV MODULE**

For Red users, please use RedCV library. [https://github.com/ldci/redCV
](https://github.com/ldci/redCV)
