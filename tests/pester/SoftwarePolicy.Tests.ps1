$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Software ensure-state policy validation" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:ValidationScript = Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1"
        $script:TempRoots = @()

        $script:NewTestSoftwareItem = {
            param(
                [hashtable]$Overrides = @{}
            )

            $item = [ordered]@{
                id = "test-software"
                displayName = "Test Software"
                ensure = "present"
                source = "manual"
                packageId = "test.software"
                version = $null
                scope = "machine"
                installMode = "planned"
                priority = 100
                tags = @("fixture")
                notes = "fixture"
            }

            foreach ($entry in $Overrides.GetEnumerator()) {
                $item[$entry.Key] = $entry.Value
            }

            return $item
        }

        $script:InvokePolicyValidation = {
            param(
                [hashtable]$Overrides = @{}
            )

            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-software-policy-{0}" -f ([guid]::NewGuid().ToString("N")))
            New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
            $script:TempRoots += $tempRoot

            $softwarePath = Join-Path $tempRoot "software.json"
            $scopePath = Join-Path $tempRoot "customization-scope.json"
            $stdoutPath = Join-Path $tempRoot "stdout.txt"
            $stderrPath = Join-Path $tempRoot "stderr.txt"

            $software = [ordered]@{
                '$schema' = '../schemas/software.schema.json'
                manifestVersion = 1
                software = @((& $script:NewTestSoftwareItem -Overrides $Overrides))
            }
            $software | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $softwarePath -Encoding UTF8

            $scope = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\customization-scope.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            $scope.applications.softwareManifest = $softwarePath
            $scope | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $scopePath -Encoding UTF8

            & $script:PowerShell -NoProfile -ExecutionPolicy Bypass -File $script:ValidationScript -ScopeManifestPath $scopePath > $stdoutPath 2> $stderrPath
            $exitCode = $LASTEXITCODE
            $stdout = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
            $stderr = Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8

            [pscustomobject]@{
                ExitCode = $exitCode
                Stdout = $stdout
                Stderr = $stderr
            }
        }
    }

    AfterAll {
        foreach ($tempRoot in $script:TempRoots) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "validates the default config without package file checks" {
        $stdoutPath = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-default-policy-{0}.out" -f ([guid]::NewGuid().ToString("N")))
        $stderrPath = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-default-policy-{0}.err" -f ([guid]::NewGuid().ToString("N")))

        try {
            & $script:PowerShell -NoProfile -ExecutionPolicy Bypass -File $script:ValidationScript > $stdoutPath 2> $stderrPath
            $output = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8

            Assert-KitEqual $LASTEXITCODE 0
            Assert-KitMatch $output "0 .*0"
            Assert-KitNotMatch $output "\[WARN\]"
        } finally {
            Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "accepts a valid ensure-state software item" {
        $result = & $script:InvokePolicyValidation -Overrides @{}

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch $result.Stdout "0 .*0"
    }

    It "rejects invalid ensure enum values" {
        $result = & $script:InvokePolicyValidation -Overrides @{
            ensure = "install"
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "ensure"
    }

    It "rejects invalid installMode enum values" {
        $result = & $script:InvokePolicyValidation -Overrides @{
            installMode = "auto"
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "installMode"
    }

    It "rejects invalid priority field types" {
        $result = & $script:InvokePolicyValidation -Overrides @{
            priority = "high"
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "priority"
    }

    It "rejects non-string tags" {
        $result = & $script:InvokePolicyValidation -Overrides @{
            tags = @(1, 2)
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "tags"
    }

    It "rejects pinned items without version" {
        $result = & $script:InvokePolicyValidation -Overrides @{
            ensure = "pinned"
            version = $null
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "pinned"
        Assert-KitMatch $result.Stdout "version"
    }

    It "accepts manual installMode with null version" {
        $result = & $script:InvokePolicyValidation -Overrides @{
            ensure = "manual"
            installMode = "manual"
            version = $null
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch $result.Stdout "0 .*0"
    }
}
