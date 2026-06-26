Describe "Controlled execution recovery plan fixtures" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "passes a plan with EFI, Windows, and Recovery logical volumes" {
        $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\winre-plan\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $plan = ConvertTo-KitWinREPlan -InputObject $input

        Assert-KitEqual $plan.status "planned"
        Assert-KitEqual $plan.failureCount 0
        Assert-KitEqual $plan.efiVolume.logicalName "EFI"
        Assert-KitEqual $plan.windowsVolume.logicalName "Windows"
        Assert-KitEqual $plan.recoveryVolume.logicalName "Recovery"
        Assert-KitEqual $plan.recoveryVolume.gptType "de94bba4-06d1-4d40-a16a-bfd50179d6ac"
        Assert-KitEqual $plan.recoveryVolume.gptAttributes "0x8000000000000001"
        if (@($plan.plannedCommands).Count -lt 1) {
            throw "Expected planned recovery command strings."
        }
    }

    It "blocks missing recovery volume and wrong partition type" {
        foreach ($path in @(
            "tests\fixtures\controlled-execution\winre-plan\missing-recovery-volume.json",
            "tests\fixtures\controlled-execution\winre-plan\wrong-gpt-type.json"
        )) {
            $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot $path) -Raw -Encoding UTF8 | ConvertFrom-Json
            $plan = ConvertTo-KitWinREPlan -InputObject $input

            Assert-KitEqual $plan.status "blocked"
            if ($plan.failureCount -lt 1) {
                throw "Expected recovery plan failure for $path."
            }
        }
    }
}
