Describe "Evidence chain producer adapter" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-evidence-adapter-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null

        $script:InvokeEvidenceChain = {
            param(
                [Parameter(Mandatory)]
                [string]$InputManifestPath
            )

            $reportPath = Join-Path $script:TempRoot ("report-{0}.json" -f ([IO.Path]::GetFileNameWithoutExtension($InputManifestPath)))
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:RepoRoot\scripts\validate\Test-EvidenceChain.ps1`" -InputManifestPath `"$InputManifestPath`" -ReportPath `"$reportPath`""
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
                report = if (Test-Path -LiteralPath $reportPath) { Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
            }
        }
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "fails when a required producer input is missing" {
        $result = & $script:InvokeEvidenceChain -InputManifestPath "tests/fixtures/evidence-chain/failure-inputs/missing-required/project-config.json"

        Assert-KitEqual $result.exitCode 1
        Assert-KitEqual ($result.report.producerNormalization.missingRequiredCount -gt 0) $true
        Assert-KitMatch $result.stdout "producerNormalization.missingRequiredCount must be zero"
    }

    It "fails when reportType does not match the producer contract" {
        $result = & $script:InvokeEvidenceChain -InputManifestPath "tests/fixtures/evidence-chain/failure-inputs/report-type-mismatch/project-config.json"

        Assert-KitEqual $result.exitCode 1
        Assert-KitEqual ($result.report.producerNormalization.reportTypeMismatchCount -gt 0) $true
        Assert-KitMatch $result.stdout "producerNormalization.reportTypeMismatchCount must be zero"
    }

    It "fails when a report-only producer reports failure" {
        $result = & $script:InvokeEvidenceChain -InputManifestPath "tests/fixtures/evidence-chain/failure-inputs/failed-producer/project-config.json"

        Assert-KitEqual $result.exitCode 1
        Assert-KitEqual ($result.report.summary.failedCount -gt 0) $true
    }

    It "fails when report-only producers are manual or not-captured" {
        $manual = & $script:InvokeEvidenceChain -InputManifestPath "tests/fixtures/evidence-chain/failure-inputs/disallowed-manual/project-config.json"
        $notCaptured = & $script:InvokeEvidenceChain -InputManifestPath "tests/fixtures/evidence-chain/failure-inputs/disallowed-not-captured/project-config.json"

        Assert-KitEqual $manual.exitCode 1
        Assert-KitEqual ($manual.report.producerNormalization.disallowedManualCount -gt 0) $true
        Assert-KitEqual $notCaptured.exitCode 1
        Assert-KitEqual ($notCaptured.report.producerNormalization.disallowedNotCapturedCount -gt 0) $true
    }

    It "fails invalid input paths and unknown producers" {
        $badPaths = & $script:InvokeEvidenceChain -InputManifestPath "tests/fixtures/evidence-chain/failure-inputs/bad-paths/project-config.json"
        $unknownProducer = & $script:InvokeEvidenceChain -InputManifestPath "tests/fixtures/evidence-chain/failure-inputs/unknown-producer/project-config.json"

        Assert-KitEqual $badPaths.exitCode 1
        Assert-KitEqual ($badPaths.report.producerNormalization.inputPolicyViolationCount -gt 0) $true
        Assert-KitEqual $unknownProducer.exitCode 1
        Assert-KitEqual ($unknownProducer.report.producerNormalization.unmatchedInputCount -gt 0) $true
    }
}
