#Requires -Version 5.1

function Get-FutureTrueUxRestoreFrozenFlagNames {
    @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")
}

function Get-FutureTrueUxRestoreSupportedScopes {
    @("current-user", "default-user", "offline-image", "machine")
}

function New-FutureTrueUxRestoreFrozenExecutionState {
    [pscustomobject][ordered]@{
        authorizationApproved = $false
        executionApproved = $false
        executeReady = $false
        trueExecution = $false
        mutationCount = 0
    }
}

function Get-FutureTrueUxRestoreGuardValue {
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

function Get-FutureTrueUxRestoreFrozenStateDrift {
    param(
        [AllowNull()]
        $InputObject,

        [string]$Prefix = "",

        [string[]]$FlagNames = @(Get-FutureTrueUxRestoreFrozenFlagNames)
    )

    $drift = @()
    foreach ($flagName in @($FlagNames)) {
        if ([bool](Get-FutureTrueUxRestoreGuardValue -InputObject $InputObject -Name $flagName -DefaultValue $false)) {
            $drift += "$($Prefix)$flagName"
        }
    }

    if ([int](Get-FutureTrueUxRestoreGuardValue -InputObject $InputObject -Name "mutationCount" -DefaultValue 0) -ne 0) {
        $drift += "$($Prefix)mutationCount"
    }

    @($drift)
}

function Get-FutureTrueUxRestoreFrozenStateMessages {
    param(
        [AllowNull()]
        $InputObject,

        [string]$Subject = "",

        [string[]]$FlagNames = @(Get-FutureTrueUxRestoreFrozenFlagNames)
    )

    $messages = @()
    $prefix = ""
    if (-not [string]::IsNullOrWhiteSpace($Subject)) {
        $prefix = "$Subject "
    }

    foreach ($flagName in @($FlagNames)) {
        if ([bool](Get-FutureTrueUxRestoreGuardValue -InputObject $InputObject -Name $flagName -DefaultValue $false)) {
            $messages += "$prefix$flagName must remain false"
        }
    }

    if ([int](Get-FutureTrueUxRestoreGuardValue -InputObject $InputObject -Name "mutationCount" -DefaultValue 0) -ne 0) {
        $messages += "$($prefix)mutationCount must remain 0"
    }

    @($messages)
}

function Get-FutureTrueUxRestoreIssueAutoClosePattern {
    param(
        [int]$IssueNumber = 18
    )

    '(?i)\b({0}|{1}|{2})\s+#{3}\b' -f ("fix" + "es"), ("close" + "s"), ("resolve" + "s"), $IssueNumber
}

function Get-FutureTrueUxRestoreStatePromotionPattern {
    '(?i)\bauthorization-review-ready\b.*\b(is|becomes|promotes to|counts as)\b.*\b(execute-ready|closure-ready)\b'
}

function Get-FutureTrueUxRestoreEvidencePromotionPattern {
    param(
        [ValidateSet("NoExecutionAudit")]
        [string]$Scope = "NoExecutionAudit"
    )

    '(?i)\b(CI|dry-run|handler report|manual checklist|mock packet|report-only)\b.*\b(is|counts as|promotes to|can be treated as)\b.*\b(true UX restore evidence|real restore evidence|real UX evidence)\b'
}

function New-FutureTrueUxRestoreLiteralPattern {
    param(
        [Parameter(Mandatory)]
        [string[]]$Parts
    )

    [regex]::Escape(($Parts -join ""))
}

function Get-FutureTrueUxRestoreDangerousCommandPatterns {
    @(
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Start", "-", "Process")),
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Invoke", "-", "Expression")),
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Set", "-", "Item", "Property")),
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("New", "-", "Item", "Property")),
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Remove", "-", "Appx", "Package")),
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Add", "-", "Mp", "Preference")),
        "\b$(([char]100).ToString())$(([char]105).ToString())$(([char]115).ToString())$(([char]109).ToString())\b",
        "\b$(([char]119).ToString())$(([char]105).ToString())$(([char]110).ToString())$(([char]103).ToString())$(([char]101).ToString())$(([char]116).ToString())\b",
        "\b$(([char]99).ToString())$(([char]104).ToString())$(([char]111).ToString())$(([char]99).ToString())$(([char]111).ToString())\b",
        "\b$(([char]109).ToString())$(([char]115).ToString())$(([char]105).ToString())$(([char]101).ToString())$(([char]120).ToString())$(([char]101).ToString())$(([char]99).ToString())\b",
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Invoke", "-", "Web", "Request")),
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Invoke", "-", "Rest", "Method")),
        (New-FutureTrueUxRestoreLiteralPattern -Parts @("Install", "-", "Module"))
    )
}

function Get-FutureTrueUxRestoreDocumentText {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Test-FutureTrueUxRestoreStatusMarker {
    param(
        [AllowNull()]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Status
    )

    return ($Text -match ('Status:\s*`{0}`' -f [regex]::Escape($Status)))
}
