#Requires -Version 5.1

. "$PSScriptRoot\Resolve-KitPath.ps1"

function Get-KitDefenderExclusionProperty {
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

    if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }

    if ($null -ne $InputObject.PSObject -and $InputObject.PSObject.Properties.Name -contains $Name) {
        return $InputObject.$Name
    }

    return $DefaultValue
}

function Test-KitDefenderExclusionPropertyExists {
    param(
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $false
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject.Contains($Name)
    }

    return ($null -ne $InputObject.PSObject -and $InputObject.PSObject.Properties.Name -contains $Name)
}

function ConvertTo-KitDefenderExclusionArray {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [System.Array] -or $Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value)
    }

    return @($Value)
}

function Get-KitDefenderExclusionRequired {
    param(
        [AllowNull()]
        $Exclusion
    )

    if (Test-KitDefenderExclusionPropertyExists -InputObject $Exclusion -Name "required") {
        return [bool](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "required" -DefaultValue $false)
    }

    return $false
}

function Get-KitDefenderExclusionFailurePolicy {
    param(
        [AllowNull()]
        $Exclusion
    )

    $policy = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "failurePolicy" -DefaultValue "manual")
    if ([string]::IsNullOrWhiteSpace($policy)) {
        return "manual"
    }

    return $policy.ToLowerInvariant()
}

function Test-KitDefenderExclusionEnabled {
    param(
        [AllowNull()]
        $Exclusion
    )

    if (Test-KitDefenderExclusionPropertyExists -InputObject $Exclusion -Name "enabled") {
        return [bool](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "enabled" -DefaultValue $true)
    }

    return $true
}

