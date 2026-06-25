Describe "Context scope resolver" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitContextScope.ps1")
        $script:Scope = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\context-scope.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    It "maps registry roots to machine, current-user, and default-user" {
        $machine = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "hklm"; targetType = "registry"; root = "HKLM"; phase = "build"; mutationPolicy = "planned"; reason = "test" }) -ScopeConfig $script:Scope
        $current = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "hkcu"; targetType = "registry"; root = "HKCU"; phase = "interactive"; mutationPolicy = "manual"; reason = "test" }) -ScopeConfig $script:Scope
        $default = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "hku"; targetType = "registry"; root = "HKU_DEFAULT"; phase = "build"; mutationPolicy = "manual"; reason = "test" }) -ScopeConfig $script:Scope

        Assert-KitEqual $machine.context "machine"
        Assert-KitEqual $machine.status "allowed"
        Assert-KitEqual $current.context "current-user"
        Assert-KitEqual $current.status "manual"
        Assert-KitEqual $default.context "default-user"
        Assert-KitEqual $default.status "manual"
    }

    It "maps profile and machine paths" {
        $default = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "default-profile"; targetType = "profile"; path = "C:\Users\Default\AppData\Local"; phase = "build"; mutationPolicy = "manual"; reason = "test" }) -ScopeConfig $script:Scope
        $current = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "current-profile"; targetType = "profile"; path = "%USERPROFILE%\AppData\Local"; phase = "interactive"; mutationPolicy = "manual"; reason = "test" }) -ScopeConfig $script:Scope
        $programData = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "programdata"; targetType = "file"; path = "C:\ProgramData\Win11"; phase = "build"; mutationPolicy = "planned"; reason = "test" }) -ScopeConfig $script:Scope
        $windows = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "windows"; targetType = "file"; path = "C:\Windows\Temp"; phase = "build"; mutationPolicy = "planned"; reason = "test" }) -ScopeConfig $script:Scope
        $programFiles = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "programfiles"; targetType = "file"; path = "C:\Program Files\App"; phase = "build"; mutationPolicy = "planned"; reason = "test" }) -ScopeConfig $script:Scope

        Assert-KitEqual $default.context "default-user"
        Assert-KitEqual $current.context "current-user"
        Assert-KitEqual $programData.context "machine"
        Assert-KitEqual $windows.context "machine"
        Assert-KitEqual $programFiles.context "machine"
    }

    It "blocks unknown roots, conflicting hints, and phase policy mismatch" {
        $unknown = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "unknown"; targetType = "registry"; root = "HKCR"; phase = "build"; mutationPolicy = "planned"; reason = "test" }) -ScopeConfig $script:Scope
        $conflict = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "conflict"; context = "machine"; targetType = "registry"; root = "HKCU"; phase = "build"; mutationPolicy = "planned"; reason = "test" }) -ScopeConfig $script:Scope
        $phaseMismatch = Resolve-KitContextScope -Target ([pscustomobject]@{ id = "phase"; context = "current-user"; targetType = "registry"; root = "HKCU"; phase = "build"; mutationPolicy = "planned"; reason = "test" }) -ScopeConfig $script:Scope

        Assert-KitEqual $unknown.status "blocked"
        Assert-KitEqual $conflict.status "blocked"
        Assert-KitMatch ($conflict.errors -join ";") "ambiguous"
        Assert-KitEqual $phaseMismatch.status "blocked"
        Assert-KitMatch ($phaseMismatch.errors -join ";") "phasePolicy mismatch|current-user context"
    }
}
