$ScriptPath = "$PSScriptRoot\archive_logs.ps1"

function Assert-True {
    param($Condition, $Message)
    if (-not $Condition) {
        throw "Assertion failed: $Message"
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

function Test-NonExistentDirectory {
    Write-Host "TEST: Non-existent log directory"
    $TestRoot, $LogPath, $BackupPath = Create-TestEnv
    try {
        & $ScriptPath -LogPath "$TestRoot\notexist" -ThresholdValue 10 -ThresholdType MB -FilesToArchive 2 2>$null
        if ($LASTEXITCODE -eq 0) {
            throw "Expected error for non-existent directory, but script succeeded."
        }
    } finally {
        Cleanup-TestEnv $TestRoot
    }
}

function Test-UnderThresholdMB {
    Write-Host "TEST: Folder under threshold (MB)"
    $TestRoot, $LogPath, $BackupPath = Create-TestEnv
    try {
        1..3 | ForEach-Object {
            Set-Content "$LogPath\log$_.txt" ("data" * 100)
        }
        & $ScriptPath -LogPath $LogPath -ThresholdValue 50 -ThresholdType MB -FilesToArchive 2
        $Archives = if (Test-Path $BackupPath) { Get-ChildItem -Path $BackupPath -Filter *.tar.gz -ErrorAction SilentlyContinue } else { @() }
        Assert-True ($Archives.Count -eq 0) "No archive should be created under threshold (MB)"
    } finally {
        Cleanup-TestEnv $TestRoot
    }
}

function Test-ExceedThresholdMB {
    Write-Host "TEST: Threshold exceeded (MB)"
    $TestRoot, $LogPath, $BackupPath = Create-TestEnv
    try {
        1..5 | ForEach-Object {
            $f = "$LogPath\old$_.txt"
            Set-Content $f ("x" * 1024 * 1024 * 2)
            (Get-Item $f).LastWriteTime = (Get-Date).AddDays(-$_)
        }
        & $ScriptPath -LogPath $LogPath -ThresholdValue 5 -ThresholdType MB -FilesToArchive 3
        $Archives = if (Test-Path $BackupPath) { Get-ChildItem -Path $BackupPath -Filter *.tar.gz -ErrorAction SilentlyContinue } else { @() }
        Assert-True ($Archives.Count -eq 1) "Archive should be created (MB)"
        Assert-True ($Archives[0].Length -gt 0) "Archive should not be empty (MB)"
    } finally {
        Cleanup-TestEnv $TestRoot
    }
}

function Test-PercentMode {
    Write-Host "TEST: Threshold in Percent mode"
    $TestRoot, $LogPath, $BackupPath = Create-TestEnv
    try {
        1..3 | ForEach-Object {
            Set-Content "$LogPath\pct$_.txt" ("small" * 1000)
        }
        & $ScriptPath -LogPath $LogPath -ThresholdValue 1 -ThresholdType Percent -FilesToArchive 2
    } finally {
        Cleanup-TestEnv $TestRoot
    }
}

function Run-Suite1 {
    Write-Host "`nSuite 1. Running tests: 1"
    Test-NonExistentDirectory
}

function Run-Suite2 {
    Write-Host "`nSuite 2. Running tests: 1, 2"
    Test-NonExistentDirectory
    Test-UnderThresholdMB
}

function Run-Suite3 {
    Write-Host "`nSuite 3. Running tests: 1, 2, 3"
    Test-NonExistentDirectory
    Test-UnderThresholdMB
    Test-ExceedThresholdMB
}

function Run-Suite4 {
    Write-Host "`nSuite 4. Running tests: 1, 2, 4"
    Test-NonExistentDirectory
    Test-UnderThresholdMB
    Test-PercentMode
}

$suites = @(
    @{ Name = "Suite 1"; Func = ${function:Run-Suite1}; Tests = 1 },
    @{ Name = "Suite 2"; Func = ${function:Run-Suite2}; Tests = 2 },
    @{ Name = "Suite 3"; Func = ${function:Run-Suite3}; Tests = 3 },
    @{ Name = "Suite 4"; Func = ${function:Run-Suite4}; Tests = 3 }
)

$totalSuites = $suites.Count
$passedSuites = 0
$failedSuites = 0
$totalTestsRun = 0
$totalTestsPassed = 0
$totalTestsFailed = 0

Write-Host "Starting test execution:"

foreach ($suite in $suites) {
    $suiteName = $suite.Name
    $suiteFunc = $suite.Func
    $expectedTests = $suite.Tests

    Write-Host "`nExecuting $suiteName ($expectedTests tests)"
$suitePassed = $true
    $testsInSuitePassed = 0
    $testsInSuiteFailed = 0

    try {
        & $suiteFunc
        $testsInSuitePassed = $expectedTests
    } catch {
        $suitePassed = $false
        $testsInSuiteFailed = 1
        Write-Host "$suiteName FAILED: $_" -ForegroundColor Red
    }

    if ($suitePassed) {
        $passedSuites++
        $totalTestsPassed += $expectedTests
        Write-Host "$suiteName PASSED" -ForegroundColor Green
    } else {
        $failedSuites++
        $totalTestsFailed += $testsInSuiteFailed
        
    }
    $totalTestsRun += $expectedTests
}
Write-Host ""
Write-Host "Final statistics" -ForegroundColor Blue
Write-Host ""
Write-Host "Total suites executed: $totalSuites"
Write-Host "Suites passed:         $passedSuites"
Write-Host "Suites failed:         $failedSuites"
Write-Host ""
Write-Host "Total tests executed:  $totalTestsRun"
Write-Host "Tests passed:          $totalTestsPassed"
Write-Host "Tests failed:          $totalTestsFailed"
Write-Host ""

if ($failedSuites -gt 0) {
    Write-Host "Some suites failed." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "All suites passed!!!" -ForegroundColor Green
    exit 0
}