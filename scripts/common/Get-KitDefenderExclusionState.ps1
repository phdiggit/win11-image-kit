#Requires -Version 5.1

. "$PSScriptRoot\Test-KitDefenderExclusionPolicy.ps1"

function Get-KitDefaultDefenderExclusionPreference {
    Get-MpPreference -ErrorAction Stop
}

function ConvertTo-KitDefenderNormalizedValueSet {
    param(
        [AllowNull()]
        $Values = @()
    )

    $set = @{}
    foreach ($value in @(ConvertTo-KitDefenderExclusionArray -Value $Values)) {
        $normalized = Normalize-KitDefenderPathForCompare -Path ([string]$value)
        if (-not [string]::IsNullOrWhiteSpace($normalized)) {
            $set[$normalized] = [string]$value
        }
    }

    return $set
}

function Get-KitDefenderPreferenceValues {
    param(
        [AllowNull()]
        $Preference,

        [Parameter(Mandatory)]
        [ValidateSet("path", "process")]
        [string]$Type
    )

    if ($null -eq $Preference) {
        return @()
    }

    $propertyName = if ($Type -eq "path") { "ExclusionPath" } else { "ExclusionProcess" }
    if ($Preference.PSObject.Properties.Name -notcontains $propertyName) {
        return @()
    }

    return @(ConvertTo-KitDefenderExclusionArray -Value $Preference.$propertyName)
}

function Test-KitDefenderExclusionExistsInPreference {
    param(
        [AllowNull()]
        $Preference,

        [Parameter(Mandatory)]
        [ValidateSet("path", "process")]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$ResolvedValue
    )

    $values = Get-KitDefenderPreferenceValues -Preference $Preference -Type $Type
    $set = ConvertTo-KitDefenderNormalizedValueSet -Values $values
    $normalized = Normalize-KitDefenderPathForCompare -Path $ResolvedValue
    return $set.ContainsKey($normalized)
}

function Get-KitDefenderExclusionState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Exclusions,

        [hashtable]$PathMap = @{},

        [AllowEmptyString()]
        [string]$RepoRoot,

        [scriptblock]$DefenderQuery = $null
    )

    $items = @(ConvertTo-KitDefenderExclusionArray -Value $Exclusions)
    if ($items.Count -eq 0) {
        return @()
    }

    $query = $DefenderQuery
    if ($null -eq $query) {
        $query = {
            Get-KitDefaultDefenderExclusionPreference
        }
    }

    try {
        $preference = & $query
    } catch {
        $results = @()
        foreach ($item in $items) {
            $policy = Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $PathMap -RepoRoot $RepoRoot
            $results += [pscustomobject][ordered]@{
                id = $policy.id
                type = $policy.type
                value = $policy.value
                resolvedValue = $policy.resolvedValue
                expected = $true
                exists = $false
                actual = $null
                status = "failed"
                reason = "defender-query-failed"
                policyStatus = $policy.policyStatus
                policyReason = $policy.policyReason
                data = [pscustomobject]@{
                    errors = @($_.Exception.Message)
                }
            }
        }

        return $results
    }

    $stateResults = @()
    foreach ($item in $items) {
        $policy = Test-KitDefenderExclusionPolicy -Exclusion $item -PathMap $PathMap -RepoRoot $RepoRoot
        $exists = $false
        $actual = @()
        if ($policy.policyStatus -eq "allowed") {
            $exists = Test-KitDefenderExclusionExistsInPreference -Preference $preference -Type $policy.type -ResolvedValue $policy.resolvedValue
            $actual = Get-KitDefenderPreferenceValues -Preference $preference -Type $policy.type
        }

        $stateResults += [pscustomobject][ordered]@{
            id = $policy.id
            type = $policy.type
            value = $policy.value
            resolvedValue = $policy.resolvedValue
            expected = $true
            exists = [bool]$exists
            actual = $actual
            status = if ($exists) { "unchanged" } else { "failed" }
            reason = if ($exists) { "exclusion-present" } else { "exclusion-missing" }
            policyStatus = $policy.policyStatus
            policyReason = $policy.policyReason
            data = [pscustomobject]@{
                required = $policy.required
                failurePolicy = $policy.failurePolicy
            }
        }
    }

    return $stateResults
}
