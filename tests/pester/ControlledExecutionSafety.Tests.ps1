Describe "Controlled execution safety guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
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
}
