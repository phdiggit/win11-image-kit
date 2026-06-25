function Test-KitContextProperty {
    param(
        [AllowNull()]
        $Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]
}

function Get-KitContextProperty {
    param(
        [AllowNull()]
        $Object,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if (Test-KitContextProperty -Object $Object -Name $Name) {
        return $Object.PSObject.Properties[$Name].Value
    }

    return $DefaultValue
}

function Add-KitUniqueContextHint {
    param(
        [System.Collections.ArrayList]$Hints,

        [AllowEmptyString()]
        [string]$Context
    )

    if ([string]::IsNullOrWhiteSpace($Context)) {
        return
    }

    if (-not $Hints.Contains($Context)) {
        [void]$Hints.Add($Context)
    }
}

function Get-KitContextFromRegistryRoot {
    param(
        [AllowEmptyString()]
        [string]$Root
    )

    $normalized = ([string]$Root).Trim().ToUpperInvariant()
    switch -Regex ($normalized) {
        '^(HKLM|HKEY_LOCAL_MACHINE)' { return "machine" }
        '^(HKCU|HKEY_CURRENT_USER)' { return "current-user" }
        '^(HKU_DEFAULT|HKU:\\?\\.DEFAULT|HKEY_USERS\\\.DEFAULT)' { return "default-user" }
    }

    return $null
}

function Get-KitContextFromPath {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    $value = ([string]$Path).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    $lower = $value.ToLowerInvariant()
    if ($lower -match '(^|[\\/%])users[\\/%]default([\\/%]|$)' -or
        $lower -match '\$\{defaultuserprofile\}' -or
        $lower -match '%systemdrive%[\\/]users[\\/]default') {
        return "default-user"
    }

    if ($lower -match '%userprofile%' -or
        $lower -match '\$env:userprofile' -or
        $lower -match '\$\{currentuserprofile\}' -or
        $lower -match '%localappdata%' -or
        $lower -match '%appdata%') {
        return "current-user"
    }

    if ($lower -match '(^|[\\/%])programdata([\\/%]|$)' -or
        $lower -match '(^|[\\/%])windows([\\/%]|$)' -or
        $lower -match '(^|[\\/%])program files([\\/%]|$)' -or
        $lower -match '%programdata%' -or
        $lower -match '%windir%' -or
        $lower -match '%programfiles%' -or
        $lower -match '\$\{toolroot\}' -or
        $lower -match '\$\{dataroot\}') {
        return "machine"
    }

    return $null
}

function Get-KitAllowedContextsForPhase {
    param(
        [AllowNull()]
        $ScopeConfig,

        [Parameter(Mandatory)]
        [string]$Phase
    )

    if ($null -eq $ScopeConfig -or -not (Test-KitContextProperty -Object $ScopeConfig -Name "phasePolicy")) {
        return @()
    }

    if (-not (Test-KitContextProperty -Object $ScopeConfig.phasePolicy -Name $Phase)) {
        return @()
    }

    return @($ScopeConfig.phasePolicy.$Phase | ForEach-Object { [string]$_ })
}

function Resolve-KitContextScope {
    param(
        [Parameter(Mandatory)]
        $Target,

        [AllowNull()]
        $ScopeConfig = $null,

        [AllowEmptyString()]
        [string]$Phase
    )

    $id = [string](Get-KitContextProperty -Object $Target -Name "id" -DefaultValue "")
    $targetType = [string](Get-KitContextProperty -Object $Target -Name "targetType" -DefaultValue "unknown")
    $root = [string](Get-KitContextProperty -Object $Target -Name "root" -DefaultValue "")
    $path = [string](Get-KitContextProperty -Object $Target -Name "path" -DefaultValue "")
    $declaredContext = [string](Get-KitContextProperty -Object $Target -Name "context" -DefaultValue "")
    $phaseValue = if ([string]::IsNullOrWhiteSpace($Phase)) { [string](Get-KitContextProperty -Object $Target -Name "phase" -DefaultValue "validate") } else { $Phase }
    $mutationPolicy = [string](Get-KitContextProperty -Object $Target -Name "mutationPolicy" -DefaultValue "blocked")
    $reason = [string](Get-KitContextProperty -Object $Target -Name "reason" -DefaultValue "")

    $warnings = @()
    $errors = @()
    $hints = New-Object System.Collections.ArrayList

    Add-KitUniqueContextHint -Hints $hints -Context $declaredContext
    Add-KitUniqueContextHint -Hints $hints -Context (Get-KitContextFromRegistryRoot -Root $root)
    Add-KitUniqueContextHint -Hints $hints -Context (Get-KitContextFromPath -Path $path)

    $context = "unknown"
    if ($hints.Count -eq 1) {
        $context = [string]$hints[0]
    } elseif ($hints.Count -gt 1) {
        $context = "unknown"
        $errors += "ambiguous context hints: $($hints -join ',')"
        if ([string]::IsNullOrWhiteSpace($reason)) {
            $reason = "ambiguous context hints must be resolved manually"
        }
    }

    if ($context -eq "unknown") {
        $errors += "unknown context"
        if ([string]::IsNullOrWhiteSpace($reason)) {
            $reason = "unknown context cannot be routed automatically"
        }
    }

    $allowedContexts = @(Get-KitAllowedContextsForPhase -ScopeConfig $ScopeConfig -Phase $phaseValue)
    if ($allowedContexts.Count -gt 0 -and $context -ne "unknown" -and $allowedContexts -notcontains $context) {
        $errors += "phasePolicy mismatch: phase=$phaseValue context=$context"
    }

    if ($root -and $targetType -eq "registry") {
        $rootContext = Get-KitContextFromRegistryRoot -Root $root
        if ($null -eq $rootContext) {
            $errors += "unknown registry root: $root"
        }
    }

    if ($context -eq "current-user" -and $phaseValue -eq "build") {
        $errors += "current-user context is not allowed in build phase"
    }

    if ($mutationPolicy -notin @("planned", "manual", "blocked")) {
        $errors += "invalid mutationPolicy: $mutationPolicy"
    }

    $status = "allowed"
    if ($mutationPolicy -eq "blocked" -or $errors.Count -gt 0) {
        $status = "blocked"
    } elseif ($mutationPolicy -eq "manual") {
        $status = "manual"
    }

    if ($status -eq "manual" -and $warnings.Count -eq 0) {
        $warnings += "manual review required"
    }

    [pscustomobject]@{
        id = $id
        context = $context
        targetType = $targetType
        phase = $phaseValue
        root = $root
        path = $path
        mutationPolicy = $mutationPolicy
        status = $status
        reason = $reason
        warnings = @($warnings)
        errors = @($errors)
    }
}
