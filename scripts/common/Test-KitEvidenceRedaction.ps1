#Requires -Version 5.1

function Get-KitEvidenceRedactionObjectProperties {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return @()
    }

    if ($InputObject -is [string]) {
        return @()
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        $results = @()
        foreach ($item in $InputObject) {
            $results += @(Get-KitEvidenceRedactionObjectProperties -InputObject $item)
        }
        return @($results)
    }

    if ($null -ne $InputObject.PSObject -and $null -ne $InputObject.PSObject.Properties) {
        return @($InputObject.PSObject.Properties)
    }

    return @()
}

function Test-KitEvidenceRedaction {
    [CmdletBinding()]
    param(
        [AllowNull()]
        $InputObject,

        [string[]]$ForbiddenFieldNames = @("password", "token", "secret", "privateKey", "credential", "username"),

        [string]$RedactedValue = "<redacted>"
    )

    $blockedFields = @()
    $redactedCount = 0

    function Visit-Node {
        param(
            [AllowNull()]
            $Node,

            [string]$Path = "$"
        )

        if ($null -eq $Node) {
            return
        }

        if ($Node -is [string]) {
            if ([string]$Node -eq $RedactedValue) {
                $script:RedactionVisitRedactedCount++
            }
            return
        }

        if ($Node -is [System.Collections.IEnumerable]) {
            $index = 0
            foreach ($item in $Node) {
                Visit-Node -Node $item -Path ("{0}[{1}]" -f $Path, $index)
                $index++
            }
            return
        }

        foreach ($property in @(Get-KitEvidenceRedactionObjectProperties -InputObject $Node)) {
            $propertyPath = "{0}.{1}" -f $Path, $property.Name
            $isForbidden = @($ForbiddenFieldNames | Where-Object { $_.ToLowerInvariant() -eq $property.Name.ToLowerInvariant() }).Count -gt 0
            if ($isForbidden) {
                if ([string]$property.Value -eq $RedactedValue) {
                    $script:RedactionVisitRedactedCount++
                } else {
                    $script:RedactionVisitBlockedFields += $propertyPath
                }
            }

            Visit-Node -Node $property.Value -Path $propertyPath
        }
    }

    $script:RedactionVisitBlockedFields = @()
    $script:RedactionVisitRedactedCount = 0
    Visit-Node -Node $InputObject
    $blockedFields = @($script:RedactionVisitBlockedFields)
    $redactedCount = [int]$script:RedactionVisitRedactedCount
    $script:RedactionVisitBlockedFields = @()
    $script:RedactionVisitRedactedCount = 0

    [pscustomobject][ordered]@{
        redactedCount = $redactedCount
        blockedCount = $blockedFields.Count
        blockedFields = @($blockedFields)
    }
}
