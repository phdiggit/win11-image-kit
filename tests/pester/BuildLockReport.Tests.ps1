Describe "Build lock report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitBuildLockReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-build-lock-report-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory((Join-Path $script:TempRoot "manifests")) | Out-Null
        [IO.Directory]::CreateDirectory((Join-Path $script:TempRoot "scripts\common")) | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $script:TempRoot "manifests\a.json"), [byte[]](97, 98, 99))
        [IO.File]::WriteAllBytes((Join-Path $script:TempRoot "scripts\common\new.ps1"), [byte[]](110, 101, 119))
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    function New-TestReportLock {
        param(
            [string]$Path = "manifests/a.json",
            [string]$Hash = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            [string]$UntrackedPolicy = "manual"
        )

        [pscustomobject]@{
            lockVersion = 1
            algorithm = "SHA256"
            mode = "verify"
            entries = @([pscustomobject]@{
                path = $Path
                category = "manifest"
                required = $true
                hash = $Hash
                reason = "fixture"
            })
            watchGlobs = @("scripts/common/*.ps1")
            policy = [pscustomobject]@{
                missingRequired = "fail"
                hashMismatch = "fail"
                untrackedWatchedFile = $UntrackedPolicy
                unsupportedAlgorithm = "fail"
            }
        }
    }

    function Invoke-TestBuildLockProcess {
        param(
            [Parameter(Mandatory)]
            [string]$LockPath,

            [Parameter(Mandatory)]
            [string]$ReportPath
        )

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:RepoRoot\scripts\validate\Test-BuildLock.ps1`" -LockPath `"$LockPath`" -ReportPath `"$ReportPath`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $process = [System.Diagnostics.Process]::Start($psi)
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        [pscustomobject]@{
            exitCode = $process.ExitCode
            stdout = $stdout
            stderr = $stderr
        }
    }

    It "creates a build-lock report with counts and untracked details" {
        $report = New-KitBuildLockReport -BuildLock (New-TestReportLock) -RepoRoot $script:TempRoot -WhatIf

        Assert-KitEqual $report.reportType "build-lock"
        Assert-KitEqual $report.status "manual"
        Assert-KitEqual $report.summary.total 2
        Assert-KitEqual $report.summary.passedCount 1
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitEqual $report.summary.untrackedWatchedCount 1
        Assert-KitEqual (@($report.untrackedWatchedFiles) -contains "scripts/common/new.ps1") $true
        Assert-KitEqual $report.whatIf $true
    }

    It "keeps missing and mismatch details and serializes JSON" {
        $missingReport = New-KitBuildLockReport -BuildLock (New-TestReportLock -Path "manifests/missing.json" -UntrackedPolicy "pass") -RepoRoot $script:TempRoot -WhatIf
        $mismatchReport = New-KitBuildLockReport -BuildLock (New-TestReportLock -Hash ("0" * 64) -UntrackedPolicy "pass") -RepoRoot $script:TempRoot -WhatIf
        $json = $mismatchReport | ConvertTo-Json -Depth 12

        Assert-KitEqual $missingReport.summary.missingCount 1
        Assert-KitEqual $missingReport.status "failed"
        Assert-KitEqual $mismatchReport.summary.mismatchCount 1
        Assert-KitEqual $mismatchReport.status "failed"
        Assert-KitMatch $json "build-lock"
        Assert-KitMatch $json "hash mismatch"
    }

    It "writes explicit reports and returns expected exit codes" {
        $manualLockPath = Join-Path $script:TempRoot "manual-lock.json"
        $manualReportPath = Join-Path $script:TempRoot "manual-report.json"
        $failedLockPath = Join-Path $script:TempRoot "failed-lock.json"
        $failedReportPath = Join-Path $script:TempRoot "failed-report.json"
        $absoluteExistingPath = Join-Path $script:TempRoot "manifests\a.json"
        $absoluteMissingPath = Join-Path $script:TempRoot "manifests\missing.json"

        (New-TestReportLock -Path $absoluteExistingPath -UntrackedPolicy "manual") | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manualLockPath -Encoding UTF8
        (New-TestReportLock -Path $absoluteMissingPath -UntrackedPolicy "pass") | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $failedLockPath -Encoding UTF8

        $manualProcess = Invoke-TestBuildLockProcess -LockPath $manualLockPath -ReportPath $manualReportPath
        $failedProcess = Invoke-TestBuildLockProcess -LockPath $failedLockPath -ReportPath $failedReportPath
        $manualReport = Get-Content -LiteralPath $manualReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $failedReport = Get-Content -LiteralPath $failedReportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $manualProcess.exitCode 0
        Assert-KitEqual $manualReport.status "manual"
        Assert-KitEqual $failedProcess.exitCode 1
        Assert-KitEqual $failedReport.status "failed"
    }
}
