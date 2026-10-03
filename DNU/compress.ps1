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
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)  # Extract filename without extension
        $outputFile = Join-Path -Path $outputFolder -ChildPath "$fileName`_processed_$timestamp.mp4"

        if ($debug) {
            Write-Host "[DEBUG] Input file: $inputFile"
            Write-Host "[DEBUG] Output file: $outputFile"
            Write-Host "[DEBUG] File name without extension: $fileName"
        }

        # Extract trim duration (x) and optional remove duration (y)
        if ($fileName -match "_(\d+)(?:-(\d+))?$") {
            $trimDuration = [int]$matches[1]
            $removeDuration = if ($matches[2]) { [int]$matches[2] } else { 0 }

            if ($debug) { 
                Write-Host "[DEBUG] Extracted trim duration (x): $trimDuration seconds"
                Write-Host "[DEBUG] Extracted remove duration (y): $removeDuration seconds"
            }

            # Ensure valid trim durations
            $startSeconds = $trimDuration - $removeDuration

            if ($startSeconds -le 0) {
                Write-Host "[ERROR] Invalid trim configuration: x ($trimDuration) must be greater than y ($removeDuration). Skipping file: $inputFile"
                return
            }

            # Get total video duration using ffprobe
            $videoDuration = & ffprobe -i "`"$inputFile`"" -show_entries format=duration -v quiet -of csv="p=0"
            $videoDuration = [math]::Round([double]$videoDuration)

            # Calculate correct start time (For actual trimming)
            $startTime = $videoDuration - $trimDuration
            $duration = $trimDuration - $removeDuration

            if ($startTime -lt 0) {
                Write-Host "[ERROR] Calculated start time is negative. Skipping file: $inputFile"
                return
            }

            if ($debug) {
                Write-Host "[DEBUG] Video duration: $videoDuration seconds"
                Write-Host "[DEBUG] Calculated start time: $startTime seconds"
                Write-Host "[DEBUG] Clip duration: $duration seconds"
            }

            # Run ffmpeg command to trim video correctly
            $ffmpegCommand = @(
                "ffmpeg",
                "-i", "`"$inputFile`"", # Input file
                "-ss", "$startTime", # Seek to calculated start time
                "-t", "$duration", # Duration to extract
                "-c:v", "libx264",
                "-preset", "slow",
                "-crf", "18",
                "-c:a", "aac",
                "-ac", "2",
                "-movflags", "+faststart",
                "`"$outputFile`""          # Output file
            )

            if ($debug) { Write-Host "[DEBUG] Running ffmpeg command: $($ffmpegCommand -join ' ')" }

            Start-Process -NoNewWindow -Wait -FilePath $ffmpegCommand[0] -ArgumentList $ffmpegCommand[1..$ffmpegCommand.Length]

            # Check for errors
            if ($?) {
                Write-Host "[INFO] Successfully processed: $inputFile"
            }
            else {
                Write-Host "[ERROR] Failed to process: $inputFile"
            }

        }
        else {
            Write-Host "[ERROR] Invalid filename format (expected _x-y). Skipping file: $fileName"
        }
    }
    else {
        if ($debug) { Write-Host "[DEBUG] Skipping unsupported file type: $($file.FullName)" }
    }
}
