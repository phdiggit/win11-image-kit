Describe "User experience restore safety" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitUserExperienceRestoreReport.ps1")
    }

    It "rejects unsafe manifest switches" {
        $manifest = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\user-experience-restore.json") -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest.allowRegistryMutation = $true
        $errors = @(Test-KitUserExperienceRestoreSafety -Manifest $manifest)

        Assert-KitEqual ($errors.Count -gt 0) $true
        Assert-KitMatch ($errors -join "`n") "allowRegistryMutation must be false"
    }

    It "keeps dangerous command names out of Issue 18 scripts" {
        $patterns = @(
            '\bSet-ItemProperty\b',
            '\bNew-ItemProperty\b',
            '\bRemove-ItemProperty\b',
            '\breg\.exe\b',
            '\breg\s+add\b',
            '\breg\s+delete\b',
            '\bDism(\.exe)?\b',
            '\bImport-StartLayout\b',
            '\bExport-StartLayout\b',
            '\bGet-StartApps\b',
            '\bStart-Process\b',
            '\bInvoke-Expression\b',
            '\bInvoke-WebRequest\b',
            '\bInvoke-RestMethod\b',
            '\bInstall-Module\b',
            '\bwinget\b',
            '\bchoco\b',
            '\bmsiexec\b'
        )
        $files = @(
            "scripts\common\New-KitUserExperienceRestoreReport.ps1",
            "scripts\common\Test-KitUserExperienceRestoreSafety.ps1",
            "scripts\validate\Test-UserExperienceRestore.ps1",
            "scripts\config\Show-UserExperienceRestorePlan.ps1"
        )

        foreach ($file in $files) {
            $text = Get-Content -LiteralPath (Join-Path $script:RepoRoot $file) -Raw -Encoding UTF8
            foreach ($pattern in $patterns) {
                Assert-KitNotMatch $text $pattern
            }
        }
    }
}
