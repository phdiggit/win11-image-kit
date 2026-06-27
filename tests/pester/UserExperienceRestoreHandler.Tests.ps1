Describe "Restore-UserExperience handler entrypoint" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-ux-restore-handler-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
        $script:PowerShell = (Get-Command powershell -ErrorAction Stop).Source
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "defaults to report-only handler output under WhatIf" {
        $reportPath = Join-Path $script:TempRoot "restore-user-experience.json"
        & $script:PowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:RepoRoot "scripts\postdeploy\Restore-UserExperience.ps1") -WhatIf -ReportPath $reportPath | Out-Null
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $report.reportType "restore-user-experience"
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.summary.handlerExecutionCount 0
        Assert-KitEqual $report.summary.registryWriteCount 0
        Assert-KitEqual $report.summary.profileWriteCount 0
        Assert-KitEqual (@($report.handlers).Count -gt 0) $true
    }

    It "blocks Apply and Execute requests" {
        foreach ($switchName in @("Apply", "Execute")) {
            $reportPath = Join-Path $script:TempRoot "$switchName.json"
            $scriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Restore-UserExperience.ps1"
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $script:PowerShell
            $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -WhatIf -ReportPath `"$reportPath`" -$switchName"
            $processInfo.WorkingDirectory = $script:RepoRoot
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.UseShellExecute = $false
            $process = [System.Diagnostics.Process]::Start($processInfo)
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $standardOutput.Contains("restore-user-experience") $true
            Assert-KitEqual $standardError ""
            Assert-KitEqual $process.ExitCode 1
            Assert-KitEqual $report.requestedApply $true
            Assert-KitEqual ([int]$report.summary.requestedApplyBlockedCount -gt 0) $true
            Assert-KitEqual $report.trueExecution $false
        }
    }
}
