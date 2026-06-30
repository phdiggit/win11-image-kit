Describe "Controlled execution long-term safety contract" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
        $script:WinPEEntrypoint = Join-Path $script:RepoRoot "scripts\winpe\New-WinPEControlledExecutionPlan.ps1"

        $script:InvokeWinPEPlanProcess = {
            param([string]$Arguments = "")

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script:WinPEEntrypoint`" $Arguments"
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

    It "blocks network, registry, and disk fixture actions" {
        foreach ($path in @(
            "tests\fixtures\controlled-execution\failure\network-download-action.json",
            "tests\fixtures\controlled-execution\failure\registry-mutation-action.json",
            "tests\fixtures\controlled-execution\failure\disk-mutation-action.json"
        )) {
            $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $report = New-KitControlledExecutionReport -Manifest $manifest -RepoRoot $script:RepoRoot -WhatIf

            Assert-KitEqual $report.status "failed"
            Assert-KitEqual $report.summary.blockedActionCount 1
            Assert-KitEqual @($report.actions | Where-Object { $_.executed }).Count 0
        }
    }

    It "keeps dangerous command names out of new Issue 17 scripts" {
        $dangerousPattern = "\bDism(\.exe)?\b|\bsysprep\b|\bGet-AppxPackage\b|\bRemove-AppxPackage\b|\bAdd-AppxPackage\b|\bAdd-MpPreference\b|\bRemove-MpPreference\b|\bNew-ItemProperty\b|\bSet-ItemProperty\b|\bRemove-ItemProperty\b|\bStart-Service\b|\bStop-Service\b|\bSet-Service\b|\bNew-Service\b|\bsc\.exe\b|\bbcdedit\b|\bformat\b|\bclean\b|\bInitialize-Disk\b|\bNew-Partition\b|\bSet-Partition\b|\bFormat-Volume\b|\bGet-PhysicalDisk\b|\bGet-Disk\b|\bdiskpart\b|\bbcdboot\b|\breagentc\b|\bInvoke-Expression\b|\bInvoke-WebRequest\b|\bInvoke-RestMethod\b|\bInstall-Module\b|\bwinget\b|\bchoco\b|\bmsiexec\b|Start-Process"
        foreach ($path in @(
            "scripts\common\New-KitControlledExecutionReport.ps1",
            "scripts\common\Test-KitControlledExecutionSafety.ps1",
            "scripts\common\ConvertTo-KitDiskIdentityPlan.ps1",
            "scripts\common\Test-KitConfirmationToken.ps1",
            "scripts\common\ConvertTo-KitWimImagePlan.ps1",
            "scripts\common\ConvertTo-KitWinREPlan.ps1",
            "scripts\common\New-KitNativeCommandPlan.ps1",
            "scripts\validate\Test-ControlledExecution.ps1",
            "scripts\config\Show-ControlledExecutionPlan.ps1"
        )) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8
            Assert-KitNotMatch $content $dangerousPattern
        }
    }

    It "allows native tool names only in fixture planned strings" {
        $fixtureText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command\planned.json") -Raw -Encoding UTF8
        Assert-KitMatch $fixtureText "plannedCommand"
        Assert-KitMatch $fixtureText "not-run"
        Assert-KitMatch $fixtureText "not-captured"
    }

    It "keeps paths.local.json out of the build lock" {
        $lock = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\build-lock.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $paths = @($lock.entries | ForEach-Object { $_.path })

        if ($paths -contains "manifests/paths.local.json") {
            throw "Build Lock must not include manifests/paths.local.json."
        }
    }

    It "keeps the baseline execution set plan-only and dependency-aware" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\controlled-execution.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $diskIdentity = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\disk-identity\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $confirmationToken = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\confirmation-token\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $wimMetadata = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\wim-image\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $winREPlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\winre-plan\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $nativeCommandPlan = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $authorization = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\authorization\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $nativeCommandSimulation = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command-simulation\baseline-success.json") -Raw -Encoding UTF8 | ConvertFrom-Json

        $report = New-KitControlledExecutionReport `
            -Manifest $manifest `
            -RepoRoot $script:RepoRoot `
            -DiskIdentity $diskIdentity `
            -ConfirmationToken $confirmationToken `
            -WimMetadata $wimMetadata `
            -WinREPlan $winREPlan `
            -NativeCommandPlan $nativeCommandPlan `
            -Authorization $authorization `
            -NativeCommandSimulation $nativeCommandSimulation `
            -WhatIf

        $stages = @($report.stageResults.stage)
        foreach ($stage in @("preflight", "disk-identity", "confirmation-token", "wim-validation", "partition-plan", "apply-plan", "boot-plan", "winre-plan", "native-command-simulation", "final-report")) {
            Assert-KitEqual ($stages -contains $stage) $true
        }

        Assert-KitEqual $report.status "passed"
        Assert-KitEqual $report.trueExecution $false
        foreach ($action in @($report.actions)) {
            Assert-KitEqual $action.executed $false
        }

        $blockedManifest = $manifest | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $partition = @($blockedManifest.actions | Where-Object { $_.id -eq "partition-plan" })[0]
        $partition.mutationKind = "disk"
        $blockedReport = New-KitControlledExecutionReport `
            -Manifest $blockedManifest `
            -RepoRoot $script:RepoRoot `
            -DiskIdentity $diskIdentity `
            -ConfirmationToken $confirmationToken `
            -WimMetadata $wimMetadata `
            -WinREPlan $winREPlan `
            -NativeCommandPlan $nativeCommandPlan `
            -Authorization $authorization `
            -NativeCommandSimulation $nativeCommandSimulation `
            -WhatIf
        $applyPlan = @($blockedReport.actions | Where-Object { $_.id -eq "apply-plan" })[0]

        Assert-KitEqual $blockedReport.status "failed"
        Assert-KitEqual $applyPlan.status "blocked"
        Assert-KitMatch $applyPlan.reason "blocked by dependency"
    }

    It "keeps authorization explicit and blocks execute requests" {
        $authorization = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\authorization\matched.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $planned = Test-KitControlledExecutionAuthorization -InputObject $authorization

        Assert-KitEqual $planned.status "planned"
        Assert-KitEqual $planned.trueExecutionAllowed $false

        $executeRequest = $authorization | ConvertTo-Json -Depth 12 | ConvertFrom-Json
        $executeRequest.requestedMode = "execute"
        $executeRequest.executeRequested = $true
        $blocked = Test-KitControlledExecutionAuthorization -InputObject $executeRequest

        Assert-KitEqual $blocked.status "blocked"
        Assert-KitEqual $blocked.executeRequestBlockedCount 1
        Assert-KitEqual $blocked.trueExecutionAllowed $false
        Assert-KitMatch $blocked.reason "not implemented/enabled"
    }

    It "keeps native simulation and WinPE planning non-executing" {
        $simulation = Invoke-KitNativeCommandSimulation -FixturePath "tests\fixtures\controlled-execution\native-command-simulation\reagentc-failure.json" -RepoRoot $script:RepoRoot

        Assert-KitEqual $simulation.status "simulated-failure"
        Assert-KitEqual $simulation.simulatedFailureCount 1
        Assert-KitEqual $simulation.command.executed $false
        Assert-KitEqual $simulation.command.simulated $true

        $process = & $script:InvokeWinPEPlanProcess -Arguments "-PlanOnly -Execute -TargetDiskNumber 0 -ExpectedDiskSerial SAMPLE-DISK-SERIAL-001 -ExpectedDiskSize 107374182400 -ImageSha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef -ImageIndex 1 -ImageArchitecture amd64 -ConfirmationToken confirm-SAMPLE-DISK-SERIAL-001 -SourceRunId kit-run-20260626T000000Z-0000000"
        $report = $process.stdout | ConvertFrom-Json

        Assert-KitEqual $process.exitCode 0
        Assert-KitEqual $report.reportType "winpe-controlled-execution-plan"
        Assert-KitEqual $report.executeRequested $true
        Assert-KitEqual $report.trueExecution $false
        Assert-KitEqual $report.status "blocked"
        Assert-KitEqual $report.stageResults[0].executed $false
    }
}
