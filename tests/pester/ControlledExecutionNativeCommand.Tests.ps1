Describe "Controlled execution native command envelope fixtures" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "keeps native command envelopes planned and not captured" {
        $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command\planned.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $plan = New-KitNativeCommandPlan -InputObject $input

        Assert-KitEqual $plan.status "planned"
        Assert-KitEqual $plan.failureCount 0
        foreach ($command in @($plan.commands)) {
            Assert-KitEqual $command.actualExitCode "not-run"
            Assert-KitEqual $command.stdout "not-captured"
            Assert-KitEqual $command.stderr "not-captured"
            Assert-KitEqual $command.status "planned"
        }
    }

    It "blocks a fixture that includes an actual exit code" {
        $input = Get-Content -LiteralPath (Join-Path $script:RepoRoot "tests\fixtures\controlled-execution\native-command\actual-exitcode-present.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $plan = New-KitNativeCommandPlan -InputObject $input

        Assert-KitEqual $plan.status "blocked"
        if ($plan.failureCount -lt 1) {
            throw "Expected native command failure count."
        }
    }
}
