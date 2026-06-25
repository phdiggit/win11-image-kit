. "$PSScriptRoot\Get-KitFileHash.ps1"

function Get-KitBuildLock {
    param(
        [string]$Path = "manifests/build-lock.json",

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $resolvedPath = Resolve-KitBuildLockRepoPath -RepoRoot $RepoRoot -Path $Path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "build lock manifest not found: $Path"
    }

    try {
        $lock = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "build lock JSON parse failed: $Path - $($_.Exception.Message)"
    }

    $entryPaths = @{}
    foreach ($entry in @($lock.entries)) {
        $entryPath = ([string]$entry.path).Replace("\", "/").ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($entryPath)) {
            throw "build lock contains an empty entry path"
        }

        if ($entryPaths.ContainsKey($entryPath)) {
            throw "duplicate build lock entry path: $($entry.path)"
        }

        $entryPaths[$entryPath] = $true
    }

    [pscustomobject]@{
        lockVersion = [int]$lock.lockVersion
        algorithm = [string]$lock.algorithm
        mode = [string]$lock.mode
        generatedBy = [string]$lock.generatedBy
        entries = @($lock.entries)
        watchGlobs = @($lock.watchGlobs)
        policy = $lock.policy
    }
}
