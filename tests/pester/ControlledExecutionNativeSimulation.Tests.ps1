Describe "Controlled execution native command simulation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitControlledExecutionReport.ps1")
    }

    It "returns simulated success without execution" {
        $result = Invoke-KitNativeCommandSimulation -FixturePath "tests\fixtures\controlled-execution\native-command-simulation\baseline-success.json" -RepoRoot $script:RepoRoot

        Assert-KitEqual $result.status "simulated-success"
        Assert-KitEqual $result.simulatedCommandCount 1
        Assert-KitEqual $result.command.executed $false
        Assert-KitEqual $result.command.simulated $true
    }

    It "returns simulated failure for non-zero fixture exit code" {
        $result = Invoke-KitNativeCommandSimulation -FixturePath "tests\fixtures\controlled-execution\native-command-simulation\dism-apply-failure.json" -RepoRoot $script:RepoRoot

        Assert-KitEqual $result.status "simulated-failure"
        Assert-KitEqual $result.simulatedFailureCount 1
        Assert-KitEqual $result.command.executed $false
    }

    It "keeps controlled execution PowerShell scripts free of native executable calls" {
        $patterns = @(
            "Start-Process",
            "Invoke-Expression",
            "\bcmd\.exe\b",
            "\bpowershell\.exe\b",
            "\bpwsh\.exe\b",
            "&\s*\$.*planned",
            "\bDism(\.exe)?\b",
            "\bdiskpart\b",
            "\bbcdboot\b",
            "\breagentc\b",
            "\bbcdedit\b",
            "\bGet-Disk\b",
            "\bGet-PhysicalDisk\b",
            "\bInitialize-Disk\b",
            "\bNew-Partition\b",
            "\bSet-Partition\b",
            "\bFormat-Volume\b"
        )
        $targetFiles = @(
            "scripts\common\Test-KitControlledExecutionAuthorization.ps1",
            "scripts\common\Invoke-KitNativeCommandSimulation.ps1",
            "scripts\common\New-KitControlledExecutionReport.ps1",
            "scripts\config\Show-ControlledExecutionPlan.ps1",
            "scripts\validate\Test-ControlledExecution.ps1",
            "scripts\winpe\New-WinPEControlledExecutionPlan.ps1"
        )

        foreach ($relativePath in $targetFiles) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            foreach ($pattern in $patterns) {
                if ($content -match $pattern) {
                    throw "Dangerous command pattern <$pattern> found in $relativePath"
                }
            }
        }
    }
}
