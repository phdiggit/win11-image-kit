$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Software package policy validation" {
    BeforeAll {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")

        $script:PowerShell = (Get-Command powershell -ErrorAction SilentlyContinue).Source
        if ([string]::IsNullOrWhiteSpace($script:PowerShell)) {
            $script:PowerShell = (Get-Command pwsh -ErrorAction Stop).Source
        }

        $script:ValidationScript = Join-Path $script:RepoRoot "scripts\validate\Test-ProjectConfig.ps1"
        $script:TempRoots = @()

        $script:NewTestPackage = {
            param(
                [string]$Name = "test-package",
                [string]$Type = "archive",
                [bool]$SilentInstall = $true,
                [hashtable]$Policy = @{
                    required = $true
                    failurePolicy = "fail"
                    allowMissingSource = $false
                }
            )

            $package = [ordered]@{
                name = $Name
                version = "1.0.0"
                enabled = $true
                category = "test"
                stage = "golden-image"
                type = $Type
            }

            foreach ($key in @("required", "failurePolicy", "allowMissingSource")) {
                if ($Policy.ContainsKey($key)) {
                    $package[$key] = $Policy[$key]
                }
            }

            if ($Type -eq "archive") {
                $package["archiveFormat"] = "zip"
                $package["source"] = '${PackageRoot}\test\test.zip'
                $package["destination"] = '${ToolRoot}\test-package'
            } elseif ($Type -eq "zip") {
                $package["source"] = '${PackageRoot}\test\test.zip'
                $package["destination"] = '${ToolRoot}\test-package'
            } elseif ($Type -eq "installer") {
                $package["source"] = '${PackageRoot}\test\setup.exe'
                $package["destination"] = 'C:\Program Files\TestPackage'
                $package["installArgs"] = @()
                $package["silentInstall"] = $SilentInstall
            }

            return $package
        }

        $script:InvokePolicyValidation = {
            param(
                [hashtable]$Policy,
                [string]$Type = "archive",
                [bool]$SilentInstall = $true
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
                packages = @((& $script:NewTestPackage -Policy $Policy -Type $Type -SilentInstall $SilentInstall))
            }
            $software | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $softwarePath -Encoding UTF8

            $scope = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\customization-scope.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            $scope.applications.softwareManifest = $softwarePath
            $scope | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $scopePath -Encoding UTF8

            & $script:PowerShell -NoProfile -ExecutionPolicy Bypass -File $script:ValidationScript -ScopeManifestPath $scopePath > $stdoutPath 2> $stderrPath
            $exitCode = $LASTEXITCODE
            $stdout = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
            $stderr = Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8

            return [pscustomobject]@{
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
            Assert-KitNotMatch $output "failurePolicy|required|allowMissingSource"
            Assert-KitNotMatch $output "\[WARN\]"
        } finally {
            Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }

    It "accepts required fail policy fields" {
        $result = & $script:InvokePolicyValidation -Policy @{
            required = $true
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch $result.Stdout "0 .*0"
    }

    It "rejects invalid failurePolicy enum values" {
        $result = & $script:InvokePolicyValidation -Policy @{
            required = $true
            failurePolicy = "continue"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "failurePolicy"
    }

    It "rejects invalid required field types" {
        $result = & $script:InvokePolicyValidation -Policy @{
            required = "true"
            failurePolicy = "fail"
            allowMissingSource = $false
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "required"
        Assert-KitMatch $result.Stdout "boolean"
    }

    It "rejects invalid allowMissingSource field types" {
        $result = & $script:InvokePolicyValidation -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = "yes"
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "allowMissingSource"
        Assert-KitMatch $result.Stdout "boolean"
    }

    It "rejects contradictory policy combinations" {
        $result = & $script:InvokePolicyValidation -Policy @{
            required = $true
            failurePolicy = "skip"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 1
        Assert-KitMatch $result.Stdout "required=true"
        Assert-KitMatch $result.Stdout "allowMissingSource"
    }

    It "accepts optional skip policy" {
        $result = & $script:InvokePolicyValidation -Policy @{
            required = $false
            failurePolicy = "skip"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch $result.Stdout "0 .*0"
    }

    It "accepts manual policy for silentInstall false installers" {
        $result = & $script:InvokePolicyValidation -Type "installer" -SilentInstall $false -Policy @{
            required = $false
            failurePolicy = "manual"
            allowMissingSource = $true
        }

        Assert-KitEqual $result.ExitCode 0
        Assert-KitMatch $result.Stdout "0 .*0"
    }
}
