#!/bin/bash

# Uaserials dowloader.

# Install before use:
# sudo apt install html-xml-utils wget ffmpeg

# Quality: 480, 720, 1080 if available
QUALITY="480"
# Specific season for show.
SEASON=0
# Set Audio track.
SOUND=0
# Will create all files needed for queue download or check if movie is available for download in case of using ffmepg downloader.
DRY_RUN="0"
# Set folder to download movie.
OUTPUT="/home/$USER/Videos/uaserials/"
OUTPUT_SEGMENTS=$OUTPUT
OUTPUT_SEGMENTS+="segments"
# Skip first N videos from season.
SKIP=0
# Additional flag to enable FFmepeg downloader.
USE_FFMPEG_DOWNLOADER=0

# Temp files to store info.
FILE_FFMPEG_LIST="./vars/list-ffmpeg.txt"
FILE_WGET_LIST="./vars/list-wget.txt"
FILE_COUNTER="./vars/counter"
FILE_VIDEO_NAME="./vars/video-name"

# Get url from first argument.
args=("$@") 
URL=${args[0]}
unset args[0]

# Check if link to page is present.
if [ -z "$URL" ]; then
    echo "No url supplied. Please set collection name. (ex: https://uaserials.pro/filmy/genre-action/some-movie.html)"
    exit
fi 

for i in "${args[@]}"; do
  echo "$i"
  case "$i" in
    --season=*)
      SEASON="${i#*=}"
      ;;
    --sound=*)
      SOUND="${i#*=}"
      ;;
    --quality=*)
      QUALITY="${i#*=}"
      ;;
    --dry-run=*)
      DRY_RUN="1"
      ;;  
    --output=*)
      OUTPUT="${i#*=}"
      ;;
    --use-ffmpeg=*)
      USE_FFMPEG_DOWNLOADER="${i#*=}"
      ;;  
    --skip=*)
      SKIP="${i#*=}"
      ;;  
    *)
      printf "***************************\n"
      printf "* Error: Invalid argument.*\n"
      printf "***************************\n"
      exit 1
  esac
  shift
done

#get_player_encoded() {
#	echo $1 |
#	wget -O- -i- --no-verbose --quiet | 
#	hxnormalize -x |
#	sed -n 's/.*data-tag1="\([^"]\+\).*/\1/p' |
#	sed -n "s/&#34;/\"/gp"
#}

# Updated versions after the bracets where changes on website.
get_player_encoded() {
	echo $1 |
	wget -O- -i- --no-verbose --quiet | 
	hxnormalize -x |
	sed -n "s/.*data-tag1='\([^']\+\).*/\1/p"
}

# Get playlist link from iframe.
get_main_playlist_in_iframe() {
	echo $1 |
	sed  's/https://' | sed 's/\/\//https:\/\//' | 
	wget -O- -i- --no-verbose --quiet | 
	grep -E -o 'file:"(.*)m3u8' | 
	sed -n 's/file:"//p'
} 

# Get quality playlist from main playlist.
get_quality_playlist() {
	echo $1 |
	wget -O- -i- --no-verbose --quiet | 
	grep -E -o "https://(.*)hls\/$QUALITY\/(.*)m3u8"
} 

# Create filename from playlist url.
# exmaple url https://sparrow.tortuga.wtf/hls/serials/solar.opposites.s01e08.adrianzp.mvo_45026/hls/index.m3u8
get_filename_from_url() {
	echo $1 |
	sed 's/\/hls\/index.*//' |  # remove text after hls/index
	sed 's#.*/##' # leave only last word
}

# Will be used to create segment url
get_remote_video_folder() {
	echo $1 |
	sed -n 's/index.m3u8//p'
}

# Create files with segments list for wget and ffmpeg.
# param 1 - m3u8 playlist url
create_segments_files() {
	[ -d $OUTPUT_SEGMENTS ] || mkdir -p $OUTPUT_SEGMENTS
	
	# Remove previously created files.
    if test -f "$FILE_FFMPEG_LIST"; then
	   rm $FILE_FFMPEG_LIST
	fi
	if test -f "$FILE_WGET_LIST"; then
	   rm $FILE_WGET_LIST
	fi
	
	VIDEO_FOLDER=$(get_remote_video_folder $1)

	# Download playlist and extract only segments links.
	wget $1 --output-document=pls.file --no-verbose
	LIST=$(grep segment pls.file)
	rm pls.file
	for f in $LIST;
	do
		echo "file '$OUTPUT_SEGMENTS/$f'" >> $FILE_FFMPEG_LIST
		echo "$VIDEO_FOLDER$f" >> $FILE_WGET_LIST
	done
	echo "Saving lists files done."
}

