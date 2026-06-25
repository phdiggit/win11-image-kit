Describe "Issue 10 context scope acceptance matrix" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
    }

    It "keeps the acceptance document in the expected state with required sections" {
        $docPath = Join-Path $script:RepoRoot "docs\25-issue10-context-scope-acceptance.md"
        Assert-KitEqual (Test-Path -LiteralPath $docPath) $true
        $doc = Get-Content -LiteralPath $docPath -Raw -Encoding UTF8

        Assert-KitMatch $doc "Status: in-acceptance"
        foreach ($section in @("## Scope", "## Non-goals", "## Acceptance Matrix", "## Handler Adoption Checklist", "CI boundary")) {
            Assert-KitMatch $doc ([regex]::Escape($section))
        }

        foreach ($link in @("24-issue10-context-scope-split.md", "26-issue10-close-preparation.md", "27-issue10-main-validation-evidence.md")) {
            Assert-KitMatch $doc ([regex]::Escape($link))
        }
    }

    It "keeps manifest and schema context contracts strict" {
        $manifestPath = Join-Path $script:RepoRoot "manifests\context-scope.json"
        $schemaPath = Join-Path $script:RepoRoot "schemas\context-scope.schema.json"
        Assert-KitEqual (Test-Path -LiteralPath $manifestPath) $true
        Assert-KitEqual (Test-Path -LiteralPath $schemaPath) $true

        $schema = Get-Content -LiteralPath $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-KitEqual $schema.additionalProperties $false
        Assert-KitEqual $schema.'$defs'.target.additionalProperties $false
        Assert-KitEqual ((@($schema.'$defs'.context.enum) -join ",") -eq "machine,default-user,current-user") $true
        Assert-KitEqual (@($schema.'$defs'.target.required) -contains "reason") $true
    }

    It "keeps active context code free of uncontrolled hive, registry, and profile mutation" {
        $files = @(
            "scripts\common\Resolve-KitContextScope.ps1",
            "scripts\common\New-KitContextPlan.ps1",
            "scripts\common\Test-KitContextSafety.ps1",
            "scripts\validate\Test-ContextScope.ps1"
        )

        foreach ($relativePath in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            Assert-KitNotMatch $text "reg\s+load|reg\.exe\s+load|reg\s+unload|reg\.exe\s+unload"
            Assert-KitNotMatch $text "Set-ItemProperty\s+-Path\s+HKCU|Set-ItemProperty\s+-Path\s+HKLM"
            Assert-KitNotMatch $text "New-ItemProperty\s+-Path\s+HKCU|New-ItemProperty\s+-Path\s+HKLM"
            Assert-KitNotMatch $text "Copy-Item.*USERPROFILE|Set-Content.*USERPROFILE|Remove-Item.*USERPROFILE"
        }
    }

    It "keeps context plan report fields stable" {
        . (Join-Path $script:RepoRoot "scripts\common\New-KitContextPlan.ps1")
        $scope = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\context-scope.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $plan = New-KitContextPlan -Targets $scope.targets -ScopeConfig $scope -WhatIf

        foreach ($property in @("reportType", "status", "summary", "items", "whatIf")) {
            Assert-KitEqual ($null -ne $plan.PSObject.Properties[$property]) $true
        }
        Assert-KitEqual $plan.reportType "context-scope-plan"
    }

    It "links acceptance docs from README and PR Fast CI" {
        $readme = Get-Content -LiteralPath (Join-Path $script:RepoRoot "README.md") -Raw -Encoding UTF8
        $workflow = Get-Content -LiteralPath (Join-Path $script:RepoRoot ".github\workflows\ci.yml") -Raw -Encoding UTF8

        Assert-KitMatch $readme "docs/25-issue10-context-scope-acceptance\.md"
        foreach ($testPath in @(
            "tests/pester/ContextScopeSchema.Tests.ps1",
            "tests/pester/ContextScopeResolver.Tests.ps1",
            "tests/pester/ContextScopeSafety.Tests.ps1",
            "tests/pester/ContextScopeReport.Tests.ps1",
            "tests/pester/Issue10ContextScope.Tests.ps1",
            "tests/pester/Issue10ContextScopeAcceptance.Tests.ps1"
        )) {
            Assert-KitMatch $workflow ([regex]::Escape($testPath))
        }
    }
}
