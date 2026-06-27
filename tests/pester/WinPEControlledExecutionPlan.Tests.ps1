Describe "WinPE controlled execution plan entrypoint" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:Entrypoint = Join-Path $script:RepoRoot "scripts\winpe\New-WinPEControlledExecutionPlan.ps1"

        $script:InvokeWinPEPlanProcess = {
            param([string]$Arguments = "")

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:Entrypoint`" $Arguments"
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

    It "defaults to plan-only JSON output" {
        $process = & $script:InvokeWinPEPlanProcess
        $report = $process.stdout | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.reportType "winpe-controlled-execution-plan"
        Assert-KitEqual $report.whatIf $true
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.executeRequested $false
        Assert-KitEqual $report.status "blocked"
    }

    It "blocks Execute even when future contract parameters are present" {
        $args = "-PlanOnly -Execute -TargetDiskNumber 0 -ExpectedDiskSerial SAMPLE-DISK-SERIAL-001 -ExpectedDiskSize 107374182400 -ImageSha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef -ImageIndex 1 -ImageArchitecture amd64 -ConfirmationToken confirm-SAMPLE-DISK-SERIAL-001 -SourceRunId kit-run-20260626T000000Z-0000000"
        $process = & $script:InvokeWinPEPlanProcess -Arguments $args
        $report = $process.stdout | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.status "blocked"
        Assert-KitEqual $report.executeRequested $true
        Assert-KitEqual $report.trueExecution $false
        Assert-KitMatch $report.reason "not implemented/enabled"
    }

    It "plans without execution when all future contract parameters are present" {
        $args = "-PlanOnly -TargetDiskNumber 0 -ExpectedDiskSerial SAMPLE-DISK-SERIAL-001 -ExpectedDiskSize 107374182400 -ImageSha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef -ImageIndex 1 -ImageArchitecture amd64 -ConfirmationToken confirm-SAMPLE-DISK-SERIAL-001 -SourceRunId kit-run-20260626T000000Z-0000000"
        $process = & $script:InvokeWinPEPlanProcess -Arguments $args
        $report = $process.stdout | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.status "planned"
        Assert-KitEqual $report.stageResults[0].executed $false
        Assert-KitEqual $report.authorization.trueExecutionAllowed $false
    }
}
