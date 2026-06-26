Describe "Evidence chain safety policy" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitEvidenceChainReport.ps1")
    }

    It "keeps safety flags false in the PR Fast baseline" {
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot

        Assert-KitEqual $report.safety.trueExecution $false
        Assert-KitEqual $report.safety.localPrivateIncluded $false
        Assert-KitEqual $report.safety.networkUsed $false
        Assert-KitEqual $report.safety.mutationUsed $false
    }

    It "keeps new evidence chain scripts free of dangerous command names" {
        $patterns = @(
            "\b" + "Di" + "sm(\.exe)?\b",
            "\b" + "sys" + "prep\b",
            "\b" + "Get-Appx" + "Package\b",
            "\b" + "Remove-Appx" + "Package\b",
            "\b" + "Add-Mp" + "Preference\b",
            "\b" + "Remove-Mp" + "Preference\b",
            "\b" + "New-Item" + "Property\b",
            "\b" + "Set-Item" + "Property\b",
            "\b" + "Remove-Item" + "Property\b",
            "\b" + "Start-" + "Service\b",
            "\b" + "Stop-" + "Service\b",
            "\b" + "Set-" + "Service\b",
            "\b" + "New-" + "Service\b",
            "\b" + "sc" + "\.exe\b",
            "\b" + "Invoke-Web" + "Request\b",
            "\b" + "Invoke-Rest" + "Method\b",
            "\b" + "Install-" + "Module\b",
            "\b" + "win" + "get\b",
            "\b" + "cho" + "co\b"
        )

        foreach ($relativePath in @(
            "scripts\common\New-KitEvidenceChainReport.ps1",
            "scripts\validate\Test-EvidenceChain.ps1",
            "scripts\config\Show-EvidenceChain.ps1"
        )) {
            $content = Get-Content -LiteralPath (Join-Path $script:RepoRoot $relativePath) -Raw -Encoding UTF8
            foreach ($pattern in $patterns) {
                Assert-KitNotMatch $content $pattern
            }
        }
    }

    It "does not include private local override artifacts" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\evidence-chain.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifestText = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\evidence-chain.json") -Raw -Encoding UTF8
        $report = New-KitEvidenceChainReport -RepoRoot $script:RepoRoot

        Assert-KitEqual $manifest.artifactPolicy.allowPrivateLocalOverrides $false
        Assert-KitEqual $manifest.artifactPolicy.redactLocalPrivateValues $true
        Assert-KitNotMatch $manifestText "paths\.local\.json"

        foreach ($item in @($report.evidence)) {
            foreach ($artifact in @($item.artifactReferences)) {
                Assert-KitNotMatch ([string]$artifact.path) "paths\.local\.json"
            }
        }
    }
}
