. "$PSScriptRoot\Get-KitCapabilityRegistry.ps1"

function Test-KitCapabilityFileList {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        $Capability,

        [Parameter(Mandatory)]
        [string]$FieldName,

        [Parameter(Mandatory)]
        [string]$DisplayName
    )

    $paths = @($Capability.$FieldName | ForEach-Object { [string]$_ })
    $missing = @()
    foreach ($path in $paths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            $missing += "<empty>"
            continue
        }

        $resolvedPath = Resolve-KitCapabilityRepoPath -RepoRoot $RepoRoot -Path $path
        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            $missing += $path
        }
    }

    [pscustomobject]@{
        exists = ($missing.Count -eq 0)
        missing = @($missing)
        count = $paths.Count
        displayName = $DisplayName
    }
}

function Get-KitCapabilityOrphanManifests {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        $Registry
    )

    $referenced = @{}
    foreach ($capability in @($Registry.capabilities)) {
        $manifest = [string]$capability.manifest
        if (-not [string]::IsNullOrWhiteSpace($manifest)) {
            $referenced[$manifest.Replace("\", "/").ToLowerInvariant()] = $true
        }
    }

    $manifestRoot = Join-Path -Path $RepoRoot -ChildPath "manifests"
    $orphans = @()
    foreach ($file in Get-ChildItem -Path $manifestRoot -Filter *.json -File) {
        $relative = ("manifests/{0}" -f $file.Name).ToLowerInvariant()
        if ($relative -eq "manifests/capability-registry.json") {
            continue
        }

        if (-not $referenced.ContainsKey($relative)) {
            $orphans += "manifests/$($file.Name)"
        }
    }

    return @($orphans | Sort-Object)
}

function Test-KitCapabilityConsistency {
    param(
        [Parameter(Mandatory)]
        $Registry,

        [string]$RepoRoot,

        [switch]$Strict
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $allowedStatuses = @("planned", "implemented", "deprecated", "static-only")
    $results = @()

    foreach ($capability in @($Registry.capabilities)) {
        $errors = @()
        $warnings = @()
        $status = [string]$capability.status
        $context = [string]$capability.context
        $mutationLevel = [string]$capability.mutationLevel
        $notes = [string]$capability.notes

        $manifestPath = [string]$capability.manifest
        $schemaPath = [string]$capability.schema
        $manifestExists = -not [string]::IsNullOrWhiteSpace($manifestPath) -and (Test-Path -LiteralPath (Resolve-KitCapabilityRepoPath -RepoRoot $RepoRoot -Path $manifestPath))
        $schemaExists = -not [string]::IsNullOrWhiteSpace($schemaPath) -and (Test-Path -LiteralPath (Resolve-KitCapabilityRepoPath -RepoRoot $RepoRoot -Path $schemaPath))

        $entrypointCheck = Test-KitCapabilityFileList -RepoRoot $RepoRoot -Capability $capability -FieldName "entrypoints" -DisplayName "entrypoints"
        $validateCheck = Test-KitCapabilityFileList -RepoRoot $RepoRoot -Capability $capability -FieldName "validateEntrypoints" -DisplayName "validate entrypoints"
        $testsCheck = Test-KitCapabilityFileList -RepoRoot $RepoRoot -Capability $capability -FieldName "tests" -DisplayName "tests"
        $docsCheck = Test-KitCapabilityFileList -RepoRoot $RepoRoot -Capability $capability -FieldName "docs" -DisplayName "docs"

        if ($status -notin $allowedStatuses) {
            $errors += "unknown capability status: $status"
        }

        if ([string]$capability.issue -notmatch '^#[0-9]+$') {
            $errors += "issue must match #<number>: $($capability.issue)"
        }

        if (-not $manifestExists -and $status -ne "planned") {
            $errors += "manifest missing: $manifestPath"
        }

        $schemaMayBeStaticOnly = $status -eq "static-only" -and $notes -match "static-only|not applicable|no schema"
        if (-not $schemaExists -and $status -ne "planned" -and -not $schemaMayBeStaticOnly) {
            $errors += "schema missing: $schemaPath"
        }

        foreach ($check in @($entrypointCheck, $validateCheck, $testsCheck, $docsCheck)) {
            if (-not $check.exists) {
                $errors += "$($check.displayName) missing: $($check.missing -join ', ')"
            }
        }

        if ($status -eq "implemented") {
            if ($testsCheck.count -lt 1) {
                $errors += "implemented capability must list at least one test"
            }

            if ($docsCheck.count -lt 1) {
                $errors += "implemented capability must list at least one doc"
            }
        }

        if ($status -eq "planned") {
            $warnings += "planned capability may lack implementation until a later stage"
        }

        if ($mutationLevel -eq "unknown" -and $status -eq "implemented") {
            $errors += "implemented capability cannot use mutationLevel=unknown"
        }

        if ($mutationLevel -eq "real-mutation") {
            $warnings += "real-mutation capability requires manual review and cannot pass PR Fast CI by default"
        }

        if ($context -eq "mixed") {
            $warnings += "mixed context capability requires manual review"
        }

        $resultStatus = "passed"
        if ($errors.Count -gt 0) {
            $resultStatus = "failed"
        } elseif ($warnings.Count -gt 0 -or $mutationLevel -eq "real-mutation" -or $context -eq "mixed") {
            $resultStatus = "manual"
        }

        $results += [pscustomobject]@{
            id = [string]$capability.id
            status = $resultStatus
            issue = [string]$capability.issue
            context = $context
            mutationLevel = $mutationLevel
            checks = [pscustomobject]@{
                manifestExists = [bool]$manifestExists
                schemaExists = [bool]$schemaExists
                entrypointsExist = [bool]$entrypointCheck.exists
                validateEntrypointsExist = [bool]$validateCheck.exists
                testsExist = [bool]$testsCheck.exists
                docsExist = [bool]$docsCheck.exists
                hasAtLeastOneTest = [bool]($testsCheck.count -gt 0)
                hasAtLeastOneDoc = [bool]($docsCheck.count -gt 0)
                mutationBoundaryKnown = [bool]($mutationLevel -ne "unknown")
            }
            warnings = @($warnings)
            errors = @($errors)
        }
    }

    $orphanManifests = @(Get-KitCapabilityOrphanManifests -RepoRoot $RepoRoot -Registry $Registry)
    if ($Strict -and $orphanManifests.Count -gt 0) {
        $results += [pscustomobject]@{
            id = "orphan-manifest-check"
            status = "failed"
            issue = "#11"
            context = "none"
            mutationLevel = "audit-only"
            checks = [pscustomobject]@{
                manifestExists = $true
                schemaExists = $true
                entrypointsExist = $true
                validateEntrypointsExist = $true
                testsExist = $true
                docsExist = $true
                hasAtLeastOneTest = $true
                hasAtLeastOneDoc = $true
                mutationBoundaryKnown = $true
            }
            warnings = @()
            errors = @("orphan manifests: $($orphanManifests -join ', ')")
        }
    }

    return @($results)
}
