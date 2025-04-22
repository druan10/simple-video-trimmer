# Simple Video File Trimmer/Compressor

A PowerShell script to compress and trim video files using FFmpeg.

## Features

- Compresses video files for efficient storage
- Trims videos based on filename format
- Supports multiple audio tracks with customizable volume levels

## Usage

1. Ensure FFmpeg is installed and added to your system's PATH.
2. Clone the repository and navigate to the folder.
3. (Optional) Modify `compress.ps1` to customize:
   - `$videoFolder`: Input folder for video files
   - `$outputFolder`: Output folder for processed videos
   - `$volumeLevels`: Adjust volume levels for each audio track (2 tracks by default)
   - `$debug`: Enable/disable verbose output
4. Name your video files to specify trim duration:
   - `video1_12.mp4`: Keep the last 12 seconds
   - `video2_12-5.mp4`: Keep 7 seconds, starting 12 seconds from the end
5. Run the script using `.\run_compress.bat`

## Requirements

- FFmpeg
- PowerShell

## Workflow

1. Record gameplay with OBS using separate audio tracks.
2. Review clips and rename files to specify durations.
3. Run the script to process videos.

This method enables quick and efficient video editing without additional software.
