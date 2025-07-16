#!/bin/bash
DEV=/dev/video2
uvc_set() {
	echo ${PS4}uvcdynctrl -d $DEV -s ${1@Q} ${2@Q}
	uvcdynctrl -d $DEV -s "$1" "$2" 2>&1 | grep -v libwebcam >&2
	sleep .5
}
uvc_set 'Backlight Compensation' 0
uvc_set 'Power Line Frequency' 0

#uvc_set 'White Balance, Automatic' 1
uvc_set 'White Balance, Automatic' 0
uvc_set 'White Balance Temperature' 8000
# Using a custom LUT to lower Green gama and adjust Reds.
# Matching real light color temperature here end up with many values clamped at 255 on all RVB channels, as seen with Histogram source in OBS.

uvc_set 'Exposure, Dynamic Framerate' 0
uvc_set 'Auto Exposure' 0
uvc_set 'Exposure Time, Absolute' 300
uvc_set 'Gain' 23

uvc_set 'Saturation' 80
uvc_set 'Sharpness' 2

#guvcview -d $DEV -x 1920x1080 -F 30

# Got some errors with Debian 13 in 2025-07-16 but it does not affect image quality or framerate
# + uvcdynctrl -d /dev/video2 -s 'Auto Exposure' '0'
# ERROR: Unable to set new control value: A Video4Linux2 API call returned an unexpected error 22. (Code: 12)
# + uvcdynctrl -d /dev/video2 -s 'Exposure Time, Absolute' '300'
# ERROR: Unable to set new control value: A Video4Linux2 API call returned an unexpected error 13. (Code: 12)

