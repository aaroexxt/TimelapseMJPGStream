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
    if [ $SECONDS -ge $timeBetweenFrames ]
        then
            photoDir="p$photoNumber.jpeg";
            #echo "Attempt capture of photo# $photoNumber as file $photoDir"
            sudo curl -s $photoPath -o $photoDir --connect-timeout 5 -m "$timeBetweenFrames"
            if [ $? -eq 0 ]
                then
                    if [ $cyclesSinceLast -gt 0 ];
                        then
                            echo "Frame $photoNumber capture ok, onFrameDelayTarget=true";
                        else
                            overstep=$((SECONDS-timeBetweenFrames))
                            echo "Frame $photoNumber capture ok, onFrameDelayTarget=false, overstep= $overstep s";
                    fi
                    photoNumber=$((photoNumber + 1))
                    SECONDS=0;
                    curRetries=0;
                    cyclesSinceLast=0;
                else
                    if [ $curRetries -ge $retryCaptureMax ]
                        then
                            echo "Dropped frame $photoNumber and max retries reached; building timelapse and exiting";
                            (timelapse && echo "Building timelapse OK") || echo "Building timelapse FAILED rip";
                            cd ..;
                            stty sane;
                            trap : 0;
                            exit 0;
                        else
                            curRetries=$((curRetries + 1))
                            echo "Dropped frame $photoNumber; retrying (retryCount= $curRetries , maxRetries= $retryCaptureMax )";
                    fi
            fi
        else
            #echo "exceeded framert, seconds passed=$SECONDS";
            cyclesSinceLast=$((cyclesSinceLast + 1))
    fi
}

timelapse() #timelapse
{
    echo "Deleting invalid images...";
    sudo find . -size 0 -delete
    echo "Getting file list...";
    sudo rm -f files.txt;
    sudo touch files.txt;
    sudo chmod 777 files.txt;
    #ok the following line is kinda crazy, here's what it does:
    # 1) find all files that match p*.jpeg
    # 2) remove the directory stuff from the beginning of the file names that the find command adds
    # 3) sort by name
    # 4) add required stuff for ffmpeg to understand it
    # 5) output to file
    # woah im proud of myself
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

if [ -z "$1" ]
    then
        echo "Warning: No time between frames argument supplied; defaulting to 10s";
        timeBetweenFrames=10;
    else
        timeBetweenFrames=$1;
fi
echo "Time between frames has been set to: $timeBetweenFrames s";

if [ -z "$2" ]
    then
        echo "Warning: No retry amount argument supplied; defaulting to 5";
        retryCaptureMax=5;
    else
        retryCaptureMax=$2;
fi
curRetries=0;
echo "Max retry of frames has been set to: $retryCaptureMax";

#setup dirs
DATE=`date '+%Y-%m-%d:%H-%M-%S'`
picDir="capturedOutput@$DATE";
photoNumber=1;
photoPath="http://octopi.local/webcam/?action=snapshot"
cyclesSinceLast=0;
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
        echo "Creating timelapse..."; ((timelapse && echo "Building timelapse OK") || echo "Building timelapse FAILED rip"); cd ..; stty sane; trap : 0; exit 0;
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