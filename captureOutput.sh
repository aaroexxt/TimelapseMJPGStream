#!/bin/bash

abort() #aborts script
{
    stty sane #reset stty
    echo >&2 '
***************
*** ABORTED ***
***************
'
    echo "An error occurred :( Exiting..." >&2
    exit 1;
}

snap() #snaps photo
{
    photoDir="p$photoNumber.jpeg";
    echo "Capturing photo# $photoNumber as file $photoDir"
    photoNumber=$((photoNumber + 1))
    sudo curl -s $photoPath -o $photoDir
}

timelapse() #timelapse
{
    echo "Deleting invalid images...";
    sudo find . -size 0 -delete
    echo "Getting file list...";
    sudo rm -f files.txt;
    sudo touch files.txt;
    sudo chmod 777 files.txt;
    sudo find . -type f -name 'p*.jpeg' | cut -c 3- | sort -V | sed "s/^/file '/;s/$/'/" > files.txt #this sorting took forever, it sorts it perfectly
    #sudo mkdir build;
    #echo "Rotating images";
    #sudo find *.jpeg -type f -print | xargs -I {} convert {} -rotate 90 build/{};
    echo "Building combined mp4; this might take a while";
    sudo rm -f timeLapse.mp4;
    sudo ffmpeg -f concat -i files.txt -r 60 -s 1920x1080 -vcodec libx264 -crf 15 -pix_fmt yuv420p timeLapse.mp4; #create timelapse (high quality)
    #sudo ffmpeg -f concat -i files.txt -r 30 -s hd480 -vcodec mpeg4 timeLapse.mp4; #create timelapse (lower quality)
    #sudo rm -r build;
}

if [[ $(id -u) -ne 0 ]]
  then echo "Sorry, but it appears that you didn't run this script as root. Please run it as a root user!";
  exit 1;
fi

trap 'abort' 0;
stty -echo -icanon time 0 min 0

echo "Aaron's AutoSnap Tool for MJPG" && echo "------------------------------";

#setup dirs
DATE=`date '+%Y-%m-%d:%H-%M-%S'`
picDir="capturedOutput@$DATE";
photoNumber=1;
photoPath="http://octopi.local/webcam/?action=snapshot"
echo "Writing to directory: $picDir";

sudo mkdir $picDir;
cd $picDir;


keypress=''
while true; do
    read keypress
    case $keypress in
        # This case is for no keypress
        "")
        ;;
        $'q')
        echo "Creating timelapse..."; timelapse; exit 0;
        ;;
        # If you want to do something for unknown keys, otherwise leave this out
        *)
        echo "Unknown input: $keypress, type q to quit & create timelapse"
        ;;
    esac
    snap
done

stty sane
trap : 0;