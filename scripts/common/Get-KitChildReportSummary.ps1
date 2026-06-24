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