function Resolve-KitDefenderExclusionValue {
    param(
        [AllowEmptyString()]
        [string]$Value,

        [hashtable]$PathMap = @{}
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $resolved = Resolve-KitPath -Path $Value -PathMap $PathMap
    return $resolved.Replace("/", "\").Trim()
}

function Normalize-KitDefenderPathForCompare {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    $normalized = [Environment]::ExpandEnvironmentVariables($Path).Replace("/", "\").Trim()
    if ($normalized -match '[*?]') {
        return $normalized.TrimEnd("\").ToLowerInvariant()
    }

    try {
        $normalized = [IO.Path]::GetFullPath($normalized)
    } catch {
    }

    if ($normalized -notmatch '^[A-Za-z]:\\$' -and $normalized -notmatch '^\\\\[^\\]+\\[^\\]+\\?$') {
        $normalized = $normalized.TrimEnd("\")
    }

    return $normalized.ToLowerInvariant()
}

function Test-KitDefenderPathIsUnder {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [AllowEmptyString()]
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($Root)) {
        return $false
    }

    $normalizedPath = Normalize-KitDefenderPathForCompare -Path $Path
    $normalizedRoot = Normalize-KitDefenderPathForCompare -Path $Root
    if ([string]::IsNullOrWhiteSpace($normalizedPath) -or [string]::IsNullOrWhiteSpace($normalizedRoot)) {
        return $false
    }

    if ($normalizedPath -eq $normalizedRoot) {
        return $false
    }

    if ($normalizedRoot.EndsWith("\")) {
        return $normalizedPath.StartsWith($normalizedRoot)
    }

    return $normalizedPath.StartsWith($normalizedRoot + "\")
}

function Get-KitDefenderManagedRoots {
    param(
        [hashtable]$PathMap = @{},

        [AllowEmptyString()]
        [string]$RepoRoot
    )

    $roots = @()
    foreach ($key in @("WorkRoot", "DeployRoot", "PackageRoot", "ConfigRoot", "ToolRoot", "DataRoot")) {
        if ($PathMap.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace([string]$PathMap[$key])) {
            $roots += [string]$PathMap[$key]
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $roots += $RepoRoot
    }

    return @($roots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function New-KitDefenderExclusionPolicyResult {
    param(
        [Parameter(Mandatory)]
        $Exclusion,

        [AllowEmptyString()]
        [string]$ResolvedValue,

        [Parameter(Mandatory)]
        [ValidateSet("allowed", "blocked", "manual", "skipped")]
        [string]$PolicyStatus,

        [AllowEmptyString()]
        [string]$PolicyReason,

        [AllowNull()]
        $Warnings = @(),

        [AllowNull()]
        $Errors = @(),

        [AllowEmptyString()]
        [string]$ManualAction
    )

    [pscustomobject][ordered]@{
        id = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "id" -DefaultValue "")
        type = ([string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "type" -DefaultValue "")).ToLowerInvariant()
        value = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "value" -DefaultValue "")
        resolvedValue = $ResolvedValue
        scope = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "scope" -DefaultValue "")
        reason = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "reason" -DefaultValue "")
        required = Get-KitDefenderExclusionRequired -Exclusion $Exclusion
        failurePolicy = Get-KitDefenderExclusionFailurePolicy -Exclusion $Exclusion
        enabled = Test-KitDefenderExclusionEnabled -Exclusion $Exclusion
        policyStatus = $PolicyStatus
        policyReason = $PolicyReason
        warnings = @(ConvertTo-KitDefenderExclusionArray -Value $Warnings)
        errors = @(ConvertTo-KitDefenderExclusionArray -Value $Errors)
        manualAction = $ManualAction
    }
}

function Test-KitDefenderDangerousPath {
    param(
        [Parameter(Mandatory)]
        [string]$ResolvedValue
    )

    $normalized = Normalize-KitDefenderPathForCompare -Path $ResolvedValue
    $blockedRoots = @(
        (Normalize-KitDefenderPathForCompare -Path "C:\"),
        (Normalize-KitDefenderPathForCompare -Path "$env:SystemRoot"),
        (Normalize-KitDefenderPathForCompare -Path "C:\Windows"),
        (Normalize-KitDefenderPathForCompare -Path "C:\Windows\System32"),
        (Normalize-KitDefenderPathForCompare -Path "$env:ProgramFiles"),
        (Normalize-KitDefenderPathForCompare -Path "${env:ProgramFiles(x86)}"),
        (Normalize-KitDefenderPathForCompare -Path "C:\Users"),
        (Normalize-KitDefenderPathForCompare -Path "$env:USERPROFILE")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($root in $blockedRoots) {
        if ($normalized -eq $root) {
            return "blocked-broad-system-path"
        }
    }

    if ($normalized -match '^[a-z]:\\$') {
        return "blocked-drive-root"
    }

    if ($normalized -match '^\\\\[^\\]+\\[^\\]+\\?$') {
        return "blocked-unc-share-root"
    }

    if ($normalized -match '(^|\\)(desktop|downloads)(\\|$)') {
        return "blocked-user-shell-folder"
    }

    return ""
}

function Test-KitDefenderGenericProcess {
    param(
        [Parameter(Mandatory)]
        [string]$ResolvedValue
    )

    $fileName = ([IO.Path]::GetFileName($ResolvedValue)).ToLowerInvariant()
    $blockedNames = @(
        "powershell.exe",
        "pwsh.exe",
        "cmd.exe",
        "conhost.exe",
        "explorer.exe",
        "msiexec.exe",
        "setup.exe",
        "python.exe",
        "node.exe"
    )

    if ($blockedNames -contains $fileName) {
        return "blocked-generic-process"
    }

    $normalized = Normalize-KitDefenderPathForCompare -Path $ResolvedValue
    foreach ($root in @("$env:SystemRoot", "$env:ProgramFiles", "${env:ProgramFiles(x86)}")) {
        if (-not [string]::IsNullOrWhiteSpace($root) -and (Test-KitDefenderPathIsUnder -Path $normalized -Root $root)) {
            return "blocked-system-process"
        }
    }

    return ""
}

function Test-KitDefenderExclusionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Exclusion,

        [hashtable]$PathMap = @{},

        [AllowEmptyString()]
        [string]$RepoRoot
    )

    $id = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "id" -DefaultValue "")
    $type = ([string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "type" -DefaultValue "")).ToLowerInvariant()
    $value = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "value" -DefaultValue "")
    $scope = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "scope" -DefaultValue "")
    $reason = [string](Get-KitDefenderExclusionProperty -InputObject $Exclusion -Name "reason" -DefaultValue "")
    $failurePolicy = Get-KitDefenderExclusionFailurePolicy -Exclusion $Exclusion
    $resolvedValue = Resolve-KitDefenderExclusionValue -Value $value -PathMap $PathMap
    $errors = @()

    if (-not (Test-KitDefenderExclusionEnabled -Exclusion $Exclusion)) {
        return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "skipped" -PolicyReason "disabled"
    }

    if ([string]::IsNullOrWhiteSpace($id)) {
        $errors += "missing-id"
    }
    if ([string]::IsNullOrWhiteSpace($type)) {
        $errors += "missing-type"
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $errors += "missing-value"
    }
    if ([string]::IsNullOrWhiteSpace($scope)) {
        $errors += "missing-scope"
    }
    if ([string]::IsNullOrWhiteSpace($reason)) {
        $errors += "missing-reason"
    }
    if (@("fail", "skip", "manual") -notcontains $failurePolicy) {
        $errors += "invalid-failure-policy"
    }
    if (@("path", "process") -notcontains $type) {
        $errors += "unsupported-type"
    }
    if ($resolvedValue -match '\$\{[^}]+\}') {
        $errors += "unresolved-path-token"
    }
    if ($resolvedValue -match '[*?]') {
        $errors += "wildcard-not-allowed"
    }
    if ($resolvedValue -match '(^|[\\/])\.\.([\\/]|$)') {
        $errors += "path-traversal-not-allowed"
    }
    if ($errors.Count -gt 0) {
        return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "blocked" -PolicyReason ($errors -join ";") -Errors $errors
    }

    if (-not [IO.Path]::IsPathRooted($resolvedValue)) {
        return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "blocked" -PolicyReason "path-must-be-absolute" -Errors @("path-must-be-absolute")
    }

    $managedRoots = @(Get-KitDefenderManagedRoots -PathMap $PathMap -RepoRoot $RepoRoot)
    $underManagedRoot = $false
    foreach ($root in $managedRoots) {
        if (Test-KitDefenderPathIsUnder -Path $resolvedValue -Root $root) {
            $underManagedRoot = $true
            break
        }
    }

    if (-not $underManagedRoot) {
        return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "blocked" -PolicyReason "outside-managed-roots" -Errors @("outside-managed-roots")
    }

    if ($type -eq "path") {
        $dangerReason = Test-KitDefenderDangerousPath -ResolvedValue $resolvedValue
        if (-not [string]::IsNullOrWhiteSpace($dangerReason)) {
            return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "blocked" -PolicyReason $dangerReason -Errors @($dangerReason)
        }

        if (Test-Path -LiteralPath $resolvedValue) {
            $item = Get-Item -LiteralPath $resolvedValue -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "manual" -PolicyReason "reparse-point-needs-review" -ManualAction "Inspect the reparse point target before adding this Defender exclusion."
            }
        }
    }

    if ($type -eq "process") {
        $genericReason = Test-KitDefenderGenericProcess -ResolvedValue $resolvedValue
        if (-not [string]::IsNullOrWhiteSpace($genericReason)) {
            return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "blocked" -PolicyReason $genericReason -Errors @($genericReason)
        }

        $extension = ([IO.Path]::GetExtension($resolvedValue)).ToLowerInvariant()
        if (@(".exe", ".ps1", ".cmd", ".bat") -notcontains $extension) {
            return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "blocked" -PolicyReason "process-must-be-explicit-executable" -Errors @("process-must-be-explicit-executable")
        }
    }

    return New-KitDefenderExclusionPolicyResult -Exclusion $Exclusion -ResolvedValue $resolvedValue -PolicyStatus "allowed" -PolicyReason "allowed-managed-scope"
}
