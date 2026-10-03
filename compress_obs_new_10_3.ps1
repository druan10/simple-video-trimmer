# Enable debug logging (set to $true for verbose output, $false to disable)
$debug = $true

# If $true, keep each audio track separate in the output file instead of merging them into one.
$keepTracksSeparate = $true

# Define input and output folders
$videoFolder = "input"
$outputFolder = "output"

# Create output folder if it doesn't exist
if (!(Test-Path -Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Get current timestamp for output filenames
$timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
if ($debug) { Write-Host "[DEBUG] Current timestamp: $timestamp" }

# Loop through all video files in the folder, oldest first
Get-ChildItem -Path $videoFolder -File | Sort-Object LastWriteTime | ForEach-Object {
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

            # Get each input audio stream's original bitrate so re-encoded output matches it
            $defaultBitrate = "160k"
            $audioBitrates = & ffprobe -i "`"$inputFile`"" -select_streams a -show_entries stream=bit_rate -v 0 -of csv="p=0"
            $audioBitrates = @($audioBitrates | ForEach-Object {
                if ($_ -match '^\d+$' -and [int64]$_ -gt 0) { "$([math]::Round([int64]$_ / 1000))k" } else { $defaultBitrate }
            })
            if ($debug) { Write-Host "[DEBUG] Original audio bitrates: $($audioBitrates -join ', ')" }

            # Build the filter complex string based on number of audio streams
            $filterComplex = ""
            $mergeInputs = ""

            # Define volume multiplier for each track (adjust these values as needed)
            # In OBS, I use:
            #   Track 1 = All audio sources combined
            #   Track 2 = Desktop Audio
            #   Track 3 = Discord Audio
            #   Track 4 = Game Audio
            #   Track 5 = Self Mic
            $volumeMultipliers = @(0, 0.8, 1.0, 0.8, 1.0) # Example: Track 1 = 50%, Track 2 = 70%, Track 3 = 90%

            for ($i = 0; $i -lt $audioStreams; $i++) {
                $volumeMultiplier = if ($i -lt $volumeMultipliers.Length) { $volumeMultipliers[$i] } else { 1.0 }
                
                if ($i -eq 0) {
                    # Apply only volume adjustment to the first track
                    $filterComplex += "[0:a:$i]volume=${volumeMultiplier}[a$i];"
                } else {
                    # Apply compression, loudness normalization, and volume adjustment to other tracks
                    $filterComplex += "[0:a:$i]acompressor=threshold=-10dB:ratio=2:attack=5:release=50[compressed$i];"
                    $filterComplex += "[compressed$i]loudnorm=I=-16:TP=-1.5:LRA=11[normalized$i];"
                    $filterComplex += "[normalized$i]volume=${volumeMultiplier}[a$i];"
                }
                $mergeInputs += "[a$i]"
            }

            if ($audioStreams -gt 0) {
                if ($keepTracksSeparate) {
                    # Trim trailing separator left over from the per-track filter chain
                    $filterComplex = $filterComplex.TrimEnd(';')
                } else {
                    # Merge all processed tracks down into a single output track
                    $filterComplex += "$mergeInputs amerge=inputs=$audioStreams[aout]"
                }
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
                    "-map", "0:v"
                )

                if ($keepTracksSeparate) {
                    for ($i = 0; $i -lt $audioStreams; $i++) {
                        $ffmpegArgs += @("-map", "[a$i]")
                    }
                } else {
                    $ffmpegArgs += @("-map", "[aout]")
                }

                # loudnorm silently bumps its output sample rate to 192kHz; pin it back down
                # to the source rate so we don't ship unnecessarily bloated/upsampled audio.
                $ffmpegArgs += @("-ar", "48000")
            }

            if ($keepTracksSeparate) {
                # Use uncompressed PCM for separate tracks. Vegas Pro's MP4 demuxer does not
                # reliably decode multiple discrete AAC audio streams in one container (tracks
                # come in silent even though the encoded data is fine), but it handles
                # multi-stream PCM correctly. No bitrate setting needed since PCM is uncompressed.
                for ($i = 0; $i -lt $audioStreams; $i++) {
                    $ffmpegArgs += @(
                        "-c:a:$i", "pcm_s16le",
                        "-ac:a:$i", "2"
                    )
                }
            } else {
                # Merged single track: use the highest original bitrate among the inputs
                $mergedBitrate = if ($audioBitrates.Length -gt 0) {
                    ($audioBitrates | ForEach-Object { [int]($_ -replace 'k$', '') } | Measure-Object -Maximum).Maximum.ToString() + "k"
                } else { $defaultBitrate }
                $ffmpegArgs += @(
                    "-c:a", "aac",
                    "-b:a", "$mergedBitrate",
                    "-ac", "2"
                )
            }

            $ffmpegArgs += @(
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








