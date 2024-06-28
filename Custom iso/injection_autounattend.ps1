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
if (-Not (Test-Path $oscdimg)) {
    Write-Error "oscdimg.exe not found in directory $scriptDir"
    exit 1
}

# Temporary folder for mounting the ISO image
$tempMountDir = Join-Path -Path $scriptDir -ChildPath "temp_iso"

# Mount the ISO image
Write-Output "Mounting ISO image..."
Mount-DiskImage -ImagePath $isoFile.FullName
if ($?) {
    Write-Output "ISO image mounted successfully."
} else {
    Write-Error "Failed to mount ISO image."
    exit 1
}
$diskImage = Get-DiskImage -ImagePath $isoFile.FullName
$volumes = Get-Volume -DiskImage $diskImage

# Create a temporary folder
Write-Output "Creating temporary folder..."
New-Item -ItemType Directory -Path $tempMountDir -Force
if ($?) {
    Write-Output "Temporary folder created successfully."
} else {
    Write-Error "Failed to create temporary folder."
    exit 1
}

# Copy files from the ISO to the temporary folder
Write-Output "Copying files from ISO image to temporary folder..."
$volumeLetter = $volumes.DriveLetter + ":"
$files = Get-ChildItem -Path "$volumeLetter\\*" -Recurse
$totalFiles = $files.Count
$currentFile = 0

foreach ($file in $files) {
    $destPath = Join-Path -Path $tempMountDir -ChildPath ($file.FullName.Substring(3))
    Copy-Item -Path $file.FullName -Destination $destPath -Force
    if ($?) {
        $currentFile++
        Write-Progress -Activity "Copying files" -Status "$currentFile of $totalFiles files copied" -PercentComplete (($currentFile / $totalFiles) * 100)
    } else {
        Write-Error "Failed to copy file: $file.FullName"
    }
}

# Add the XML file to the temporary folder
Write-Output "Adding XML file to temporary folder..."
Copy-Item -Path $xmlFile.FullName -Destination $tempMountDir
if ($?) {
    Write-Output "XML file added successfully."
} else {
    Write-Error "Failed to add XML file."
    exit 1
}

# Dismount the ISO image
Write-Output "Dismounting ISO image..."
Dismount-DiskImage -ImagePath $isoFile.FullName
if ($?) {
    Write-Output "ISO image dismounted successfully."
} else {
    Write-Error "Failed to dismount ISO image."
    exit 1
}

# Create a new ISO image with the added XML file
$newIsoFileName = "custom_" + $isoFile.Name
$newIsoFilePath = Join-Path -Path $scriptDir -ChildPath $newIsoFileName
$isoLabel = "IMAGE_LABEL"
Write-Output "Creating new ISO image with the added XML file..."

$cdImageArgs = "-bootdata:2#p0,e,b`"$tempMountDir\\boot\\etfsboot.com`"#pEF,e,b`"$tempMountDir\\efi\\microsoft\\boot\\efisys.bin`" -u1 -udfver102 -l$isoLabel `"$tempMountDir`" `"$newIsoFilePath`""
Start-Process -FilePath $oscdimg -ArgumentList $cdImageArgs -Wait -NoNewWindow
if ($?) {
    Write-Output "ISO file created successfully. New ISO file: $newIsoFilePath"
} else {
    Write-Error "Failed to create ISO file."
    exit 1
}

# Remove the temporary folder
Write-Output "Removing temporary folder..."
Remove-Item -Path $tempMountDir -Recurse -Force
if ($?) {
    Write-Output "Temporary folder removed successfully."
} else {
    Write-Error "Failed to remove temporary folder."
}
