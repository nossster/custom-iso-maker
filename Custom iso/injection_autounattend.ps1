# Get the directory where the script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find files with .xml and .iso extensions in the script directory
$xmlFile = Get-ChildItem -Path $scriptDir -Filter *.xml | Select-Object -First 1
$isoFile = Get-ChildItem -Path $scriptDir -Filter *.iso | Select-Object -First 1

# Check if files exist
if ($xmlFile -eq $null) {
    Write-Error "XML file not found in directory $scriptDir"
    exit 1
}
if ($isoFile -eq $null) {
    Write-Error "ISO file not found in directory $scriptDir"
    exit 1
}

# Path to oscdimg.exe
$oscdimg = Join-Path -Path $scriptDir -ChildPath "oscdimg.exe"

# Temporary folder for mounting the ISO image
$tempMountDir = "$env:TEMP\ISOMount"

# Mount the ISO image
Write-Output "Mounting ISO image..."
Mount-DiskImage -ImagePath $isoFile.FullName
$diskImage = Get-DiskImage -ImagePath $isoFile.FullName
$volumes = Get-Volume -DiskImage $diskImage

# Create a temporary folder
Write-Output "Creating temporary folder..."
New-Item -ItemType Directory -Path $tempMountDir -Force

# Copy files from the ISO to the temporary folder
Write-Output "Copying files from ISO image to temporary folder..."
$volumeLetter = $volumes.DriveLetter + ":"
$files = Get-ChildItem -Path "$volumeLetter\*" -Recurse
$totalFiles = $files.Count
$currentFile = 0

foreach ($file in $files) {
    $destPath = Join-Path -Path $tempMountDir -ChildPath ($file.FullName.Substring(3))
    Copy-Item -Path $file.FullName -Destination $destPath -Force
    $currentFile++
    Write-Progress -Activity "Copying files" -Status "$currentFile of $totalFiles files copied" -PercentComplete (($currentFile / $totalFiles) * 100)
}

# Add the XML file to the temporary folder
Write-Output "Adding XML file to temporary folder..."
Copy-Item -Path $xmlFile.FullName -Destination $tempMountDir

# Dismount the ISO image
Write-Output "Dismounting ISO image..."
Dismount-DiskImage -ImagePath $isoFile.FullName

# Create a new ISO image with the added XML file
$newIsoFileName = "custom_" + $isoFile.Name
$newIsoFilePath = Join-Path -Path $scriptDir -ChildPath $newIsoFileName
$isoLabel = "IMAGE_LABEL"
Write-Output "Creating new ISO image with the added XML file..."
$cdImageCmd = "& `"$oscdimg`" -n -m -o -l$isoLabel `"$tempMountDir`" `"$newIsoFilePath`""

Invoke-Expression -Command $cdImageCmd

# Remove the temporary folder
Write-Output "Removing temporary folder..."
Remove-Item -Path $tempMountDir -Recurse -Force

Write-Output "ISO file successfully updated. New ISO file: $newIsoFilePath"
