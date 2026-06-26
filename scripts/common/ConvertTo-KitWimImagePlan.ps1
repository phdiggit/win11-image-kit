#Requires -Version 5.1

function ConvertTo-KitWimImagePlan {
    param(
        [AllowNull()]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject][ordered]@{
            status = "blocked"
            reason = "image metadata input is missing"
            failureCount = 1
            imagePath = ""
        }
    }

    $reasons = @()
    $imagePath = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "imagePath" -DefaultValue "")

    if ($imagePath -notmatch '^fixture://') {
        $reasons += "image path must be fixture scoped"
    }

    if ([string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "expectedSha256") -ne [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "actualSha256")) {
        $reasons += "image hash mismatch"
    }

    if ([string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "expectedImageIndex") -ne [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "imageIndex")) {
        $reasons += "image index mismatch"
    }

    if ([string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "expectedArchitecture") -ne [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "architecture")) {
        $reasons += "image architecture mismatch"
    }

    if ([string]::IsNullOrWhiteSpace([string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "sourceRunId" -DefaultValue ""))) {
        $reasons += "source run id is missing"
    }

    $status = "matched"
    if ($reasons.Count -gt 0) {
        $status = "blocked"
    }

    [pscustomobject][ordered]@{
        status = $status
        reason = if ($reasons.Count -gt 0) { $reasons -join "; " } else { "image metadata matched fixture expectations" }
        failureCount = $reasons.Count
        imagePath = $imagePath
        imageIndex = [int](Get-KitControlledExecutionValue -InputObject $InputObject -Name "imageIndex" -DefaultValue 0)
        architecture = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "architecture" -DefaultValue "")
        edition = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "edition" -DefaultValue "")
        sourceRunId = [string](Get-KitControlledExecutionValue -InputObject $InputObject -Name "sourceRunId" -DefaultValue "")
    }
}
