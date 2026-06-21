function Resolve-KitOutputPath {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [hashtable]$PathMap,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $resolved = if ($null -ne $PathMap) {
        Resolve-KitPath -Path $Path -PathMap $PathMap
    } else {
        [Environment]::ExpandEnvironmentVariables($Path)
    }

    if ([IO.Path]::IsPathRooted($resolved)) {
        return $resolved
    }

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        return $resolved
    }

    return Join-Path -Path $RepoRoot -ChildPath $resolved
}
