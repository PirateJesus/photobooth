#!/bin/bash

SHUTTER=23
HALT=7
LED=24
EVENT=rvmmf16

# Initialize GPIO states
gpio -g mode  $SHUTTER up
gpio -g mode  $HALT    up
gpio -g mode  $LED     out

# Flash LED on startup to indicate ready state
for i in `seq 1 5`;
do
	gpio -g write $LED 1
	sleep 0.2
	gpio -g write $LED 0
	sleep 0.2
done   

while :
do
	# Check for shutter button
	if [ $(gpio -g read $SHUTTER) -eq 0 ]; then
		gpio -g write $LED 1
		echo "Running photo process"
		
		#Print marketing message
		echo "Welcome to #RVMMF\\nDownload your photo at:\\nroguehacklab.com/photobooth/\\n" > /dev/ttyAMA0
		
		#set file name to save as
		PICID=$(cat /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
		#avoid duplicates by checking if file exists
		while [ -e ./events/$EVENT/$PICID.jpg ]
		do
			echo "File $PICID.jpg exists picking a new name"
			PICID=$(cat /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
		done
		
		#take picture - https://www.raspberrypi.org/documentation/raspbian/applications/camera.md
		raspistill -n -t 100 -e jpg -o ./events/$EVENT/$PICID.jpg
		echo "Photo saved to ./events/$EVENT/$PICID.jpg"
		
		#print picture
		lpr -o fit-to-page ./events/$EVENT/$PICID.jpg
		#raspistill -n -t 200 -w 512 -h 384 -o - | lp
		
		#check for internet to sync photos
		if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
		  echo "IPv4 is up - syncing photos"
		  #rsync ./events/$EVENT/ photobooth@srv.roguehacklab.com/events/$EVENT
		else
		  echo "IPv4 is down - no sync"
		fi
		
		#Wait for printout to finish before allowing more photos
		#while [ lpq -eq 0 ]; do continue; done		

		# Wait for user to release button before resuming
		while [ $(gpio -g read $SHUTTER) -eq 0 ]; do continue; done
		gpio -g write $LED 0
	fi

	# Check for halt button
	if [ $(gpio -g read $HALT) -eq 0 ]; then
		# Must be held for 2+ seconds before shutdown is run...
		starttime=$(date +%s)
		while [ $(gpio -g read $HALT) -eq 0 ]; do
			if [ $(($(date +%s)-starttime)) -ge 2 ]; then
				gpio -g write $LED 1
				shutdown -h now
			fi
		done
	fi
done












