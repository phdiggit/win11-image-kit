function Resolve-KitCapabilityRepoPath {
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

function Get-KitCapabilityRegistry {
    param(
        [string]$Path = "manifests/capability-registry.json",
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $resolvedPath = Resolve-KitCapabilityRepoPath -RepoRoot $RepoRoot -Path $Path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "capability registry not found: $Path"
    }

    try {
        $registry = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "capability registry JSON parse failed: $Path - $($_.Exception.Message)"
    }

    $ids = @{}
    foreach ($capability in @($registry.capabilities)) {
        $id = [string]$capability.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            throw "capability registry contains an empty capability id"
        }

        if ($ids.ContainsKey($id)) {
            throw "duplicate capability id: $id"
        }

        $ids[$id] = $true
    }

    [pscustomobject]@{
        registryVersion = [int]$registry.registryVersion
        defaultValidationMode = [string]$registry.defaultValidationMode
        capabilities = @($registry.capabilities)
    }
}
