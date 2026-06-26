Describe "Controlled execution validation runner" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-controlled-execution-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null

        $script:InvokeControlledExecutionProcess = {
            param(
                [Parameter(Mandatory)]
                [string]$ManifestPath,

                [Parameter(Mandatory)]
                [string]$ReportPath,

                [string]$ExtraArguments = ""
            )

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:RepoRoot\scripts\validate\Test-ControlledExecution.ps1`" -ManifestPath `"$ManifestPath`" -ReportPath `"$ReportPath`" $ExtraArguments"
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

    It "writes a passing report for the baseline manifest" {
        $reportPath = Join-Path $script:TempRoot "controlled-execution.json"
        $process = & $script:InvokeControlledExecutionProcess -ManifestPath "manifests\controlled-execution.json" -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.whatIf $true
        Assert-KitMatch $process.stdout "Controlled execution report written"
    }

    It "exits one when a mutation action is declared" {
        $reportPath = Join-Path $script:TempRoot "blocked-mutation.json"
        $process = & $script:InvokeControlledExecutionProcess -ManifestPath "tests\fixtures\controlled-execution\sample-blocked-mutation.json" -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 1
        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.blockedActionCount 1
    }

    It "exits one when true execution is enabled" {
        $reportPath = Join-Path $script:TempRoot "true-execution-enabled.json"
        $process = & $script:InvokeControlledExecutionProcess -ManifestPath "tests\fixtures\controlled-execution\failure\true-execution-enabled.json" -ReportPath $reportPath
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 1
        Assert-KitEqual $report.status "failed"
        Assert-KitEqual $report.summary.failedCount 1
    }

    It "exits one for disk identity, token, image, recovery, and native plan failures" {
        $cases = @(
            @{ Name = "disk"; Args = "-DiskIdentityPath `"tests\fixtures\controlled-execution\disk-identity\serial-mismatch.json`""; Count = "diskIdentityMismatchCount" },
            @{ Name = "token"; Args = "-ConfirmationTokenPath `"tests\fixtures\controlled-execution\confirmation-token\generic-yes.json`""; Count = "confirmationTokenFailureCount" },
            @{ Name = "image"; Args = "-WimMetadataPath `"tests\fixtures\controlled-execution\wim-image\hash-mismatch.json`""; Count = "wimValidationFailureCount" },
            @{ Name = "recovery"; Args = "-WinREPlanPath `"tests\fixtures\controlled-execution\winre-plan\wrong-gpt-type.json`""; Count = "winrePlanFailureCount" },
            @{ Name = "native"; Args = "-NativeCommandPlanPath `"tests\fixtures\controlled-execution\native-command\actual-exitcode-present.json`""; Count = "nativeCommandFailureCount" }
        )

        foreach ($case in $cases) {
            $reportPath = Join-Path $script:TempRoot ("{0}.json" -f $case.Name)
            $process = & $script:InvokeControlledExecutionProcess -ManifestPath "manifests\controlled-execution.json" -ReportPath $reportPath -ExtraArguments $case.Args
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $process.exitCode 1
            Assert-KitEqual $report.status "failed"
            if ($report.summary.($case.Count) -lt 1) {
                throw "Expected $($case.Count) to be greater than zero."
            }
        }
    }
}
