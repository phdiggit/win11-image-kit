$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")
. (Join-Path $RepoRoot "scripts\common\Get-KitChildReportSummary.ps1")

Describe "Report blocking summary" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Get-KitChildReportSummary.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:TempPaths = @()

        $script:NewReportReference = {
            param(
                [Parameter(Mandatory)]
                [string]$SummaryPropertyName,

                [int]$FailedRequired = 0,

                [int]$FailedOptional = 0,

                [bool]$Required = $true,

                [bool]$Exists = $true,

                [AllowEmptyString()]
                [string]$Error = ""
            )

            $reference = [ordered]@{
                name = "fake-child"
                stepName = "fake-step"
                reportType = "fake-report"
                path = "fake.json"
                required = $Required
                exists = $Exists
                error = $Error
            }

            if ($Exists -and [string]::IsNullOrWhiteSpace($Error)) {
                $reference[$SummaryPropertyName] = [pscustomobject]@{
                    failedRequiredCount = $FailedRequired
                    failedOptionalCount = $FailedOptional
                    statusCounts = [pscustomobject]@{
                        changed = 0
                        unchanged = 0
                        skipped = 0
                        manual = 0
                        whatif = 0
                        failed = $FailedRequired + $FailedOptional
                    }
                    hasBlockingFailure = $FailedRequired -gt 0
                    exitCode = if ($FailedRequired -gt 0) { 1 } else { 0 }
                }
            }

            return [pscustomobject]$reference
        }

        $script:NewTempPath = {
            param(
                [Parameter(Mandatory)]
                [string]$Extension
            )

            $path = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-report-blocking-{0}{1}" -f ([guid]::NewGuid().ToString("N")), $Extension)
            $script:TempPaths += $path
            return $path
        }
    }

    AfterAll {
        foreach ($path in $script:TempPaths) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    It "marks package required child failures as blocking" {
        $summary = Get-KitChildReportBlockingSummary -PackageReports @(
            & $script:NewReportReference -SummaryPropertyName "packageSummary" -FailedRequired 1
        )

        Assert-KitEqual $summary.failedRequired 1
        Assert-KitEqual $summary.hasBlockingFailure $true
        Assert-KitEqual $summary.exitCode 1
        Assert-KitEqual $summary.byType.package.failedRequired 1
    }

    It "marks service, junction, defender, and user experience required child failures as blocking" {
        $summary = Get-KitChildReportBlockingSummary `
            -ServiceReports @(& $script:NewReportReference -SummaryPropertyName "serviceSummary" -FailedRequired 1) `
            -JunctionReports @(& $script:NewReportReference -SummaryPropertyName "junctionSummary" -FailedRequired 1) `
            -DefenderReports @(& $script:NewReportReference -SummaryPropertyName "defenderSummary" -FailedRequired 1) `
            -UserExperienceReports @(& $script:NewReportReference -SummaryPropertyName "userExperienceSummary" -FailedRequired 1)

        Assert-KitEqual $summary.failedRequired 4
        Assert-KitEqual $summary.hasBlockingFailure $true
        Assert-KitEqual $summary.exitCode 1
        Assert-KitEqual $summary.byType.service.failedRequired 1
        Assert-KitEqual $summary.byType.junction.failedRequired 1
        Assert-KitEqual $summary.byType.defender.failedRequired 1
        Assert-KitEqual $summary.byType.userExperience.failedRequired 1
    }

    It "counts optional child failures without blocking" {
        $summary = Get-KitChildReportBlockingSummary -PackageReports @(
            & $script:NewReportReference -SummaryPropertyName "packageSummary" -FailedOptional 1 -Required $false
        )

        Assert-KitEqual $summary.failedRequired 0
        Assert-KitEqual $summary.failedOptional 1
        Assert-KitEqual $summary.hasBlockingFailure $false
        Assert-KitEqual $summary.exitCode 0
    }

    It "treats missing required child reports as blocking" {
        $summary = Get-KitChildReportBlockingSummary -PackageReports @(
            & $script:NewReportReference -SummaryPropertyName "packageSummary" -Exists $false -Required $true -Error "report-missing"
        )

        Assert-KitEqual $summary.reports 1
        Assert-KitEqual $summary.existing 0
        Assert-KitEqual $summary.missing 1
        Assert-KitEqual $summary.failedRequired 1
        Assert-KitEqual $summary.hasBlockingFailure $true
        Assert-KitEqual $summary.exitCode 1
    }

    It "treats parse failed required child reports as blocking" {
        $summary = Get-KitChildReportBlockingSummary -PackageReports @(
            & $script:NewReportReference -SummaryPropertyName "packageSummary" -Exists $true -Required $true -Error "report-parse-failed"
        )

        Assert-KitEqual $summary.existing 1
        Assert-KitEqual $summary.missing 0
        Assert-KitEqual $summary.failedRequired 1
        Assert-KitEqual $summary.hasBlockingFailure $true
        Assert-KitEqual $summary.exitCode 1
    }

    It "keeps child report references compact without embedded result arrays" {
        $reportPath = & $script:NewTempPath ".json"
        $childReport = [pscustomobject]@{
            packageSummary = [pscustomobject]@{
                failedRequiredCount = 0
                failedOptionalCount = 0
                exitCode = 0
                results = @([pscustomobject]@{ name = "should-not-be-copied" })
            }
            packageResults = @([pscustomobject]@{ name = "full-result" })
        }
        $childReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8

        $reference = Get-KitPackageReportReference -Name "package" -StepName "package" -Path $reportPath -Required

        Assert-KitEqual ($reference.PSObject.Properties.Name -contains "packageResults") $false
        Assert-KitEqual ($reference.packageSummary.PSObject.Properties.Name -contains "results") $false
    }

    It "writes unified child summary lines to top-level markdown reports" {
        $reportPath = & $script:NewTempPath ".md"
        $logPath = & $script:NewTempPath ".log"
        $stdoutPath = & $script:NewTempPath ".out"
        $stderrPath = & $script:NewTempPath ".err"
        $scriptPath = Join-Path $script:RepoRoot "scripts\build\Invoke-GoldenImageBuild.ps1"

        try {
            & $script:PowerShell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -WhatIf `
                -SkipPortableApps `
                -SkipSystemTweaks `
                -SkipDevRuntime `
                -SkipMiddleware `
                -ReportPath $reportPath `
                -LogPath $logPath 1> $stdoutPath 2> $stderrPath

            Assert-KitEqual $LASTEXITCODE 0
            $markdown = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
            foreach ($expectedSnippet in @(
                "required",
                "optional",
                "exitCode"
            )) {
                if (-not $markdown.Contains($expectedSnippet)) {
                    throw "Expected markdown to contain <$expectedSnippet>."
                }
            }
        } finally {
            Remove-Item -LiteralPath $reportPath,$logPath,$stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
}
