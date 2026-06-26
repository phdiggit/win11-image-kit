Describe "Evidence chain validation runner" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-evidence-chain-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null

        $script:InvokeEvidenceChainProcess = {
            param(
                [Parameter(Mandatory)]
                [string]$ReportPath,

                [string]$InputDirectory = "tests\fixtures\evidence-chain\sample-report-inputs",

                [string]$SourceSha = "5688a741e98a29572a99dc1e025b9f97c7876dc3"
            )

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:RepoRoot\scripts\validate\Test-EvidenceChain.ps1`" -InputDirectory `"$InputDirectory`" -ReportPath `"$ReportPath`" -SourceSha `"$SourceSha`""
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
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "writes a baseline report and exits zero when failedCount is zero" {
        $reportPath = Join-Path $script:TempRoot "evidence-chain.json"
        $process = & $script:InvokeEvidenceChainProcess -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitEqual $report.summary.manualCount 1
        Assert-KitEqual $report.summary.notCapturedCount 3
        Assert-KitMatch $process.stdout "Evidence chain report written"
    }

    It "exits one when a producer fixture reports failure" {
        $inputRoot = Join-Path $script:TempRoot "inputs"
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\evidence-chain\sample-report-inputs") -Destination $inputRoot -Recurse
        $failedPath = Join-Path $inputRoot "project-config.json"
        $failed = Get-Content -LiteralPath $failedPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $failed.status = "failed"
        $failed | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $failedPath -Encoding UTF8

        $reportPath = Join-Path $script:TempRoot "failed-evidence-chain.json"
        $process = & $script:InvokeEvidenceChainProcess -InputDirectory $inputRoot -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 1
        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.failedCount 1
    }

    It "rejects invalid source SHA and invalid workflow URL" {
        $reportPath = Join-Path $script:TempRoot "invalid-sha.json"
        $process = & $script:InvokeEvidenceChainProcess -ReportPath $reportPath -SourceSha "bad-sha"

        Assert-KitEqual $process.exitCode 1
        Assert-KitMatch $process.stdout "SourceSha must be a 40-character Git SHA"
    }
}
