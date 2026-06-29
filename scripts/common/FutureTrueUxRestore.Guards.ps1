#Requires -Version 5.1

function Get-FutureTrueUxRestoreFrozenFlagNames {
    @("authorizationApproved", "executionApproved", "executeReady", "trueExecution")
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

function Test-FutureTrueUxRestoreTruthy {
    param(
        [AllowNull()]
        $Value
    )

    if ($Value -eq $true) {
        return $true
    }

    if ($Value -is [string]) {
        return ($Value -match '^(?i:true|yes|1)$')
    }

    return $false
}

function Get-FutureTrueUxRestoreDangerousVocabularyPattern {
    $terms = @(
        "registry",
        "hklm",
        "hkcu",
        "dism",
        "appx",
        "startlayout",
        "defender",
        "junction",
        "service",
        "sysprep",
        "winget",
        "choco",
        "msiexec",
        "invoke-webrequest",
        "invoke-restmethod",
        "install-module"
    )

    return "(?i)\b($($terms -join '|'))\b"
}
