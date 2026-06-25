function Resolve-KitBuildLockRepoPath {
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

function ConvertTo-KitBuildLockRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $fullPath = [IO.Path]::GetFullPath($Path)
    $rootWithSlash = $fullRoot + [IO.Path]::DirectorySeparatorChar

    if ($fullPath.StartsWith($rootWithSlash, [StringComparison]::OrdinalIgnoreCase)) {
        $rootUri = New-Object System.Uri($rootWithSlash)
        $pathUri = New-Object System.Uri($fullPath)
        return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()).Replace("\", "/")
    }

    return $fullPath.Replace("\", "/")
}

function Get-KitFileHash {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$RepoRoot,

        [ValidateSet("SHA256")]
        [string]$Algorithm = "SHA256"
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $resolvedPath = Resolve-KitBuildLockRepoPath -RepoRoot $RepoRoot -Path $Path
    $relativePath = ConvertTo-KitBuildLockRelativePath -RepoRoot $RepoRoot -Path $resolvedPath

    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return [pscustomobject]@{
            path = $relativePath
            algorithm = $Algorithm
            hash = $null
            exists = $false
            length = 0
        }
    }

    if ((Get-Item -LiteralPath $resolvedPath).PSIsContainer) {
        throw "build lock hash target is a directory: $relativePath"
    }

    $stream = $null
    $sha = $null
    try {
        $stream = [IO.File]::Open($resolvedPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash($stream)
        $hash = ([BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
    } finally {
        if ($null -ne $sha) {
            $sha.Dispose()
        }
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }

    $file = Get-Item -LiteralPath $resolvedPath
    [pscustomobject]@{
        path = $relativePath
        algorithm = $Algorithm
        hash = $hash
        exists = $true
        length = [int64]$file.Length
    }
}
