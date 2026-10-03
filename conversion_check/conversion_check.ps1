$origPath = "D:\Highlights\highlights_new_need_editing\stalker"
$convPath = "D:\Highlights\___COMPRESSION_SCRIPT___\output"

# Get base names for converted files (strips _processed_...)
$convertedBases = Get-ChildItem -Path $convPath -File | ForEach-Object {
    $_.BaseName -replace '_processed_.*$', ''
} | Select-Object -Unique

# Find originals whose base name is not in the converted set
$unconverted = Get-ChildItem -Path $origPath -File | Where-Object {
    $base = $_.BaseName
    $convertedBases -notcontains $base
}

# Export missing list to a text file
$unconverted | Select-Object -ExpandProperty Name | Out-File "unconverted_videos.txt"