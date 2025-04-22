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

            # Get number of audio streams
            $audioStreams = & ffprobe -i "`"$inputFile`"" -show_entries stream=codec_type -select_streams a -v 0 -of compact | Measure-Object -Line | Select-Object -ExpandProperty Lines
            if ($debug) { Write-Host "[DEBUG] Number of audio streams found: $audioStreams" }

            # Build the filter complex string based on number of audio streams
            $filterComplex = ""
            $mergeInputs = ""

            for ($i = 0; $i -lt $audioStreams; $i++) {
                # Define volume level for each track (adjust these values as needed)
                $volumeLevels = @(1.0, 0.7, 0.5, 0.3) # Example: Track 1 = 100%, Track 2 = 70%, Track 3 = 50%, Track 4 = 30%
                $volumeLevel = if ($i -lt $volumeLevels.Length) { $volumeLevels[$i] } else { 1.0 }
                
                # Process each audio stream: compress/normalize first, then adjust volume
                $filterComplex += "[0:a:$i]compand=attacks=0:points=-80/-80|-45/-15|-27/-9|0/-7|20/-7:gain=1,volume=${volumeLevel}[a$i];"
                $mergeInputs += "[a$i]"
            }

            # Add the amerge and loudnorm if we have audio streams
            if ($audioStreams -gt 0) {
                $filterComplex += "$mergeInputs amerge=inputs=$audioStreams,loudnorm=I=-16:TP=-1.5:LRA=11[aout]"
            }

            # Construct the FFmpeg command string
            $ffmpegArgs = @(
                "-i", "`"$inputFile`"",
                "-ss", "$startTime",
                "-t", "$duration",
                "-c:v", "libx264",
                "-preset", "slow",
                "-crf", "18"
            )

            # Add audio processing if we have audio streams
            if ($audioStreams -gt 0) {
                $ffmpegArgs += @(
                    "-filter_complex", "`"$filterComplex`"",
                    "-map", "0:v",
                    "-map", "[aout]"
                )
            }

            $ffmpegArgs += @(
                "-c:a", "aac",
                "-ac", "2",
                "-movflags", "+faststart",
                "`"$outputFile`""
            )

            if ($debug) { 
                Write-Host "[DEBUG] Audio streams found: $audioStreams"
                Write-Host "[DEBUG] Filter complex: $filterComplex"
                Write-Host "[DEBUG] FFmpeg arguments: $($ffmpegArgs -join ' ')"
            }

            # Execute FFmpeg command
            $process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru

            # Check the exit code
            if ($process.ExitCode -eq 0) {
                Write-Host "[INFO] Successfully processed: $inputFile"
            } else {
                Write-Host "[ERROR] Failed to process: $inputFile (Exit code: $($process.ExitCode))"
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




