Describe "Quality gate validation runner" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-quality-gates-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null

        $script:InvokeQualityGateProcess = {
            param(
                [Parameter(Mandatory)]
                [string]$ManifestPath,

                [Parameter(Mandatory)]
                [string]$ReportPath
            )

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:RepoRoot\scripts\validate\Test-QualityGates.ps1`" -ManifestPath `"$ManifestPath`" -ReportPath `"$ReportPath`""
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

    It "writes a manual report and exits zero for the checked-in manifest" {
        $reportPath = Join-Path $script:TempRoot "quality-gates-report.json"

        $process = & $script:InvokeQualityGateProcess -ManifestPath "manifests\quality-gates.json" -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.status "manual"
        Assert-KitEqual $report.summary.failedCount 0
        Assert-KitMatch $process.stdout "Quality gates report written"
    }

    It "writes a failed report and exits one for policy failures" {
        $manifestPath = Join-Path $script:TempRoot "failed-quality-gates.json"
        $reportPath = Join-Path $script:TempRoot "failed-quality-gates-report.json"
        $manifest = [pscustomobject]@{
            manifestVersion = 1
            gates = @([pscustomobject]@{
                id = "bad-entrypoint"
                displayName = "Bad entrypoint"
                layer = "pr-fast"
                trigger = "pull_request"
                mode = "static"
                required = $true
                blocking = $true
                entrypoint = "missing\entrypoint.txt"
                evidence = "report"
                notes = "fixture"
            })
        }
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

        $process = & $script:InvokeQualityGateProcess -ManifestPath $manifestPath -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 1
        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.failedCount 1
    }
}
