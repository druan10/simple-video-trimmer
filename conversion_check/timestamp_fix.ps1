$origPath = "D:\Highlights\highlights_new_need_editing\stalker"
$convPath = "D:\Highlights\___COMPRESSION_SCRIPT___\output"

# Build a lookup table of original base names to their LastWriteTime
$origMap = @{}
Get-ChildItem -Path $origPath -File | ForEach-Object {
    $origMap[$_.BaseName] = $_.LastWriteTime
}

# Update modified times on converted files
Get-ChildItem -Path $convPath -File | ForEach-Object {
    $convBase = $_.BaseName -replace '_processed_.*$', ''
    
    if ($origMap.ContainsKey($convBase)) {
        $_.LastWriteTime = $origMap[$convBase]
        Write-Host "Updated timestamp for: $($_.Name)"
    }
}