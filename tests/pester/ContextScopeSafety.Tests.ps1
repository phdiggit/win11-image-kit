Describe "Context scope safety guardrails" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Test-KitContextSafety.ps1")
    }

    It "blocks machine items that point at HKCU or current profile paths" {
        $result = Test-KitContextSafety -InputObject ([pscustomobject]@{
            id = "bad-machine"
            context = "machine"
            phase = "build"
            targetType = "registry"
            root = "HKCU"
            path = ""
            mutationPolicy = "planned"
            status = "allowed"
            reason = "test"
            warnings = @()
            errors = @()
        })

        Assert-KitEqual $result.status "failed"
        Assert-KitMatch ($result.items[0].errors -join ";") "machine context"
    }

    It "blocks allowed current-user build items" {
        $result = Test-KitContextSafety -InputObject ([pscustomobject]@{
            id = "bad-current"
            context = "current-user"
            phase = "build"
            targetType = "registry"
            root = "HKCU"
            path = ""
            mutationPolicy = "planned"
            status = "allowed"
            reason = "test"
            warnings = @()
            errors = @()
        })

        Assert-KitEqual $result.status "failed"
        Assert-KitMatch ($result.items[0].errors -join ";") "current-user"
    }

    It "blocks default-user items without a default hive or profile marker" {
        $result = Test-KitContextSafety -InputObject ([pscustomobject]@{
            id = "bad-default"
            context = "default-user"
            phase = "build"
            targetType = "profile"
            root = ""
            path = "C:\Users\Public"
            mutationPolicy = "manual"
            status = "manual"
            reason = "test"
            warnings = @()
            errors = @()
        })

        Assert-KitEqual $result.status "failed"
        Assert-KitMatch ($result.items[0].errors -join ";") "Default User"
    }

    It "does not let ambiguous items pass" {
        $result = Test-KitContextSafety -InputObject ([pscustomobject]@{
            id = "ambiguous"
            context = "unknown"
            phase = "build"
            targetType = "registry"
            root = "HKCU"
            path = ""
            mutationPolicy = "planned"
            status = "allowed"
            reason = "ambiguous"
            warnings = @()
            errors = @("ambiguous context hints")
        })

        Assert-KitEqual $result.status "failed"
        Assert-KitMatch ($result.items[0].errors -join ";") "ambiguous|unknown"
    }

    It "keeps validate mode in plan or mock paths without mutation commands" {
        Mock Set-ItemProperty { throw "Set-ItemProperty should not be called." }
        Mock New-ItemProperty { throw "New-ItemProperty should not be called." }
        Mock Copy-Item { throw "Copy-Item should not be called." }

        $result = Test-KitContextSafety -ValidateMode -InputObject ([pscustomobject]@{
            id = "plan"
            context = "machine"
            phase = "validate"
            targetType = "registry"
            root = "HKLM"
            path = ""
            mutationPolicy = "planned"
            status = "allowed"
            reason = "test"
            warnings = @()
            errors = @()
        })

        Assert-KitEqual $result.status "passed"
        Assert-MockCalled Set-ItemProperty -Times 0 -Exactly
        Assert-MockCalled New-ItemProperty -Times 0 -Exactly
        Assert-MockCalled Copy-Item -Times 0 -Exactly
    }
}
