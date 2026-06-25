Describe "Context scope plan report" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\New-KitContextPlan.ps1")
        $script:Scope = Get-Content -LiteralPath (Join-Path $script:RepoRoot "manifests\context-scope.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    It "produces a context-scope-plan report with complete summary counts" {
        $plan = New-KitContextPlan -Targets $script:Scope.targets -ScopeConfig $script:Scope -WhatIf

        Assert-KitEqual $plan.reportType "context-scope-plan"
        Assert-KitEqual $plan.summary.total 5
        Assert-KitEqual $plan.summary.machineCount 1
        Assert-KitEqual $plan.summary.defaultUserCount 2
        Assert-KitEqual $plan.summary.currentUserCount 2
        Assert-KitEqual $plan.summary.manualCount 4
        Assert-KitEqual $plan.summary.blockedCount 0
        Assert-KitEqual $plan.status "manual"
        Assert-KitEqual @($plan.items).Count 5
    }

    It "keeps blocked and manual items in the report" {
        $targets = @(
            [pscustomobject]@{ id = "manual"; context = "current-user"; targetType = "registry"; root = "HKCU"; phase = "interactive"; mutationPolicy = "manual"; reason = "test" },
            [pscustomobject]@{ id = "blocked"; context = "machine"; targetType = "registry"; root = "HKCU"; phase = "build"; mutationPolicy = "planned"; reason = "test" }
        )

        $plan = New-KitContextPlan -Targets $targets -ScopeConfig $script:Scope -WhatIf

        Assert-KitEqual $plan.status "failed"
        Assert-KitEqual @($plan.items | Where-Object { $_.id -eq "manual" }).Count 1
        Assert-KitEqual @($plan.items | Where-Object { $_.id -eq "blocked" }).Count 1
    }

    It "serializes report JSON and writes an explicit temp report path" {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("win11-context-report-{0}" -f ([guid]::NewGuid().ToString("N")))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $reportPath = Join-Path $tempRoot "context-scope-plan.json"
        try {
            & (Join-Path $script:RepoRoot "scripts\validate\Test-ContextScope.ps1") -WhatIf -ReportPath $reportPath | Out-Null
            $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json

            Assert-KitEqual $report.reportType "context-scope-plan"
            Assert-KitEqual $report.whatIf $true
            Assert-KitEqual @($report.items).Count 5
        } finally {
            if ([IO.Directory]::Exists($tempRoot)) {
                [IO.Directory]::Delete($tempRoot, $true)
            }
        }
    }
}
