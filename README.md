#UASerials.pro downloader

This script was created to download videos from website uaserials.pro in different quality to watch them without ads on TV from USB drive.

##### Installs needed before using the script:
`sudo apt install html-xml-utils wget ffmpeg npm
`cd scripts; npm i``

## Usage
./uaserials.pro https://uaserials.pro/2042-velykyi-kush.html 

### Params
`--season=N`
Specific season for show.
`--sound=N`
Set Audio track.
`--quality=N`
Quality: 480, 720, 1080 if available
`dry-run=1`
Will create all files needed for queue download or check if movie is available for download in case of using ffmepg downloader.
`--output=PATH`
Set folder to download movie.
Default is /home/$USER/Videos/uaserials
`--use-ffmpeg=1`
Switch to ffmpeg downloader. Could be the issue when one of the segment goes timeout. Download will stuck and will be started from the start next run.
`--skip=N`
Skip first N videos from season.
