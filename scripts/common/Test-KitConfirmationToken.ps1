#Requires -Version 5.1

function Test-KitConfirmationToken {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{
            status = "blocked"
            reason = "confirmation token input is missing"
            failureCount = 1
            token = ""
        }
    }

    $token = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "token" -DefaultValue "")
    $targetDiskNumber = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "targetDiskNumber" -DefaultValue "")
    $targetDiskSerial = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "targetDiskSerial" -DefaultValue "")
    $genericToken = [bool](Get-KitControlledExecutionValue -InputObject $InputObject -Name "genericToken" -DefaultValue $false)
    $genericValues = @("YES", "CONFIRM", "I AGREE")
    $reasons = @()

    if ([string]::IsNullOrWhiteSpace($token)) {
        $reasons += "token is missing"
    }

    if ($genericToken -or ($genericValues -contains $token.ToUpperInvariant())) {
        $reasons += "generic token is not allowed"
    }

    $diskNumberMarker = "DISK-$targetDiskNumber"
    if (-not $token.Contains($diskNumberMarker) -and -not $token.Contains($targetDiskSerial)) {
        $reasons += "token must include target disk number or serial"
    }

    $status = "matched"
    if ($reasons.Count -gt 0) {
        $status = "blocked"
    }

    [pscustomobject][ordered]@{
        status = $status
        reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "confirmation token matched fixture target" }
        failureCount = $reasons.Count
        token = $token
        targetDiskNumber = $targetDiskNumber
        targetDiskSerial = $targetDiskSerial
    }
}
