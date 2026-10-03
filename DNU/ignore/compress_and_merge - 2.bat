@echo off
setlocal enabledelayedexpansion

rem Set the folder containing the videos
set "video_folder=."

rem Loop through all files in the video_folder
for %%f in ("%video_folder%\*.*") do (
    rem Check if the file has a .mp4 or .mkv extension
    set "extension=%%~xf"
    if /i "!extension!"==".mp4" (
        set "input_file=%%f"
        set "output_file=%%~dpn_compressed.mp4"
    ) else if /i "!extension!"==".mkv" (
        set "input_file=%%f"
        set "output_file=%%~dpn_compressed.mp4"
    ) else (
        rem Skip files that do not have the correct extensions
        rem Batch does not have a continue, so we simply skip
        goto :next
    )

    rem Process the file
    echo Processing "!input_file!"...
    ffmpeg -i "!input_file!" -filter_complex "[0:a]amerge=inputs=1[aout]" -map 0:v -map "[aout]" -c:v libx264 -preset veryfast -crf 20 -c:a aac -ac 2 "!output_file!"

    rem Check if the command was successful
    if errorlevel 1 (
        echo Error processing "!input_file!"
        exit /b 1
    ) else (
        echo Successfully processed "!input_file!"
    )

    :next
)

endlocal
pause
