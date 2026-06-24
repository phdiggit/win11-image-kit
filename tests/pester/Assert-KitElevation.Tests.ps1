$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")
. (Join-Path $RepoRoot "scripts\common\Assert-KitElevation.ps1")

Describe "Assert-KitElevation" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Assert-KitElevation.ps1")
    }

    It "脚本可以被导入并暴露入口函数" {
        Assert-KitNotNullOrEmpty (Get-Command Assert-KitElevation -ErrorAction Stop)
        Assert-KitNotNullOrEmpty (Get-Command Test-KitIsAdministrator -ErrorAction Stop)
    }

    It "管理员会话直接通过" {
        Mock -CommandName Test-KitIsAdministrator -MockWith { $true }

        Assert-KitDoesNotThrow { Assert-KitElevation -Operation "测试操作" }
    }

    It "非管理员真实执行会抛出异常" {
        Mock -CommandName Test-KitIsAdministrator -MockWith { $false }

        Assert-KitThrows { Assert-KitElevation -Operation "测试操作" } "测试操作 需要在管理员 PowerShell 会话中执行。可先使用 -WhatIf 预演。"
    }

    It "非管理员 WhatIf 预演不会请求真实提权" {
        Mock -CommandName Test-KitIsAdministrator -MockWith { $false }
        Mock -CommandName Write-Warning -MockWith { }

        Assert-KitDoesNotThrow {
            $WhatIfPreference = $true
            Assert-KitElevation -Operation "测试操作" -AllowWhatIfPreview
        }
    }
}
