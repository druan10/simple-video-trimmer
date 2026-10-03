@echo off
setlocal enabledelayedexpansion

rem Set the folder containing the videos
set "video_folder=."

rem Set the duration to keep at the end of the video in seconds (default: 20 seconds)
set "trim_duration=15"

rem Loop through all files in the video_folder
for %%f in ("%video_folder%\*") do (
    rem Check if the file has a .mp4 or .mkv extension
    if "%%~xf"==".mp4" (
        set "input_file=%%f"
        set "output_file=%%~dpnf_compressed.mp4"
    ) else if "%%~xf"==".mkv" (
        set "input_file=%%f"
        set "output_file=%%~dpnf_compressed.mp4"
    ) else (
        rem Skip files that do not have the correct extensions
        continue
    )

    rem Build the ffmpeg command to compress the video, merge all audio tracks, and keep only the last %trim_duration% seconds
    ffmpeg -sseof -!trim_duration! -i "!input_file!" -filter_complex "[0:a]amerge=inputs=1[aout]" -map 0:v -map "[aout]" -c:v libx264 -preset veryfast -crf 20 -c:a aac -ac 2 "!output_file!"

    rem Check if the command was successful
    if errorlevel 1 (
        echo Error processing "!input_file!"
        exit /b 1
    ) else (
        echo Successfully processed "!input_file!"
    )
)

endlocal
pause
