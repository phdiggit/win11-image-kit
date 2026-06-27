Describe "User experience template metadata" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")

        $script:ReadJson = {
            param([string]$Path)
            Get-Content -LiteralPath (Join-Path $script:RepoRoot $Path) -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    }

    It "passes default app and Start menu metadata baselines" {
        foreach ($path in @(
            "tests\fixtures\user-experience\template-metadata\default-apps-24h2.json",
            "tests\fixtures\user-experience\template-metadata\start-menu-24h2.json"
        )) {
            $result = Test-KitUserExperienceTemplateMetadata -InputObject (& $script:ReadJson $path)
            Assert-KitEqual $result.status "passed"
            Assert-KitEqual $result.failureCount 0
            Assert-KitEqual $result.executed $false
        }
    }

    It "blocks metadata mismatch and missing target capabilities" {
        $cases = @(
            @{ Path = "tests\fixtures\user-experience\template-metadata\missing-source-build.json"; Count = "failureCount" },
            @{ Path = "tests\fixtures\user-experience\template-metadata\source-version-mismatch.json"; Count = "failureCount" },
            @{ Path = "tests\fixtures\user-experience\template-metadata\scope-mismatch.json"; Count = "scopeMismatchCount" },
            @{ Path = "tests\fixtures\user-experience\template-metadata\required-app-missing.json"; Count = "missingCapabilityCount" },
            @{ Path = "tests\fixtures\user-experience\template-metadata\unknown-progid.json"; Count = "missingCapabilityCount" }
        )

        foreach ($case in $cases) {
            $result = Test-KitUserExperienceTemplateMetadata -InputObject (& $script:ReadJson $case.Path)
            Assert-KitEqual $result.status "failed"
            if ($result.($case.Count) -lt 1) {
                throw "Expected $($case.Count) to be greater than zero."
            }
        }
    }

    It "scans only data properties for private paths" {
        $metadata = [pscustomobject][ordered]@{
            schemaVersion = 1
            templateId = "scalar-property-regression"
            templateType = "default-app-associations"
            expectedTemplateType = "default-app-associations"
            targetScope = "current-user"
            expectedScope = "current-user"
            generatedAt = [datetime]"2026-06-27T00:00:00Z"
            sourceWindows = [pscustomobject][ordered]@{
                displayVersion = "24H2"
                buildNumber = 26100
            }
            targetApps = @(
                [pscustomobject][ordered]@{
                    appId = "browser"
                    required = $true
                    knownCapability = $true
                }
            )
        }

        $privatePaths = @(Test-KitUserExperiencePrivatePath -InputObject $metadata)
        $result = Test-KitUserExperienceTemplateMetadata -InputObject $metadata

        Assert-KitEqual $privatePaths.Count 0
        Assert-KitEqual $result.status "passed"
        Assert-KitEqual $result.localPrivatePathCount 0
    }
}
