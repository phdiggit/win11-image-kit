$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")

Describe "Orchestrator StepResult reports" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:TestPowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:TestPowerShell)) {
            $script:TestPowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:NewOrchestratorTempPath = {
            param(
                [Parameter(Mandatory)]
                [string]$Extension
            )

            $root = Join-Path $script:RepoRoot ".tmp\pester-orchestrator"
            [IO.Directory]::CreateDirectory($root) | Out-Null

            return (Join-Path $root ("win11-image-kit-orchestrator-{0}{1}" -f ([guid]::NewGuid().ToString("N")), $Extension))
        }
    }

    It "writes build skipped StepResults while preserving legacy summary" {
        $powerShell = $script:TestPowerShell
        $reportPath = & $script:NewOrchestratorTempPath ".json"
        $logPath = & $script:NewOrchestratorTempPath ".log"
        $stdoutPath = & $script:NewOrchestratorTempPath ".out"
        $stderrPath = & $script:NewOrchestratorTempPath ".err"

        try {
            $scriptPath = Join-Path $script:RepoRoot "scripts\build\Invoke-GoldenImageBuild.ps1"
            & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -WhatIf `
                -SkipPortableApps `
                -SkipSystemTweaks `
                -SkipDevRuntime `
                -SkipMiddleware `
                -ReportPath $reportPath `
                -LogPath $logPath 1> $stdoutPath 2> $stderrPath
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
            Assert-KitEqual @($report.stepResults | Where-Object { $_.status -eq "completed" }).Count 0
            Assert-KitNullOrEmpty (Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot "logs") -Filter "project-config-validation-*" -ErrorAction SilentlyContinue)
        } finally {
            Remove-Item -LiteralPath $reportPath,$logPath,$stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "writes postdeploy WhatIf StepResults and keeps report paths" {
        $powerShell = $script:TestPowerShell
        $summaryPath = & $script:NewOrchestratorTempPath ".json"
        $installerPath = & $script:NewOrchestratorTempPath ".json"
        $userExperiencePath = & $script:NewOrchestratorTempPath ".json"
        $logPath = & $script:NewOrchestratorTempPath ".log"
        $stdoutPath = & $script:NewOrchestratorTempPath ".out"
        $stderrPath = & $script:NewOrchestratorTempPath ".err"

        try {
            $scriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Invoke-PostDeploy.ps1"
            & $powerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -WhatIf `
                -SummaryReportPath $summaryPath `
                -ReportPath $installerPath `
                -UserExperienceReportPath $userExperiencePath `
                -LogPath $logPath 1> $stdoutPath 2> $stderrPath
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
            Assert-KitEqual @($report.stepResults | Where-Object { $_.status -eq "completed" }).Count 0
        } finally {
            Remove-Item -LiteralPath $summaryPath,$installerPath,$userExperiencePath,$logPath,$stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "records failed StepResults before rethrowing blocking errors" {
        $powerShell = $script:TestPowerShell
        $scopePath = & $script:NewOrchestratorTempPath ".json"
        $summaryPath = & $script:NewOrchestratorTempPath ".json"
        $installerPath = & $script:NewOrchestratorTempPath ".json"
        $userExperiencePath = & $script:NewOrchestratorTempPath ".json"
        $logPath = & $script:NewOrchestratorTempPath ".log"
        $stdoutPath = & $script:NewOrchestratorTempPath ".out"
        $stderrPath = & $script:NewOrchestratorTempPath ".err"

        try {
            $defaultScopePath = Join-Path $script:RepoRoot "manifests\customization-scope.json"
            $scope = Get-Content -LiteralPath $defaultScopePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $scope.profile = "pester-missing-software-manifest"
            $scope.system.windowsDefender.mode = "disabled"
            $scope.applications.softwareManifest = "manifests/__missing_software_for_pester__.json"
            Set-Content -LiteralPath $scopePath -Value ($scope | ConvertTo-Json -Depth 12) -Encoding UTF8

            $scriptPath = Join-Path $script:RepoRoot "scripts\postdeploy\Invoke-PostDeploy.ps1"
            $command = @"
try {
    & '$scriptPath' -WhatIf -ScopeManifestPath '$scopePath' -SummaryReportPath '$summaryPath' -ReportPath '$installerPath' -UserExperienceReportPath '$userExperiencePath' -LogPath '$logPath'
    exit 0
} catch {
    exit 1
}
"@
            & $powerShell -NoProfile -ExecutionPolicy Bypass -Command $command 1> $stdoutPath 2> $stderrPath
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
            Assert-KitEqual @($report.stepResults | Where-Object { $_.status -eq "completed" }).Count 0
        } finally {
            Remove-Item -LiteralPath $scopePath,$summaryPath,$installerPath,$userExperiencePath,$logPath,$stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
}
