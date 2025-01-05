# Enable debug logging (set to $true for verbose output, $false to disable)
$debug = $true

# Define input and output folders
$videoFolder = "."
$outputFolder = "output"

# Create output folder if it doesn't exist
if (!(Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Get current timestamp for output filenames
$timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
if ($debug) { Write-Host "[DEBUG] Current timestamp: $timestamp" }

# Loop through all video files in the folder
Get-ChildItem -Path $videoFolder -File | ForEach-Object {
    $file = $_

    # Skip files already in the output folder
    if ($file.DirectoryName -like "*$outputFolder*") {
        if ($debug) { Write-Host "[DEBUG] Skipping file in output folder: $($file.FullName)" }
        return
    }

    # Process supported file types
    if ($file.Extension -in ".mp4", ".mkv") {
        $inputFile = $file.FullName
        $fileName = $file.BaseName
        $outputFile = Join-Path -Path $outputFolder -ChildPath "$($file.BaseName)_timestamp_$timestamp.mp4"

        if ($debug) {
            Write-Host "[DEBUG] Input file: $inputFile"
            Write-Host "[DEBUG] Output file: $outputFile"
            Write-Host "[DEBUG] File name without extension: $fileName"
        }

        # Extract trim duration from the filename (last underscore + number)
        if ($fileName -match "_(\d+)$") {
            $trimDuration = $matches[1]
            if ($debug) { Write-Host "[DEBUG] Extracted trim duration: $trimDuration" }

            # Run ffmpeg command to process the video
            $ffmpegCommand = @(
                "ffmpeg",
                "-sseof", "-$trimDuration",
                "-i", "`"$inputFile`"",
                "-filter_complex", "`"[0:a]amerge=inputs=1[aout]`"",
                "-map", "0:v",
                "-map", "`"[aout]`"",
                "-c:v", "libx264",
                "-preset", "slow",
                "-crf", "18",
                "-c:a", "aac",
                "-ac", "2",
                "-movflags", "+faststart",
                "`"$outputFile`""
            )
            if ($debug) { Write-Host "[DEBUG] Running ffmpeg command: $($ffmpegCommand -join ' ')" }
            Start-Process -NoNewWindow -Wait -FilePath $ffmpegCommand[0] -ArgumentList $ffmpegCommand[1..$ffmpegCommand.Length]

            # Check for errors
            if ($?) {
                Write-Host "[INFO] Successfully processed: $inputFile"
            } else {
                Write-Host "[ERROR] Failed to process: $inputFile"
            }
        } else {
            Write-Host "[ERROR] Invalid trim duration in filename: $fileName. Skipping file."
        }
    } else {
        if ($debug) { Write-Host "[DEBUG] Skipping unsupported file type: $($file.FullName)" }
    }
}
