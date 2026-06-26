Describe "Effective configuration token safety" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-effective-token-{0}" -f ([guid]::NewGuid().ToString("N")))
        New-Item -ItemType Directory -Path (Join-Path $script:TempRoot "manifests") -Force | Out-Null
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:TempRoot) {
            Remove-Item -LiteralPath $script:TempRoot -Recurse -Force
        }
    }

    function Write-TestConfig {
        param($Paths, [string[]]$Forbidden = @())

        @{
            manifestVersion = 1
            mergePolicy = @{ object = "deep-merge"; array = "replace"; scalar = "replace"; null = "remove" }
            layers = @(@{ id = "repo-default"; kind = "repo-default"; required = $true; tracked = $true; path = "manifests/base.json"; schema = "schemas/config-layer-fragment.schema.json"; description = "base" })
            stacks = @(@{ name = "default"; layers = @("repo-default"); description = "default" })
            localOverrideLayer = "local-private"
            safety = @{ allowedPathTokens = @("A", "B", "Root"); forbiddenPathPatterns = $Forbidden; forbidTrackedLocalOverrides = $true }
        } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/config-layers.json") -Encoding UTF8
        @{ layerId = "repo-default"; paths = $Paths } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $script:TempRoot "manifests/base.json") -Encoding UTF8
    }

    function Invoke-TestValidation {
        $reportPath = Join-Path $script:TempRoot "report.json"
        $process = Start-Process -FilePath "powershell" -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $script:RepoRoot "scripts\validate\Test-EffectiveConfiguration.ps1"),
            "-ConfigLayersPath", (Join-Path $script:TempRoot "manifests/config-layers.json"),
            "-RepoRoot", $script:TempRoot,
            "-ReportPath", $reportPath
        ) -Wait -PassThru -NoNewWindow
        return [pscustomobject]@{
            ExitCode = [int]$process.ExitCode
            Report = $(if (Test-Path -LiteralPath $reportPath) { Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null })
        }
    }

    It "fails unknown tokens" {
        Write-TestConfig -Paths @{ Root = '${MissingToken}\root' }
        $result = Invoke-TestValidation

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch (($result.Report.failures) -join "`n") "Unresolved path token"
    }

    It "fails circular tokens" {
        Write-TestConfig -Paths @{ A = '${B}'; B = '${A}' }
        $result = Invoke-TestValidation

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch (($result.Report.failures) -join "`n") "Unresolved path token"
    }

    It "fails forbidden old NAS paths" {
        Write-TestConfig -Paths @{ Root = '\\192.168.1.37\images\win11' } -Forbidden @('\\\\192\.168\.1\.37\\images')
        $result = Invoke-TestValidation

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch (($result.Report.failures) -join "`n") "forbidden pattern"
    }
}
