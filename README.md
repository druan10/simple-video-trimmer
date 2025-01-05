# Simple Video File Trimmer/Compressor

A PowerShell script to compress and trim video files in a folder using FFmpeg.

I use obs pretty often but I don't care about editing too much so I made this simple script to trim videos using ffmpeg.
The script both compresses the videos, and keeps only the last x seconds of the video, based on the filename.
E.G video1_12.mp4 would result in a compressed version of the video with only the last 12 seconds of the original clip.

## Usage

1. Clone the repository and navigate to the folder.

2. (OPTIONAL) Open `compress.ps1` and update the following variables:
	* `$videoFolder`: The folder containing the video files to compress.
	* `$outputFolder`: The folder to output the compressed video files.
	* `$debug`: Set to `$true` for verbose output, `$false` to disable.

2. Place your video files in the folder
3. Run the script by executing `.\run_compress.bat` - This batch file is just to avoid having to type out the commands to allow script execution in powershell.

## Requirements

* FFmpeg must be installed and available in your system's PATH.
* PowerShell
