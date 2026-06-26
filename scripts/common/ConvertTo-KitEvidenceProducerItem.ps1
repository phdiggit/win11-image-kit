#Requires -Version 5.1

function New-KitEvidenceProducerNormalizationResult {
    param(
        [Parameter(Mandatory)]
        $Item,

        [int]$NormalizedCount = 0,

        [int]$MissingRequiredCount = 0,

        [int]$ReportTypeMismatchCount = 0,

        [int]$DisallowedManualCount = 0,

        [int]$DisallowedNotCapturedCount = 0,

        [int]$InputPolicyViolationCount = 0
    )

    [pscustomobject][ordered]@{
        item = $Item
        normalizedCount = $NormalizedCount
        missingRequiredCount = $MissingRequiredCount
        reportTypeMismatchCount = $ReportTypeMismatchCount
        disallowedManualCount = $DisallowedManualCount
        disallowedNotCapturedCount = $DisallowedNotCapturedCount
        inputPolicyViolationCount = $InputPolicyViolationCount
    }
}

function New-KitEvidenceSyntheticInputReport {
    param(
        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$ReportType,

        [Parameter(Mandatory)]
        [datetime]$GeneratedAt,

        [Parameter(Mandatory)]
        $DefaultSource,

        [string]$Reason
    )

    [pscustomobject][ordered]@{
        reportType = $ReportType
        status = $Status
        generatedAt = $GeneratedAt.ToString("s")
        reproducible = $false
        reason = $Reason
        sourceMetadata = $DefaultSource
        artifactReferences = @()
    }
}

function ConvertTo-KitEvidenceProducerItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Producer,

        [AllowNull()]
        $InputRecord,

        [Parameter(Mandatory)]
        $DefaultSource,

        [Parameter(Mandatory)]
        [datetime]$GeneratedAt,

        [Parameter(Mandatory)]
        [string]$RunId,

        [string]$UpstreamRunId
    )

    if ($null -eq $InputRecord) {
        $item = New-KitEvidenceItem -Producer $Producer -InputReport $null -DefaultSource $DefaultSource -GeneratedAt $GeneratedAt -RunId $RunId -UpstreamRunId $UpstreamRunId
        return New-KitEvidenceProducerNormalizationResult -Item $item
    }

    $inputPolicyViolationCount = @($InputRecord.errors).Count
    if ($inputPolicyViolationCount -gt 0) {
        $synthetic = New-KitEvidenceSyntheticInputReport `
            -Status "failed" `
            -ReportType ([string]$Producer.reportType) `
            -GeneratedAt $GeneratedAt `
            -DefaultSource $DefaultSource `
            -Reason "Input index policy violation."
        $item = New-KitEvidenceItem -Producer $Producer -InputReport $synthetic -DefaultSource $DefaultSource -GeneratedAt $GeneratedAt -RunId $RunId -UpstreamRunId $UpstreamRunId
        return New-KitEvidenceProducerNormalizationResult -Item $item -InputPolicyViolationCount 1
    }

    if (-not [bool]$InputRecord.exists) {
        if ([bool]$InputRecord.required -and -not [bool]$InputRecord.allowMissing) {
            $synthetic = New-KitEvidenceSyntheticInputReport `
                -Status "failed" `
                -ReportType ([string]$Producer.reportType) `
                -GeneratedAt $GeneratedAt `
                -DefaultSource $DefaultSource `
                -Reason "Required producer report input is missing."
            $item = New-KitEvidenceItem -Producer $Producer -InputReport $synthetic -DefaultSource $DefaultSource -GeneratedAt $GeneratedAt -RunId $RunId -UpstreamRunId $UpstreamRunId
            return New-KitEvidenceProducerNormalizationResult -Item $item -MissingRequiredCount 1
        }

        $synthetic = New-KitEvidenceSyntheticInputReport `
            -Status "not-captured" `
            -ReportType ([string]$Producer.reportType) `
            -GeneratedAt $GeneratedAt `
            -DefaultSource $DefaultSource `
            -Reason "Producer report input is missing and allowed by the input index."
        $item = New-KitEvidenceItem -Producer $Producer -InputReport $synthetic -DefaultSource $DefaultSource -GeneratedAt $GeneratedAt -RunId $RunId -UpstreamRunId $UpstreamRunId
        return New-KitEvidenceProducerNormalizationResult -Item $item
    }

    $inputReport = $InputRecord.report
    $normalizedCount = 1
    $reportTypeMismatchCount = 0
    $disallowedManualCount = 0
    $disallowedNotCapturedCount = 0

    $actualReportType = [string](Get-KitEvidenceValue -InputObject $inputReport -Name "reportType" -DefaultValue "")
    if ($actualReportType -ne [string]$InputRecord.expectedReportType -or $actualReportType -ne [string]$Producer.reportType) {
        $reportTypeMismatchCount = 1
        $inputReport = New-KitEvidenceSyntheticInputReport `
            -Status "failed" `
            -ReportType ([string]$Producer.reportType) `
            -GeneratedAt $GeneratedAt `
            -DefaultSource $DefaultSource `
            -Reason ("Report type mismatch for producer {0}." -f $Producer.id)
    }

    $status = [string](Get-KitEvidenceValue -InputObject $inputReport -Name "status" -DefaultValue "")
    if ($status -eq "manual" -and -not [bool]$InputRecord.allowManual) {
        $disallowedManualCount = 1
    }
    if ($status -eq "not-captured" -and -not [bool]$InputRecord.allowNotCaptured) {
        $disallowedNotCapturedCount = 1
    }

    $item = New-KitEvidenceItem -Producer $Producer -InputReport $inputReport -DefaultSource $DefaultSource -GeneratedAt $GeneratedAt -RunId $RunId -UpstreamRunId $UpstreamRunId
    New-KitEvidenceProducerNormalizationResult `
        -Item $item `
        -NormalizedCount $normalizedCount `
        -ReportTypeMismatchCount $reportTypeMismatchCount `
        -DisallowedManualCount $disallowedManualCount `
        -DisallowedNotCapturedCount $disallowedNotCapturedCount
}
