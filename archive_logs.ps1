# archive_logs.ps1
param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [Parameter(Mandatory = $true)]
    [double]$ThresholdValue,

    [Parameter(Mandatory = $true)]
    [ValidateSet("MB", "Percent")]
    [string]$ThresholdType,

    [Parameter(Mandatory = $true)]
    [int]$FilesToArchive
)

if (-not (Test-Path -Path $LogPath)) {
    Write-Error "Log directory '$LogPath' does not exist."
    exit 1
}

$FileItems = Get-ChildItem -Path $LogPath -Recurse -File -ErrorAction SilentlyContinue
$UsedSize = ($FileItems | Measure-Object -Property Length -Sum).Sum
if ($null -eq $UsedSize) { $UsedSize = 0 }
$UsedSizeMb = $UsedSize / 1MB

$Drive = (Get-Item $LogPath).PSDrive.Name
$DiskInfo = Get-PSDrive -Name $Drive -ErrorAction Stop
$TotalDiskSizeMb = $DiskInfo.Free + $DiskInfo.Used
$TotalDiskSizeMb = [Math]::Round($TotalDiskSizeMb / 1MB, 2)

switch ($ThresholdType) {
    "MB" {
        if ($ThresholdValue -le 0) {
            Write-Error "ThresholdValue must be greater than 0 when using 'MB'."
            exit 1
        }
        $ThresholdInMb = $ThresholdValue
        $PercentUsed = [math]::Round(($UsedSizeMb / $ThresholdInMb) * 100, 2)
        Write-Host "Log folder size: $([math]::Round($UsedSizeMb, 2)) MB (${PercentUsed}% of threshold ${ThresholdInMb} MB)."
    }
    "Percent" {
        if ($ThresholdValue -le 0 -or $ThresholdValue -gt 100) {
            Write-Error "ThresholdValue must be between 0 and 100 when using 'Percent'."
            exit 1
        }
        $ThresholdInMb = ($ThresholdValue / 100) * $TotalDiskSizeMb
        $PercentUsed = [math]::Round(($UsedSizeMb / $TotalDiskSizeMb) * 100, 2)
        Write-Host "Log folder size: $([math]::Round($UsedSizeMb, 2)) MB (${PercentUsed}% of total disk ${TotalDiskSizeMb} MB). Threshold: ${ThresholdValue}% (${ThresholdInMb:N2} MB)."
    }
}

if ($UsedSizeMb -gt $ThresholdInMb) {
    $ParentDir = Split-Path -Parent $LogPath
    $BackupPath = Join-Path $ParentDir "backup"
    if (-not (Test-Path -Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath | Out-Null
    }

    Write-Host "Threshold exceeded. Archiving $FilesToArchive oldest files."

    $OldFiles = $FileItems | Sort-Object LastWriteTime | Select-Object -First $FilesToArchive

    if (-not $OldFiles -or $OldFiles.Count -eq 0) {
        Write-Host "No files to archive."
        exit 0
    }

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ArchiveName = "logs_$Timestamp.tar.gz"
    $ArchivePath = Join-Path $BackupPath $ArchiveName

    $RelativePaths = $OldFiles | ForEach-Object {
        $relPath = $_.FullName.Substring($LogPath.Length)
        if ($relPath.StartsWith('\') -or $relPath.StartsWith('/')) {
            $relPath = $relPath.Substring(1)
        }
        $relPath
    }

    & tar -czf $ArchivePath -C $LogPath $RelativePaths

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create archive. Files were not deleted."
        exit 1
    }

    Write-Host "Archived $($OldFiles.Count) files to $ArchivePath"

    foreach ($file in $OldFiles) {
        try {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            Write-Host "Deleted: $($file.FullName)"
        }
        catch {
            Write-Warning "Failed to delete file: $($file.FullName). Error: $_"
        }
    }
}