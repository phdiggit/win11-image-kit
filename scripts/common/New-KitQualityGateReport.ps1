#Requires -Version 5.1

function Get-KitQualityGatePolicyValue {
    param(
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [AllowNull()]
        $DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }

    if ($null -ne $InputObject.PSObject -and $null -ne $InputObject.PSObject.Properties[$Name]) {
        return $InputObject.PSObject.Properties[$Name].Value
    }

    return $DefaultValue
}

function Resolve-KitQualityGateRepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
}

function Test-KitQualityGateWorkflowPolicy {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $workflowPath = Resolve-KitQualityGateRepoPath -RepoRoot $RepoRoot -Path ".github/workflows/ci.yml"
    if (-not (Test-Path -LiteralPath $workflowPath)) {
        return @("workflow missing: .github/workflows/ci.yml")
    }

    $workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
    $errors = @()
    foreach ($pattern in @(
        "if:\s*github\.event_name == 'pull_request'",
        "if:\s*github\.event_name != 'pull_request'",
        "Run fast Pester tests with Windows PowerShell"
    )) {
        if ($workflow -notmatch $pattern) {
            $errors += "workflow policy missing pattern: $pattern"
        }
    }

    foreach ($pattern in @(
        "Invoke-GoldenImageBuild",
        "\bdism(\.exe)?\b",
        "\bsysprep(\.exe)?\b",
        "winget\s+(install|uninstall|upgrade)",
        "choco\s+(install|uninstall|upgrade)",
        "msiexec\s+/(i|x)",
        "\bInstall-Package\b",
        "\bUninstall-Package\b",
        "\bSet-Service\b",
        "\bStart-Service\b",
        "\bStop-Service\b",
        "sc\.exe\s+(config|delete|stop|start)",
        "Invoke-WebRequest",
        "Invoke-RestMethod",
        "Start-BitsTransfer",
        "\breg\s+(load|unload|add|delete)",
        "\bSet-ItemProperty\b",
        "\bNew-ItemProperty\b",
        "Install-Module"
    )) {
        if ($workflow -match $pattern) {
            $errors += "workflow contains forbidden command pattern: $pattern"
        }
    }

    return @($errors)
}

function New-KitQualityGateResult {
    param(
        [Parameter(Mandatory)]
        $Gate,

        [Parameter(Mandatory)]
        [ValidateSet("passed", "manual", "failed", "skipped")]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason,

        [string[]]$Warnings = @(),

        [string[]]$Errors = @()
    )

    [pscustomobject][ordered]@{
        id = [string](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "id" -DefaultValue "")
        displayName = [string](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "displayName" -DefaultValue "")
        layer = [string](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "layer" -DefaultValue "")
        trigger = [string](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "trigger" -DefaultValue "")
        mode = [string](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "mode" -DefaultValue "")
        required = [bool](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "required" -DefaultValue $false)
        blocking = [bool](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "blocking" -DefaultValue $false)
        entrypoint = [string](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "entrypoint" -DefaultValue "")
        evidence = [string](Get-KitQualityGatePolicyValue -InputObject $Gate -Name "evidence" -DefaultValue "")
        status = $Status
        reason = $Reason
        warnings = @($Warnings)
        errors = @($Errors)
    }
}

function New-KitQualityGateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $QualityGateManifest,

        [string]$RepoRoot,

        [switch]$WhatIf
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $results = @()
    $seen = @{}
    foreach ($gate in @($QualityGateManifest.gates)) {
        $id = [string](Get-KitQualityGatePolicyValue -InputObject $gate -Name "id" -DefaultValue "")
        $entrypoint = [string](Get-KitQualityGatePolicyValue -InputObject $gate -Name "entrypoint" -DefaultValue "")
        $mode = [string](Get-KitQualityGatePolicyValue -InputObject $gate -Name "mode" -DefaultValue "")
        $evidence = [string](Get-KitQualityGatePolicyValue -InputObject $gate -Name "evidence" -DefaultValue "")
        $blocking = [bool](Get-KitQualityGatePolicyValue -InputObject $gate -Name "blocking" -DefaultValue $false)
        $errors = @()
        $warnings = @()
        $status = "passed"
        $reason = "quality gate is present and static/report-only"

        if ([string]::IsNullOrWhiteSpace($id)) {
            $errors += "gate id is required"
        } elseif ($seen.ContainsKey($id.ToLowerInvariant())) {
            $errors += "duplicate gate id: $id"
        } else {
            $seen[$id.ToLowerInvariant()] = $true
        }

        foreach ($name in @("displayName", "layer", "trigger", "mode", "entrypoint", "evidence", "notes")) {
            if ([string]::IsNullOrWhiteSpace([string](Get-KitQualityGatePolicyValue -InputObject $gate -Name $name -DefaultValue ""))) {
                $errors += "gate $id missing $name"
            }
        }

        if ($mode -eq "true-execution") {
            $errors += "true-execution gates must be split into a separate issue"
        }

        if (-not [string]::IsNullOrWhiteSpace($entrypoint)) {
            $resolved = Resolve-KitQualityGateRepoPath -RepoRoot $RepoRoot -Path $entrypoint
            if (-not (Test-Path -LiteralPath $resolved)) {
                $errors += "entrypoint missing: $entrypoint"
            }
        }

        if ($id -eq "ci-policy" -or $id -eq "safety-boundary") {
            $errors += @(Test-KitQualityGateWorkflowPolicy -RepoRoot $RepoRoot)
        }

        if ($evidence -eq "manual" -or -not $blocking) {
            $warnings += "gate is manual or non-blocking under current policy"
        }

        if ($errors.Count -gt 0) {
            $status = "failed"
            $reason = "quality gate policy failed"
        } elseif ($warnings.Count -gt 0) {
            $status = "manual"
            $reason = "quality gate requires review under current policy"
        }

        $results += New-KitQualityGateResult -Gate $gate -Status $status -Reason $reason -Warnings $warnings -Errors $errors
    }

    $failedCount = @($results | Where-Object { $_.status -eq "failed" }).Count
    $manualCount = @($results | Where-Object { $_.status -eq "manual" }).Count
    $passedCount = @($results | Where-Object { $_.status -eq "passed" }).Count
    $skippedCount = @($results | Where-Object { $_.status -eq "skipped" }).Count
    $status = "passed"
    if ($failedCount -gt 0) {
        $status = "failed"
    } elseif ($manualCount -gt 0) {
        $status = "manual"
    }

    [pscustomobject][ordered]@{
        reportType = "quality-gates"
        generatedAt = (Get-Date).ToString("s")
        status = $status
        summary = [pscustomobject][ordered]@{
            totalCount = @($results).Count
            passedCount = $passedCount
            manualCount = $manualCount
            failedCount = $failedCount
            skippedCount = $skippedCount
        }
        gates = @($results)
        safety = [pscustomobject][ordered]@{
            realBuild = $false
            realMutation = $false
            networkDownload = $false
            registryProfileHiveWrite = $false
        }
        whatIf = [bool]$WhatIf
    }
}
