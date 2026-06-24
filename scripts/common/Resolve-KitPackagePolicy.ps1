function Test-KitJsonProperty {
    param(
        [AllowNull()]
        $Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }

    if ($null -eq $Object.PSObject) {
        return $false
    }

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Resolve-KitPackagePolicy {
    param(
        [Parameter(Mandatory)]
        $Package
    )

    $packageType = [string]$Package.type
    $required = $true
    $failurePolicy = "fail"
    $allowMissingSource = $false

    if ($packageType -eq "manual") {
        $required = $false
        $failurePolicy = "manual"
        $allowMissingSource = $true
    }

    if (Test-KitJsonProperty -Object $Package -Name "required") {
        $required = [bool]$Package.required
    }

    if (Test-KitJsonProperty -Object $Package -Name "failurePolicy") {
        $configuredFailurePolicy = [string]$Package.failurePolicy
        if (@("fail", "skip", "manual") -contains $configuredFailurePolicy) {
            $failurePolicy = $configuredFailurePolicy
        } else {
            $failurePolicy = "fail"
        }
    }

    if (Test-KitJsonProperty -Object $Package -Name "allowMissingSource") {
        $allowMissingSource = [bool]$Package.allowMissingSource
    }

    if ($required) {
        $failurePolicy = "fail"
        $allowMissingSource = $false
    }

    if ($failurePolicy -eq "fail") {
        $allowMissingSource = $false
    }

    if (-not $allowMissingSource -and $failurePolicy -ne "fail") {
        $failurePolicy = "fail"
    }

    [pscustomobject]@{
        required = [bool]$required
        failurePolicy = $failurePolicy
        allowMissingSource = [bool]$allowMissingSource
    }
}

function Get-KitPackageMissingSourceAction {
    param(
        [Parameter(Mandatory)]
        $Policy
    )

    if ([bool]$Policy.required -or [string]$Policy.failurePolicy -eq "fail" -or -not [bool]$Policy.allowMissingSource) {
        return "fail"
    }

    if ([string]$Policy.failurePolicy -eq "manual") {
        return "manual"
    }

    return "skip"
}
