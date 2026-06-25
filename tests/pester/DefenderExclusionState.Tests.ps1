$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path

Describe "Defender exclusion state seam" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Set-KitDefenderExclusionState.ps1")

        $script:TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-image-kit-defender-state-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($script:TempRoot) | Out-Null
        $script:PathMap = @{
            WorkRoot = Join-Path $script:TempRoot "work"
            DeployRoot = Join-Path $script:TempRoot "deploy"
            PackageRoot = Join-Path $script:TempRoot "packages"
            ConfigRoot = Join-Path $script:TempRoot "configs"
            ToolRoot = Join-Path $script:TempRoot "tools"
            DataRoot = Join-Path $script:TempRoot "data"
        }
        $script:AllowedPath = [pscustomobject]@{
            id = "cache"
            type = "path"
            value = '${WorkRoot}\cache'
            scope = "kit-cache"
            reason = "cache"
            required = $false
            failurePolicy = "manual"
        }
        $script:AllowedProcess = [pscustomobject]@{
            id = "portable"
            type = "process"
            value = '${ToolRoot}\portable\App.exe'
            scope = "portable"
            reason = "portable"
            required = $false
            failurePolicy = "manual"
        }
    }

    AfterEach {
        if ([IO.Directory]::Exists($script:TempRoot)) {
            [IO.Directory]::Delete($script:TempRoot, $true)
        }
    }

    It "returns unchanged for an existing path exclusion without mutation" {
        $resolved = Resolve-KitDefenderExclusionValue -Value $script:AllowedPath.value -PathMap $script:PathMap
        $mutationCount = 0
        $query = { [pscustomobject]@{ ExclusionPath = @($resolved); ExclusionProcess = @() } }
        $mutation = { param([string]$Type, [string]$Value) $mutationCount++ }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($script:AllowedPath) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation)[0]

        Assert-KitEqual $result.status "unchanged"
        Assert-KitEqual $result.action "unchanged"
        Assert-KitEqual $mutationCount 0
    }

    It "returns WhatIf for a missing path exclusion without mutation" {
        $mutationCount = 0
        $query = { [pscustomobject]@{ ExclusionPath = @(); ExclusionProcess = @() } }
        $mutation = { param([string]$Type, [string]$Value) $mutationCount++ }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($script:AllowedPath) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation -WhatIf)[0]

        Assert-KitEqual $result.status "whatif"
        Assert-KitEqual $result.action "would-add"
        Assert-KitEqual $result.whatIf $true
        Assert-KitEqual $mutationCount 0
    }

    It "adds a missing allowed path through the injected mutation seam" {
        $script:AddedPaths = @()
        $script:MutationCount = 0
        $query = { [pscustomobject]@{ ExclusionPath = $script:AddedPaths; ExclusionProcess = @() } }
        $mutation = {
            param([string]$Type, [string]$Value)
            $script:MutationCount++
            if ($Type -eq "path") {
                $script:AddedPaths = @($script:AddedPaths + $Value)
            }
        }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($script:AllowedPath) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation)[0]

        Assert-KitEqual $result.status "changed"
        Assert-KitEqual $result.action "added"
        Assert-KitEqual $script:MutationCount 1
    }

    It "reports verification failure when Add succeeds but the exclusion remains missing" {
        $requiredPath = [pscustomobject]@{
            id = "required-cache"
            type = "path"
            value = '${WorkRoot}\cache'
            scope = "kit-cache"
            reason = "cache"
            required = $true
            failurePolicy = "fail"
        }
        $query = { [pscustomobject]@{ ExclusionPath = @(); ExclusionProcess = @() } }
        $mutation = { param([string]$Type, [string]$Value) }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($requiredPath) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation)[0]

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.action "verify-failed"
        Assert-KitMatch $result.errors[0] "exclusion not present"
    }

    It "does not call mutation when policy blocks an exclusion" {
        $mutationCount = 0
        $blocked = [pscustomobject]@{
            id = "drive-root"
            type = "path"
            value = 'C:\'
            scope = "drive-root"
            reason = "blocked"
            required = $true
            failurePolicy = "fail"
        }
        $query = { throw "query should not run for policy blocked exclusions" }
        $mutation = { param([string]$Type, [string]$Value) $mutationCount++ }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($blocked) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation)[0]

        Assert-KitEqual $result.status "failed"
        Assert-KitEqual $result.action "blocked"
        Assert-KitEqual $mutationCount 0
    }

    It "maps query exceptions through failurePolicy" {
        $query = { throw "query failed" }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($script:AllowedPath) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query)[0]

        Assert-KitEqual $result.status "manual"
        Assert-KitEqual $result.action "query-failed"
        Assert-KitMatch $result.errors[0] "query failed"
    }

    It "handles process exclusions with the same seam" {
        $script:AddedProcesses = @()
        $script:MutationCount = 0
        $query = { [pscustomobject]@{ ExclusionPath = @(); ExclusionProcess = $script:AddedProcesses } }
        $mutation = {
            param([string]$Type, [string]$Value)
            $script:MutationCount++
            if ($Type -eq "process") {
                $script:AddedProcesses = @($script:AddedProcesses + $Value)
            }
        }

        $result = @(Set-KitDefenderExclusionState -Exclusions @($script:AllowedProcess) -PathMap $script:PathMap -RepoRoot $script:RepoRoot -DefenderQuery $query -DefenderMutation $mutation)[0]

        Assert-KitEqual $result.status "changed"
        Assert-KitEqual $result.action "added"
        Assert-KitEqual $script:MutationCount 1
    }
}
