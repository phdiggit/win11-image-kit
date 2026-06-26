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

    if ($InputObject -is [System.Collections.IDictionary]) {
        $properties = @()
        foreach ($key in $InputObject.Keys) {
            $properties += [pscustomobject][ordered]@{
                Name = [string]$key
                Value = $InputObject[$key]
            }
        }
        return @($properties)
    }

    if ($null -ne $InputObject.PSObject -and $null -ne $InputObject.PSObject.Properties) {
        return @($InputObject.PSObject.Properties)
    }

    return @()
}

function Test-KitEvidenceRedactionScalar {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $true
    }

    if ($InputObject -is [string]) {
        return $true
    }

    if ($InputObject -is [bool]) {
        return $true
    }

    if ($InputObject -is [char]) {
        return $true
    }

    if ($InputObject -is [datetime]) {
        return $true
    }

    if ($InputObject -is [guid]) {
        return $true
    }

    if ($InputObject -is [System.ValueType]) {
        return $true
    }

    return $false
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

        if (Test-KitEvidenceRedactionScalar -InputObject $Node) {
            return
        }

        $objectProperties = @()
        if ($Node -is [System.Collections.IDictionary]) {
            $objectProperties = @(Get-KitEvidenceRedactionObjectProperties -InputObject $Node)
        } elseif ($Node.PSObject.TypeNames -contains "System.Management.Automation.PSCustomObject") {
            $objectProperties = @(Get-KitEvidenceRedactionObjectProperties -InputObject $Node)
        }

        foreach ($property in $objectProperties) {
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

        if ($objectProperties.Count -gt 0) {
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
