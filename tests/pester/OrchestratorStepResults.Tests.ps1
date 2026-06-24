$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

function Get-KitTestPowerShell {
    $powerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
    if ([string]::IsNullOrWhiteSpace($powerShell)) {
        $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
    }

    return $powerShell
}

function New-KitTempPath {
    param(
        [Parameter(Mandatory)]
        [string]$Extension
    )

    return (Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-orchestrator-{0}{1}" -f ([guid]::NewGuid().ToString("N")), $Extension))
}

function Assert-KitNoCompletedStepResult {
    param(
        [Parameter(Mandatory)]
        $Report
    )

    $completed = @($Report.stepResults | Where-Object { $_.status -eq "completed" })
    Assert-KitEqual $completed.Count 0
}

Describe "Orchestrator StepResult reports" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "writes build skipped StepResults while preserving legacy summary" {
        $powerShell = Get-KitTestPowerShell
        $reportPath = New-KitTempPath -Extension ".json"
        $logPath = New-KitTempPath -Extension ".log"

        try {
            $scriptPath = Join-Path $RepoRoot "scripts\build\Invoke-GoldenImageBuild.ps1"
            & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -WhatIf `
                -SkipPortableApps `
                -SkipSystemTweaks `
                -SkipDevRuntime `
                -SkipMiddleware `
                -ReportPath $reportPath `
                -LogPath $logPath 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE

            Assert-KitEqual $exitCode 0
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $reportPath -ErrorAction SilentlyContinue)

            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-KitNotNullOrEmpty $report.steps
            Assert-KitNotNullOrEmpty $report.stepResults
            Assert-KitNotNullOrEmpty $report.stepSummary
            if ($report.summary.skipped -le 0) {
                throw "Expected legacy summary.skipped to be greater than 0."
            }
            if ($report.stepSummary.statusCounts.skipped -le 0) {
                throw "Expected stepSummary.statusCounts.skipped to be greater than 0."
            }

            Assert-KitEqual $report.stepSummary.exitCode 0
            Assert-KitNoCompletedStepResult -Report $report
            Assert-KitNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $RepoRoot "logs") -Filter "project-config-validation-*" -ErrorAction SilentlyContinue)
        } finally {
            Remove-Item -LiteralPath $reportPath,$logPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes postdeploy WhatIf StepResults and keeps report paths" {
        $powerShell = Get-KitTestPowerShell
        $summaryPath = New-KitTempPath -Extension ".json"
        $installerPath = New-KitTempPath -Extension ".json"
        $userExperiencePath = New-KitTempPath -Extension ".json"
        $logPath = New-KitTempPath -Extension ".log"

        try {
            $scriptPath = Join-Path $RepoRoot "scripts\postdeploy\Invoke-PostDeploy.ps1"
            & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -WhatIf `
                -SummaryReportPath $summaryPath `
                -ReportPath $installerPath `
                -UserExperienceReportPath $userExperiencePath `
                -LogPath $logPath 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE

            Assert-KitEqual $exitCode 0
            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $summaryPath -ErrorAction SilentlyContinue)

            $report = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-KitNotNullOrEmpty $report.steps
            Assert-KitNotNullOrEmpty $report.stepResults
            Assert-KitNotNullOrEmpty $report.stepSummary
            Assert-KitEqual $report.installerReportPath $installerPath
            Assert-KitEqual $report.userExperienceReportPath $userExperiencePath
            if ($report.stepSummary.statusCounts.whatif -le 0) {
                throw "Expected postdeploy WhatIf to produce at least one whatif StepResult."
            }

            Assert-KitEqual $report.stepSummary.exitCode 0
            Assert-KitNoCompletedStepResult -Report $report
        } finally {
            Remove-Item -LiteralPath $summaryPath,$installerPath,$userExperiencePath,$logPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "records failed StepResults before rethrowing blocking errors" {
        $powerShell = Get-KitTestPowerShell
        $scopePath = New-KitTempPath -Extension ".json"
        $summaryPath = New-KitTempPath -Extension ".json"
        $installerPath = New-KitTempPath -Extension ".json"
        $userExperiencePath = New-KitTempPath -Extension ".json"
        $logPath = New-KitTempPath -Extension ".log"

        try {
            $defaultScopePath = Join-Path $RepoRoot "manifests\customization-scope.json"
            $scope = Get-Content -LiteralPath $defaultScopePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $scope.profile = "pester-missing-software-manifest"
            $scope.system.windowsDefender.mode = "disabled"
            $scope.applications.softwareManifest = "manifests/__missing_software_for_pester__.json"
            Set-Content -LiteralPath $scopePath -Value ($scope | ConvertTo-Json -Depth 12) -Encoding UTF8

            $scriptPath = Join-Path $RepoRoot "scripts\postdeploy\Invoke-PostDeploy.ps1"
            & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -WhatIf `
                -ScopeManifestPath $scopePath `
                -SummaryReportPath $summaryPath `
                -ReportPath $installerPath `
                -UserExperienceReportPath $userExperiencePath `
                -LogPath $logPath 2>&1 | Out-Null
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {
                throw "Expected postdeploy to return a non-zero exit code for a missing software manifest."
            }

            Assert-KitNotNullOrEmpty (Get-ChildItem -LiteralPath $summaryPath -ErrorAction SilentlyContinue)
            $report = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $failedResults = @($report.stepResults | Where-Object { $_.status -eq "failed" })

            if ($failedResults.Count -le 0) {
                throw "Expected at least one failed StepResult."
            }

            Assert-KitNotNullOrEmpty $failedResults[0].reason
            Assert-KitNotNullOrEmpty $failedResults[0].errors
            Assert-KitEqual $report.stepSummary.exitCode 1
            Assert-KitNoCompletedStepResult -Report $report
        } finally {
            Remove-Item -LiteralPath $scopePath,$summaryPath,$installerPath,$userExperiencePath,$logPath -Force -ErrorAction SilentlyContinue
        }
    }
}
