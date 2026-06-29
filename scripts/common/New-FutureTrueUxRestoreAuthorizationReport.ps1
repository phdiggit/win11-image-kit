#Requires -Version 5.1

. "$PSScriptRoot\FutureTrueUxRestore.Guards.ps1"

function Resolve-FutureTrueUxRestoreRepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
}

function Get-FutureTrueUxRestoreValue {
    param(
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    if ($InputObject.PSObject.Properties.Name -contains $Name) {
        return $InputObject.$Name
    }

    return $DefaultValue
}

function Get-FutureTrueUxRestoreStrings {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($InputObject -is [string]) {
            $InputObject
            return
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            foreach ($value in $InputObject.Values) {
                Get-FutureTrueUxRestoreStrings -InputObject $value
            }
            return
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            foreach ($item in $InputObject) {
                Get-FutureTrueUxRestoreStrings -InputObject $item
            }
            return
        }

        foreach ($property in @($InputObject.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" })) {
            Get-FutureTrueUxRestoreStrings -InputObject $property.Value
        }
    }
}

function Test-FutureTrueUxRestorePrivatePath {
    param(
        [AllowNull()]
        $InputObject
    )

    $privatePathMatches = @()
    foreach ($value in @($InputObject | Get-FutureTrueUxRestoreStrings)) {
        if ($value -match '^[A-Za-z]:\\Users\\[^\\]+' -or $value -match '\\\\192\.168\.1\.37\\') {
            $privatePathMatches += [string]$value
        }
    }

    return @($privatePathMatches)
}

function Get-FutureTrueUxRestoreMutationAllowFlags {
    param(
        [Parameter(Mandatory)]
        $Manifest
    )

    [pscustomobject][ordered]@{
        registry = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowRegistryMutation" -DefaultValue $false)
        profile = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowProfileMutation" -DefaultValue $false)
        defaultUserHive = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowDefaultUserHiveMutation" -DefaultValue $false)
        defaultApps = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowDefaultAppMutation" -DefaultValue $false)
        startMenu = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowStartMenuMutation" -DefaultValue $false)
        taskbar = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowTaskbarMutation" -DefaultValue $false)
        imageServicing = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowDismMutation" -DefaultValue $false)
        appx = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowAppxMutation" -DefaultValue $false)
        networkDownload = [bool](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "allowNetworkDownload" -DefaultValue $false)
    }
}

function New-FutureTrueUxRestoreEvidenceRequirements {
    @(
        [pscustomobject][ordered]@{
            scope = "current-user"
            requiredEvidence = @("redacted user identity or SID", "before state", "authorized command envelope", "after state", "independent user-scoped verification")
            safetyGate = "current-user claim must be user-scoped and cannot rely on exit code only"
        },
        [pscustomobject][ordered]@{
            scope = "default-user"
            requiredEvidence = @("template source", "Default User target", "backup or rollback", "before and after template or hive state", "proof that this is not current-user state")
            safetyGate = "Default User evidence cannot be presented as current-user success"
        },
        [pscustomobject][ordered]@{
            scope = "offline-image"
            requiredEvidence = @("image identity", "mount path", "image index", "before and after image state", "rollback or unmount strategy")
            safetyGate = "offline image must be proven separate from the current machine"
        },
        [pscustomobject][ordered]@{
            scope = "machine"
            requiredEvidence = @("machine identity", "machine-wide target", "before state", "after state", "rollback", "admin or VM smoke boundary")
            safetyGate = "machine-level changes require a declared admin or VM smoke boundary"
        }
    )
}

function New-FutureTrueUxRestoreAuthorizationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Manifest,

        [AllowNull()]
        $AuthorizationRequest,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $requiredFields = @($Manifest.requiredAuthorizationFields | ForEach-Object { [string]$_ })
    $missingFields = @()
    foreach ($field in $requiredFields) {
        $value = Get-FutureTrueUxRestoreValue -InputObject $AuthorizationRequest -Name $field -DefaultValue $null
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
            $missingFields += $field
        }
    }

    $blockedReasons = @()
    if ($missingFields.Count -gt 0) {
        $blockedReasons += "missing authorization fields: $($missingFields -join ', ')"
    }

    $allowFlags = Get-FutureTrueUxRestoreMutationAllowFlags -Manifest $Manifest
    foreach ($flagProperty in @($allowFlags.PSObject.Properties)) {
        if ([bool]$flagProperty.Value) {
            $blockedReasons += "manifest mutation flag must remain false: $($flagProperty.Name)"
        }
    }

    $scope = [string](Get-FutureTrueUxRestoreValue -InputObject $AuthorizationRequest -Name "scope" -DefaultValue "")
    $validScopes = @("current-user", "default-user", "offline-image", "machine")
    if (-not [string]::IsNullOrWhiteSpace($scope) -and $validScopes -notcontains $scope) {
        $blockedReasons += "scope is invalid: $scope"
    }

    $claimedScope = [string](Get-FutureTrueUxRestoreValue -InputObject $AuthorizationRequest -Name "claimedScope" -DefaultValue "")
    if (-not [string]::IsNullOrWhiteSpace($claimedScope) -and -not [string]::IsNullOrWhiteSpace($scope) -and $claimedScope -ne $scope) {
        $blockedReasons += "scope mismatch: request scope $scope cannot claim $claimedScope evidence"
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $AuthorizationRequest -Name "mutationRequested" -DefaultValue $false)) {
        $blockedReasons += "mutation request is blocked in authorization intake"
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $AuthorizationRequest -Name "exitCodeOnlySuccess" -DefaultValue $false)) {
        $blockedReasons += "command exit code alone is not UX success evidence"
    }

    if ([bool](Get-FutureTrueUxRestoreValue -InputObject $AuthorizationRequest -Name "manualChecklistAsSuccess" -DefaultValue $false)) {
        $blockedReasons += "manual checklist is not real UX success evidence"
    }

    $privatePathMatches = @(Test-FutureTrueUxRestorePrivatePath -InputObject $AuthorizationRequest)
    if ($privatePathMatches.Count -gt 0) {
        $blockedReasons += "private local path evidence must be redacted"
    }

    $decision = "dry-run-ready"
    if ($blockedReasons.Count -gt 0) {
        $decision = "blocked"
    }

    [pscustomobject][ordered]@{
        reportType = "future-true-ux-restore-authorization"
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        mode = [string](Get-FutureTrueUxRestoreValue -InputObject $Manifest -Name "mode" -DefaultValue "authorization-intake")
        decision = $decision
        missingAuthorizationFields = @($missingFields)
        blockedReasons = @($blockedReasons)
        scope = $scope
        mutationAllowFlags = $allowFlags
        evidenceRequirements = @(New-FutureTrueUxRestoreEvidenceRequirements)
        privatePathMatchCount = $privatePathMatches.Count
        trueExecution = $false
        mutationCount = 0
        commandExitCodeSufficient = $false
        userConfigurationConfirmed = $false
        safety = [pscustomobject][ordered]@{
            registryMutation = $false
            profileMutation = $false
            defaultUserHiveMutation = $false
            defaultAppMutation = $false
            startMenuMutation = $false
            taskbarMutation = $false
            imageServicingMutation = $false
            appxMutation = $false
            networkDownload = $false
            trueExecution = $false
        }
    }
}
