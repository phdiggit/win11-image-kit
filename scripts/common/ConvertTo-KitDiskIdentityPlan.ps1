#Requires -Version 5.1

function ConvertTo-KitDiskIdentityPlan {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{
            status = "blocked"
            reason = "disk identity input is missing"
            mismatchCount = 1
            target = $null
            expected = $null
            partitions = @()
        }
    }

    $reasons = @()
    $target = Get-KitControlledExecutionValue -InputObject $InputObject -Name "target"
    $expected = Get-KitControlledExecutionValue -InputObject $InputObject -Name "expected"

    foreach ($name in @("diskNumber", "serial", "sizeBytes", "busType")) {
        $targetValue = Get-KitControlledExecutionValue -InputObject $target -Name $name
        $expectedValue = Get-KitControlledExecutionValue -InputObject $expected -Name $name
        if ($null -eq $expectedValue -or [string]::IsNullOrWhiteSpace([string]$expectedValue)) {
            $reasons += "expected $name is missing"
        } elseif ([string]$targetValue -ne [string]$expectedValue) {
            $reasons += "$name mismatch"
        }
    }

    $candidateCount = [int](Get-KitControlledExecutionValue -InputObject $InputObject -Name "candidateCount" -DefaultValue 1)
    if ($candidateCount -ne 1) {
        $reasons += "candidate disk count must be exactly 1"
    }

    $status = "matched"
    if ($reasons.Count -gt 0) {
        $status = "blocked"
    }

    [pscustomobject][ordered]@{
        status = $status
        reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "disk identity matched fixture expectations" }
        mismatchCount = $reasons.Count
        target = $target
        expected = $expected
        partitions = @($InputObject.partitions)
    }
}
