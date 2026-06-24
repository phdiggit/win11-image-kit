#Requires -Version 5.1

function Get-KitPackageReportReference {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowEmptyString()]
        [string]$StepName,

        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required,

        [string]$ReportType = "software-package-results"
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $exists = Test-Path -LiteralPath $Path
    $packageSummary = $null
    $errorCode = $null

    if (-not $exists) {
        $errorCode = "report-missing"
    } else {
        try {
            $childReport = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($childReport.PSObject.Properties.Name -contains "packageSummary") {
                $packageSummary = Copy-KitPackageSummaryWithoutResults -PackageSummary $childReport.packageSummary
            } else {
                $errorCode = "package-summary-missing"
            }
        } catch {
            $errorCode = "report-parse-failed"
            if ($Required) {
                throw "Package report parse failed: $Path - $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject][ordered]@{
        name = $Name
        stepName = $StepName
        reportType = $ReportType
        path = $Path
        required = [bool]$Required
        exists = [bool]$exists
        packageSummary = $packageSummary
        error = $errorCode
    }
}

function Copy-KitPackageSummaryWithoutResults {
    param(
        [AllowNull()]
        $PackageSummary
    )

    if ($null -eq $PackageSummary) {
        return $null
    }

    $summary = [ordered]@{}
    foreach ($property in $PackageSummary.PSObject.Properties) {
        if ($property.Name -eq "results") {
            continue
        }

        $summary[$property.Name] = $property.Value
    }

    [pscustomobject]$summary
}

function Get-KitPackageReportAggregate {
    param(
        [AllowNull()]
        $PackageReports = @()
    )

    $reports = @($PackageReports | Where-Object { $null -ne $_ })
    $aggregate = [ordered]@{
        reports = $reports.Count
        existing = 0
        missing = 0
        failedRequired = 0
        failedOptional = 0
        skipped = 0
        manual = 0
        whatif = 0
        testCommandRunCount = 0
        testCommandSuccessCount = 0
        testCommandFailedCount = 0
        testCommandNotRunCount = 0
    }

    foreach ($report in $reports) {
        if ([bool]$report.exists) {
            $aggregate.existing++
        } else {
            $aggregate.missing++
        }

        if ($null -eq $report.packageSummary) {
            continue
        }

        $summary = $report.packageSummary
        $aggregate.failedRequired += [int]$summary.failedRequiredCount
        $aggregate.failedOptional += [int]$summary.failedOptionalCount

        if ($null -ne $summary.statusCounts) {
            $aggregate.skipped += [int]$summary.statusCounts.skipped
            $aggregate.manual += [int]$summary.statusCounts.manual
            $aggregate.whatif += [int]$summary.statusCounts.whatif
        }

        if ($null -ne $summary.PSObject.Properties["testCommandRunCount"]) {
            $aggregate.testCommandRunCount += [int]$summary.testCommandRunCount
        }
        if ($null -ne $summary.PSObject.Properties["testCommandSuccessCount"]) {
            $aggregate.testCommandSuccessCount += [int]$summary.testCommandSuccessCount
        }
        if ($null -ne $summary.PSObject.Properties["testCommandFailedCount"]) {
            $aggregate.testCommandFailedCount += [int]$summary.testCommandFailedCount
        }
        if ($null -ne $summary.PSObject.Properties["testCommandNotRunCount"]) {
            $aggregate.testCommandNotRunCount += [int]$summary.testCommandNotRunCount
        }
    }

    [pscustomobject]$aggregate
}

function Get-KitServiceReportReference {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowEmptyString()]
        [string]$StepName,

        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required,

        [string]$ReportType = "service-state-verification"
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $exists = Test-Path -LiteralPath $Path
    $serviceSummary = $null
    $errorCode = $null

    if (-not $exists) {
        $errorCode = "report-missing"
    } else {
        try {
            $childReport = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($childReport.PSObject.Properties.Name -contains "serviceSummary") {
                $serviceSummary = Copy-KitPackageSummaryWithoutResults -PackageSummary $childReport.serviceSummary
            } else {
                $errorCode = "service-summary-missing"
            }
        } catch {
            $errorCode = "report-parse-failed"
            if ($Required) {
                throw "Service report parse failed: $Path - $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject][ordered]@{
        name = $Name
        stepName = $StepName
        reportType = $ReportType
        path = $Path
        required = [bool]$Required
        exists = [bool]$exists
        serviceSummary = $serviceSummary
        error = $errorCode
    }
}

function Get-KitServiceReportAggregate {
    param(
        [AllowNull()]
        $ServiceReports = @()
    )

    $reports = @($ServiceReports | Where-Object { $null -ne $_ })
    $aggregate = [ordered]@{
        reports = $reports.Count
        existing = 0
        missing = 0
        failedRequired = 0
        failedOptional = 0
        skipped = 0
        manual = 0
        whatif = 0
        serviceCheckedCount = 0
        serviceMismatchCount = 0
        serviceMissingCount = 0
        serviceNotRunCount = 0
    }

    foreach ($report in $reports) {
        if ([bool]$report.exists) {
            $aggregate.existing++
        } else {
            $aggregate.missing++
        }

        if ($null -eq $report.serviceSummary) {
            continue
        }

        $summary = $report.serviceSummary
        $aggregate.failedRequired += [int]$summary.failedRequiredCount
        $aggregate.failedOptional += [int]$summary.failedOptionalCount

        if ($null -ne $summary.statusCounts) {
            $aggregate.skipped += [int]$summary.statusCounts.skipped
            $aggregate.manual += [int]$summary.statusCounts.manual
            $aggregate.whatif += [int]$summary.statusCounts.whatif
        }

        if ($null -ne $summary.PSObject.Properties["serviceCheckedCount"]) {
            $aggregate.serviceCheckedCount += [int]$summary.serviceCheckedCount
        }
        if ($null -ne $summary.PSObject.Properties["serviceMismatchCount"]) {
            $aggregate.serviceMismatchCount += [int]$summary.serviceMismatchCount
        }
        if ($null -ne $summary.PSObject.Properties["serviceMissingCount"]) {
            $aggregate.serviceMissingCount += [int]$summary.serviceMissingCount
        }
        if ($null -ne $summary.PSObject.Properties["serviceNotRunCount"]) {
            $aggregate.serviceNotRunCount += [int]$summary.serviceNotRunCount
        }
    }

    [pscustomobject]$aggregate
}

function Get-KitJunctionReportReference {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowEmptyString()]
        [string]$StepName,

        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required,

        [string]$ReportType = "junction-state-verification"
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $exists = Test-Path -LiteralPath $Path
    $junctionSummary = $null
    $errorCode = $null

    if (-not $exists) {
        $errorCode = "report-missing"
    } else {
        try {
            $childReport = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($childReport.PSObject.Properties.Name -contains "junctionSummary") {
                $junctionSummary = Copy-KitPackageSummaryWithoutResults -PackageSummary $childReport.junctionSummary
            } else {
                $errorCode = "junction-summary-missing"
            }
        } catch {
            $errorCode = "report-parse-failed"
            if ($Required) {
                throw "Junction report parse failed: $Path - $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject][ordered]@{
        name = $Name
        stepName = $StepName
        reportType = $ReportType
        path = $Path
        required = [bool]$Required
        exists = [bool]$exists
        junctionSummary = $junctionSummary
        error = $errorCode
    }
}

function Get-KitJunctionReportAggregate {
    param(
        [AllowNull()]
        $JunctionReports = @()
    )

    $reports = @($JunctionReports | Where-Object { $null -ne $_ })
    $aggregate = [ordered]@{
        reports = $reports.Count
        existing = 0
        missing = 0
        failedRequired = 0
        failedOptional = 0
        skipped = 0
        manual = 0
        whatif = 0
        junctionCheckedCount = 0
        junctionMissingCount = 0
        junctionNotJunctionCount = 0
        junctionTargetMismatchCount = 0
        junctionNotRunCount = 0
    }

    foreach ($report in $reports) {
        if ([bool]$report.exists) {
            $aggregate.existing++
        } else {
            $aggregate.missing++
        }

        if ($null -eq $report.junctionSummary) {
            continue
        }

        $summary = $report.junctionSummary
        $aggregate.failedRequired += [int]$summary.failedRequiredCount
        $aggregate.failedOptional += [int]$summary.failedOptionalCount

        if ($null -ne $summary.statusCounts) {
            $aggregate.skipped += [int]$summary.statusCounts.skipped
            $aggregate.manual += [int]$summary.statusCounts.manual
            $aggregate.whatif += [int]$summary.statusCounts.whatif
        }

        if ($null -ne $summary.PSObject.Properties["junctionCheckedCount"]) {
            $aggregate.junctionCheckedCount += [int]$summary.junctionCheckedCount
        }
        if ($null -ne $summary.PSObject.Properties["junctionMissingCount"]) {
            $aggregate.junctionMissingCount += [int]$summary.junctionMissingCount
        }
        if ($null -ne $summary.PSObject.Properties["junctionNotJunctionCount"]) {
            $aggregate.junctionNotJunctionCount += [int]$summary.junctionNotJunctionCount
        }
        if ($null -ne $summary.PSObject.Properties["junctionTargetMismatchCount"]) {
            $aggregate.junctionTargetMismatchCount += [int]$summary.junctionTargetMismatchCount
        }
        if ($null -ne $summary.PSObject.Properties["junctionNotRunCount"]) {
            $aggregate.junctionNotRunCount += [int]$summary.junctionNotRunCount
        }
    }

    [pscustomobject]$aggregate
}

function Get-KitDefenderReportReference {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowEmptyString()]
        [string]$StepName,

        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required,

        [string]$ReportType = "defender-state-verification"
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $exists = Test-Path -LiteralPath $Path
    $defenderSummary = $null
    $errorCode = $null

    if (-not $exists) {
        $errorCode = "report-missing"
    } else {
        try {
            $childReport = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($childReport.PSObject.Properties.Name -contains "defenderSummary") {
                $defenderSummary = Copy-KitPackageSummaryWithoutResults -PackageSummary $childReport.defenderSummary
            } else {
                $errorCode = "defender-summary-missing"
            }
        } catch {
            $errorCode = "report-parse-failed"
            if ($Required) {
                throw "Defender report parse failed: $Path - $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject][ordered]@{
        name = $Name
        stepName = $StepName
        reportType = $ReportType
        path = $Path
        required = [bool]$Required
        exists = [bool]$exists
        defenderSummary = $defenderSummary
        error = $errorCode
    }
}

function Get-KitDefenderReportAggregate {
    param(
        [AllowNull()]
        $DefenderReports = @()
    )

    $reports = @($DefenderReports | Where-Object { $null -ne $_ })
    $aggregate = [ordered]@{
        reports = $reports.Count
        existing = 0
        missing = 0
        failedRequired = 0
        failedOptional = 0
        skipped = 0
        manual = 0
        whatif = 0
        defenderCheckedCount = 0
        defenderMismatchCount = 0
        defenderSettingMissingCount = 0
        defenderQueryFailedCount = 0
        defenderNotRunCount = 0
    }

    foreach ($report in $reports) {
        if ([bool]$report.exists) {
            $aggregate.existing++
        } else {
            $aggregate.missing++
        }

        if ($null -eq $report.defenderSummary) {
            continue
        }

        $summary = $report.defenderSummary
        $aggregate.failedRequired += [int]$summary.failedRequiredCount
        $aggregate.failedOptional += [int]$summary.failedOptionalCount

        if ($null -ne $summary.statusCounts) {
            $aggregate.skipped += [int]$summary.statusCounts.skipped
            $aggregate.manual += [int]$summary.statusCounts.manual
            $aggregate.whatif += [int]$summary.statusCounts.whatif
        }

        if ($null -ne $summary.PSObject.Properties["defenderCheckedCount"]) {
            $aggregate.defenderCheckedCount += [int]$summary.defenderCheckedCount
        }
        if ($null -ne $summary.PSObject.Properties["defenderMismatchCount"]) {
            $aggregate.defenderMismatchCount += [int]$summary.defenderMismatchCount
        }
        if ($null -ne $summary.PSObject.Properties["defenderSettingMissingCount"]) {
            $aggregate.defenderSettingMissingCount += [int]$summary.defenderSettingMissingCount
        }
        if ($null -ne $summary.PSObject.Properties["defenderQueryFailedCount"]) {
            $aggregate.defenderQueryFailedCount += [int]$summary.defenderQueryFailedCount
        }
        if ($null -ne $summary.PSObject.Properties["defenderNotRunCount"]) {
            $aggregate.defenderNotRunCount += [int]$summary.defenderNotRunCount
        }
    }

    [pscustomobject]$aggregate
}

function Get-KitAppxReportReference {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [AllowEmptyString()]
        [string]$StepName,

        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required,

        [string]$ReportType = "appx-state-verification"
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $exists = Test-Path -LiteralPath $Path
    $appxSummary = $null
    $errorCode = $null

    if (-not $exists) {
        $errorCode = "report-missing"
    } else {
        try {
            $childReport = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($childReport.PSObject.Properties.Name -contains "appxSummary") {
                $appxSummary = Copy-KitPackageSummaryWithoutResults -PackageSummary $childReport.appxSummary
            } else {
                $errorCode = "appx-summary-missing"
            }
        } catch {
            $errorCode = "report-parse-failed"
            if ($Required) {
                throw "AppX report parse failed: $Path - $($_.Exception.Message)"
            }
        }
    }

    [pscustomobject][ordered]@{
        name = $Name
        stepName = $StepName
        reportType = $ReportType
        path = $Path
        required = [bool]$Required
        exists = [bool]$exists
        appxSummary = $appxSummary
        error = $errorCode
    }
}

function Get-KitAppxReportAggregate {
    param(
        [AllowNull()]
        $AppxReports = @()
    )

    $reports = @($AppxReports | Where-Object { $null -ne $_ })
    $aggregate = [ordered]@{
        reports = $reports.Count
        existing = 0
        missing = 0
        failedRequired = 0
        failedOptional = 0
        skipped = 0
        manual = 0
        whatif = 0
        appxCheckedCount = 0
        appxMismatchCount = 0
        appxQueryFailedCount = 0
        appxNotRunCount = 0
    }

    foreach ($report in $reports) {
        if ([bool]$report.exists) {
            $aggregate.existing++
        } else {
            $aggregate.missing++
        }

        if ($null -eq $report.appxSummary) {
            continue
        }

        $summary = $report.appxSummary
        $aggregate.failedRequired += [int]$summary.failedRequiredCount
        $aggregate.failedOptional += [int]$summary.failedOptionalCount

        if ($null -ne $summary.statusCounts) {
            $aggregate.skipped += [int]$summary.statusCounts.skipped
            $aggregate.manual += [int]$summary.statusCounts.manual
            $aggregate.whatif += [int]$summary.statusCounts.whatif
        }

        if ($null -ne $summary.PSObject.Properties["appxCheckedCount"]) {
            $aggregate.appxCheckedCount += [int]$summary.appxCheckedCount
        }
        if ($null -ne $summary.PSObject.Properties["appxMismatchCount"]) {
            $aggregate.appxMismatchCount += [int]$summary.appxMismatchCount
        }
        if ($null -ne $summary.PSObject.Properties["appxQueryFailedCount"]) {
            $aggregate.appxQueryFailedCount += [int]$summary.appxQueryFailedCount
        }
        if ($null -ne $summary.PSObject.Properties["appxNotRunCount"]) {
            $aggregate.appxNotRunCount += [int]$summary.appxNotRunCount
        }
    }

    [pscustomobject]$aggregate
}
