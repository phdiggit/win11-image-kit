Describe "Effective configuration consumer integration" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-effective-consumer-{0}" -f ([guid]::NewGuid().ToString("N")))
        New-Item -ItemType Directory -Path $script:TempRoot -Force | Out-Null

        function Invoke-ScopeDisplay {
            param([string]$CommandTail = "")

            $stdout = Join-Path $script:TempRoot ("stdout-{0}.txt" -f ([guid]::NewGuid().ToString("N")))
            $stderr = Join-Path $script:TempRoot ("stderr-{0}.txt" -f ([guid]::NewGuid().ToString("N")))
            $scriptPath = Join-Path $script:RepoRoot "scripts\config\Show-CustomizationScope.ps1"
            $command = "& '$scriptPath' $CommandTail"
            $process = Start-Process -FilePath "powershell" -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-Command", $command
            ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr

            return [pscustomobject]@{
                ExitCode = [int]$process.ExitCode
                Output = (Get-Content -LiteralPath $stdout -Raw -Encoding UTF8)
                Error = (Get-Content -LiteralPath $stderr -Raw -Encoding UTF8)
            }
        }
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:TempRoot) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
        }
    }

    It "keeps Show-CustomizationScope default behavior compatible" {
        $result = Invoke-ScopeDisplay

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch $result.Output "ConfigRoot"
        Assert-KitNotMatch $result.Output "Effective configuration stack"
    }

    It "shows effective stack and source layers when opted in" {
        $result = Invoke-ScopeDisplay -CommandTail "-UseEffectiveConfiguration -StackName release"

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch $result.Output "Effective configuration stack: release"
        Assert-KitMatch $result.Output "Effective configuration source layers"
        Assert-KitMatch $result.Output "profile-release"
        Assert-KitMatch $result.Output "WorkRoot"
    }

    It "supports CLI path override JSON without local private artifacts" {
        $scriptPath = Join-Path $script:RepoRoot "scripts\config\Show-CustomizationScope.ps1"

        Assert-KitDoesNotThrow {
            & $scriptPath `
                -UseEffectiveConfiguration `
                -StackName air15 `
                -PathOverrideJson '{"ToolRoot":"D:/tools","DataRoot":"D:/data"}'
        }
    }
}