# Download segments and create final movie file on success.
download_segments() {
	if test ! -f "$FILE_WGET_LIST"; then
		echo "No previous segments found. Start from beginning."
		return
	fi
	
	# If counter file already present we shuld continue downloading.
	COUNTER=0
	if test -f "$FILE_COUNTER"; then
	   COUNTER=$(<"$FILE_COUNTER")
	   echo "Continue downloading from $COUNTER ..."
	else
		# Create counter file.
		echo 0 > $FILE_COUNTER
	fi
	TOTAL_FILES=$(sed -n '$=' $FILE_WGET_LIST)
	readarray -t FILE_LIST < $FILE_WGET_LIST

	for (( i=$(($COUNTER));i<=$(($TOTAL_FILES));i++)); do
	
		# This will retry refused connections and similar fatal errors (--retry-connrefused), 
		# it will wait 1 second before next retry (--waitretry), it will wait a maximum of
		# 20 seconds in case no data is received and then try again (--read-timeout),
		# it will wait max 15 seconds before the initial connection times out (--timeout) 
		# and finally it will retry a 2 number of times (-t 2).
		wget --continue --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 5 ${FILE_LIST[${i}]} --directory-prefix=$OUTPUT_SEGMENTS --no-verbose
		
		# Halt if segment was not available.
		if [ ! -z "${FILE_LIST[${i}]}" ]; then
			DOWNLOADED_FILE=$(basename ${FILE_LIST[${i}]})
		
			if test ! -f "$OUTPUT_SEGMENTS/$DOWNLOADED_FILE"; then
				echo "!! Error downloading segment. pls restart. !!"
				exit
			fi
		fi
		echo "Progress: $i / $TOTAL_FILES"
		echo $i > $FILE_COUNTER
	done
	
	echo "Download segments finished."
	VIDEO_FILENAME="output.mp4"
	if test -f "$FILE_VIDEO_NAME"; then
	   VIDEO_FILENAME=$(<"$FILE_VIDEO_NAME")
	fi
	
	# Concat segments to final file.
	ffmpeg -f concat -safe 0 -i $FILE_FFMPEG_LIST -c copy -bsf:a aac_adtstoasc $OUTPUT$VIDEO_FILENAME
	
	# Remove all temp files and folders.
	rm $FILE_COUNTER
	rm -rf $FILE_FFMPEG_LIST
	rm -rf $FILE_WGET_LIST
	rm -rf $OUTPUT_SEGMENTS
	
	echo "All temp files removed. Downloading finished."
	exit
}

#================== START ==================
echo "UASERIALS.PRO downloader is starting..."

download_segments

echo "url $URL"
echo "quality $QUALITY"
echo "season $SEASON"
echo "sound $SOUND"
echo "skip $SKIP"


# Get iframes for players.
PLAYER_ENCODED=$(get_player_encoded $URL)
#PLAYER_ENCODED=$(get_player_encoded ./page.html)

if [ -z "$PLAYER_ENCODED" ]; then
    echo "Decoded player url was not found."
    exit
fi

echo "PLAYER JSON: $PLAYER_ENCODED"
#echo "$PLAYER_ENCODED" > ./player.json

PLAYER_IFRAMES=$(node ./scripts/crypto.js $PLAYER_ENCODED $SEASON $SOUND)

if [ -z "$PLAYER_IFRAMES" ]; then
	echo "No iframes for player found. exit"
	exit
fi
echo "player iframes: $PLAYER_IFRAMES"


# Split strings to an array.
PLAYER_IFRAMES=($(echo "$PLAYER_IFRAMES" | tr ',' '\n'))

# Skip videos from beginning.
if [ ! -z "$SKIP" ]; then
	for (( i=0;i<$(($SKIP));i++)); do
		echo "skip ${PLAYER_IFRAMES[${i}]}"
		unset PLAYER_IFRAMES[$i]
	done
fi

[ -d $OUTPUT ] || mkdir -p $OUTPUT

for iframe in "${PLAYER_IFRAMES[@]}";
do
	VIDEO_URI=$(get_main_playlist_in_iframe $iframe)
	echo "playlist main = $VIDEO_URI"
	PLAYLIST=$(get_quality_playlist $VIDEO_URI)
	echo "playlist quality = $PLAYLIST"
	if [ -z "$PLAYLIST" ]; then
		echo "Playlist for selected quality not found. Try another."
		exit
	fi
	
	FILENAME=$(get_filename_from_url $VIDEO_URI)
	FILENAME+=".mp4"
	echo "filname = $FILENAME"
	echo $FILENAME > $FILE_VIDEO_NAME

	if [ "$DRY_RUN" == "0" ] 
	then
		if [ "$USE_FFMPEG_DOWNLOADER" == "1" ]; then
			ffmpeg -i $PLAYLIST -c copy -bsf:a aac_adtstoasc "$OUTPUT$FILENAME" -hide_banner -y
		else
			create_segments_files $PLAYLIST
			download_segments
		fi
	fi
	echo "----------------------------------------------"
done

echo "UASERIALS.PRO downloader finished."

exit 
