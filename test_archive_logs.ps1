
# test_archive_logs.ps1
$ScriptPath = "$PSScriptRoot\archive_logs.ps1"

function Assert-True {
    param($Condition, $Message)
    if (-not $Condition) {
        Write-Host "FAIL: $Message"
        exit 1
    } else {
        Write-Host "PASS: $Message"
    }
}

function Create-TestEnv {
    $TestRoot = "$env:TEMP\log_test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $LogPath = "$TestRoot\log"
    $BackupPath = "$TestRoot\backup"
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    return $TestRoot, $LogPath, $BackupPath
}

function Cleanup-TestEnv($Path) {
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
    }
}

# ---------- TESTS ----------
Write-Host "Running tests..."
$TestRoot, $LogPath, $BackupPath = Create-TestEnv

# Test 1: Non-existent directory
Write-Host "Test 1: Non-existent log directory"
$Error.Clear()
& $ScriptPath -LogPath "$TestRoot\notexist" -ThresholdMb 10 -FilesToArchive 2 2>$null
Assert-True ($LASTEXITCODE -ne 0) "Non-existent directory should cause error"

# Test 2: Folder under threshold
Write-Host "Test 2: Folder under threshold"
1..3 | ForEach-Object {
    Set-Content "$LogPath\log$_.txt" ("data" * 100)  # маленькие файлы
}
& $ScriptPath -LogPath $LogPath -ThresholdMb 50 -FilesToArchive 2
if (Test-Path $BackupPath) {
    $Archives = Get-ChildItem -Path $BackupPath -Filter *.tar.gz -ErrorAction SilentlyContinue
} else {
    $Archives = @()
}
Assert-True ($Archives.Count -eq 0) "No archive should be created under threshold"

# Test 3: Threshold exceeded, archive M files
Write-Host "Test 3: Threshold exceeded"
1..5 | ForEach-Object {
    $f = "$LogPath\old$_.txt"
    Set-Content $f ("x" * 1024 * 1024 * 2) # ~2 MB файл
    (Get-Item $f).LastWriteTime = (Get-Date).AddDays(-$_) # старые даты
}
& $ScriptPath -LogPath $LogPath -ThresholdMb 1 -FilesToArchive 3
if (Test-Path $BackupPath) {
    $Archives = Get-ChildItem -Path $BackupPath -Filter *.tar.gz -ErrorAction SilentlyContinue
} else {
    $Archives = @()
}
Assert-True ($Archives.Count -eq 1) "Archive should be created"
Assert-True ($Archives[0].Length -gt 0) "Archive should not be empty"

Cleanup-TestEnv $TestRoot
Write-Host "All tests passed!"