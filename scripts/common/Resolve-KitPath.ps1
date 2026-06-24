function Get-KitPathMap {
    param(
        [string]$ManifestPath = "$PSScriptRoot\..\..\manifests\paths.json"
    )

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "路径配置不存在：$ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $map = @{}

    foreach ($property in $manifest.paths.PSObject.Properties) {
        $map[$property.Name] = [string]$property.Value
    }

    foreach ($key in @($map.Keys)) {
        $map[$key] = Resolve-KitPath -Path $map[$key] -PathMap $map
    }

    return ,$map
}

function Resolve-KitPath {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $resolved = [Environment]::ExpandEnvironmentVariables($Path)
    for ($i = 0; $i -lt 10; $i++) {
        $changed = $false
        foreach ($key in $PathMap.Keys) {
            $token = '${' + $key + '}'
            if ($resolved.Contains($token)) {
                $resolved = $resolved.Replace($token, $PathMap[$key])
                $changed = $true
            }
        }

        if (-not $changed) {
            break
        }
    }

    return $resolved
}
