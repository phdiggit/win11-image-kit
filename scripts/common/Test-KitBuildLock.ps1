. "$PSScriptRoot\Get-KitFileHash.ps1"

function Get-KitBuildLockPolicyValue {
    param(
        [AllowNull()]
        $Policy,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Default
    )

    if ($null -ne $Policy -and $Policy.PSObject.Properties.Name -contains $Name) {
        $value = [string]$Policy.$Name
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return $Default
}

function New-KitBuildLockResult {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Category = "unknown",

        [Parameter(Mandatory)]
        [ValidateSet("passed", "manual", "failed")]
        [string]$Status,

        [AllowNull()]
        [string]$ExpectedHash,

        [AllowNull()]
        [string]$ActualHash,

        [bool]$Exists,

        [string]$Reason,

        [string[]]$Warnings = @(),

        [string[]]$Errors = @()
    )

    [pscustomobject]@{
        path = $Path.Replace("\", "/")
        category = $Category
        status = $Status
        expectedHash = $(if ([string]::IsNullOrWhiteSpace($ExpectedHash)) { $null } else { $ExpectedHash.ToLowerInvariant() })
        actualHash = $(if ([string]::IsNullOrWhiteSpace($ActualHash)) { $null } else { $ActualHash.ToLowerInvariant() })
        exists = [bool]$Exists
        reason = $Reason
        warnings = @($Warnings)
        errors = @($Errors)
    }
}

function Get-KitBuildLockWatchedFiles {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [string[]]$WatchGlobs
    )

    $watched = @{}
    foreach ($glob in @($WatchGlobs)) {
        if ([string]::IsNullOrWhiteSpace($glob)) {
            continue
        }

        $normalizedGlob = $glob.Replace("\", "/")
        $firstWildcard = $normalizedGlob.IndexOfAny([char[]]@("*", "?"))
        $baseRelative = ""
        if ($firstWildcard -gt 0) {
            $prefix = $normalizedGlob.Substring(0, $firstWildcard)
            $lastSlash = $prefix.LastIndexOf("/")
            if ($lastSlash -ge 0) {
                $baseRelative = $prefix.Substring(0, $lastSlash)
            }
        } elseif ($normalizedGlob.Contains("/")) {
            $baseRelative = Split-Path -Path $normalizedGlob -Parent
        }

        $basePath = if ([string]::IsNullOrWhiteSpace($baseRelative)) {
            $RepoRoot
        } else {
            Resolve-KitBuildLockRepoPath -RepoRoot $RepoRoot -Path $baseRelative
        }

        if (-not (Test-Path -LiteralPath $basePath)) {
            continue
        }

        $pattern = New-Object System.Management.Automation.WildcardPattern($normalizedGlob, [System.Management.Automation.WildcardOptions]::IgnoreCase)
        foreach ($file in Get-ChildItem -LiteralPath $basePath -Recurse -File) {
            $relative = ConvertTo-KitBuildLockRelativePath -RepoRoot $RepoRoot -Path $file.FullName
            if ($relative.StartsWith(".git/", [StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            if ($pattern.IsMatch($relative)) {
                $watched[$relative.ToLowerInvariant()] = $relative
            }
        }
    }

    return @($watched.Values | Sort-Object)
}

function Test-KitBuildLock {
    param(
        [Parameter(Mandatory)]
        $BuildLock,

        [string]$RepoRoot,

        [switch]$AuditOnly
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $results = @()
    $entryPathSet = @{}
    $unsupportedPolicy = Get-KitBuildLockPolicyValue -Policy $BuildLock.policy -Name "unsupportedAlgorithm" -Default "fail"
    $missingPolicy = Get-KitBuildLockPolicyValue -Policy $BuildLock.policy -Name "missingRequired" -Default "fail"
    $mismatchPolicy = Get-KitBuildLockPolicyValue -Policy $BuildLock.policy -Name "hashMismatch" -Default "fail"
    $untrackedPolicy = Get-KitBuildLockPolicyValue -Policy $BuildLock.policy -Name "untrackedWatchedFile" -Default "manual"

    $algorithm = [string]$BuildLock.algorithm
    $unsupportedAlgorithm = $algorithm -ne "SHA256"

    foreach ($entry in @($BuildLock.entries)) {
        $entryPath = ([string]$entry.path).Replace("\", "/")
        $entryPathSet[$entryPath.ToLowerInvariant()] = $true
        $required = [bool]$entry.required
        $expectedHash = [string]$entry.hash
        $warnings = @()
        $errors = @()
        $status = "passed"
        $actualHash = $null
        $exists = $false

        if ($unsupportedAlgorithm) {
            if ($unsupportedPolicy -eq "manual" -or $AuditOnly) {
                $status = "manual"
                $warnings += "unsupported algorithm: $algorithm"
            } elseif ($unsupportedPolicy -eq "pass") {
                $warnings += "unsupported algorithm marked pass by policy: $algorithm"
            } else {
                $status = "failed"
                $errors += "unsupported algorithm: $algorithm"
            }
        } else {
            $hashResult = Get-KitFileHash -Path $entryPath -RepoRoot $RepoRoot -Algorithm "SHA256"
            $exists = [bool]$hashResult.exists
            $actualHash = [string]$hashResult.hash

            if (-not $exists) {
                if ($required) {
                    if ($missingPolicy -eq "manual" -or $AuditOnly) {
                        $status = "manual"
                        $warnings += "required file missing: $entryPath"
                    } elseif ($missingPolicy -eq "pass") {
                        $warnings += "required file missing but policy is pass: $entryPath"
                    } else {
                        $status = "failed"
                        $errors += "required file missing: $entryPath"
                    }
                } else {
                    $status = "manual"
                    $warnings += "optional file missing: $entryPath"
                }
            } elseif ($actualHash.ToLowerInvariant() -ne $expectedHash.ToLowerInvariant()) {
                if ($mismatchPolicy -eq "manual" -or $AuditOnly) {
                    $status = "manual"
                    $warnings += "hash mismatch: $entryPath"
                } elseif ($mismatchPolicy -eq "pass") {
                    $warnings += "hash mismatch marked pass by policy: $entryPath"
                } else {
                    $status = "failed"
                    $errors += "hash mismatch: $entryPath"
                }
            }
        }

        $results += New-KitBuildLockResult `
            -Path $entryPath `
            -Category ([string]$entry.category) `
            -Status $status `
            -ExpectedHash $expectedHash `
            -ActualHash $actualHash `
            -Exists:$exists `
            -Reason ([string]$entry.reason) `
            -Warnings $warnings `
            -Errors $errors
    }

    foreach ($watchedPath in Get-KitBuildLockWatchedFiles -RepoRoot $RepoRoot -WatchGlobs @($BuildLock.watchGlobs)) {
        if ($entryPathSet.ContainsKey($watchedPath.ToLowerInvariant())) {
            continue
        }

        $status = "manual"
        $warnings = @("watched file is not listed in build lock entries: $watchedPath")
        $errors = @()
        if ($untrackedPolicy -eq "fail" -and -not $AuditOnly) {
            $status = "failed"
            $errors = @($warnings[0])
            $warnings = @()
        } elseif ($untrackedPolicy -eq "pass") {
            $status = "passed"
        }

        $results += New-KitBuildLockResult `
            -Path $watchedPath `
            -Category "untracked" `
            -Status $status `
            -ExpectedHash $null `
            -ActualHash $null `
            -Exists:$true `
            -Reason "Watched file is not listed in build lock entries." `
            -Warnings $warnings `
            -Errors $errors
    }

    return @($results)
}
