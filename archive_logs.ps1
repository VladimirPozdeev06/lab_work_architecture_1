# archive_logs.ps1
param(
    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [Parameter(Mandatory = $true)]
    [int]$ThresholdMb,

    [Parameter(Mandatory = $true)]
    [int]$FilesToArchive
)

if (-not (Test-Path -Path $LogPath)) {
    Write-Error "Log directory '$LogPath' does not exist."
    exit 1
}

$FileItems = Get-ChildItem -Path $LogPath -Recurse -File -ErrorAction SilentlyContinue
$UsedSize = ($FileItems | Measure-Object Length -Sum).Sum
if (-not $UsedSize) { $UsedSize = 0 }

$PercentUsed = [math]::Round(($UsedSize / 1MB) / $ThresholdMb * 100, 2)

Write-Host "Log folder size: $([math]::Round($UsedSize/1MB,2)) MB (${PercentUsed}% of threshold $ThresholdMb MB)."

if ($PercentUsed -gt 100) {
    $ParentDir = Split-Path -Parent $LogPath
    $BackupPath = Join-Path $ParentDir "backup"
    if (-not (Test-Path -Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath | Out-Null
    }

    Write-Host "Threshold exceeded. Archiving $FilesToArchive oldest files..."

    $OldFiles = $FileItems | Sort-Object LastWriteTime | Select-Object -First $FilesToArchive

    if ($OldFiles.Count -eq 0) {
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
        Write-Error "Failed to create archive. Files were NOT deleted."
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