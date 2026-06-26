function Resolve-KitRepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
}

function Read-KitJsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Copy-KitJsonValue {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if (-not (Test-KitJsonObject -Value $Value) -and -not ($Value -is [System.Array])) {
        return $Value
    }

    return ($Value | ConvertTo-Json -Depth 64 | ConvertFrom-Json)
}

function Test-KitJsonObject {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [string] -or $Value -is [bool] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return $false
    }

    if ($Value -is [System.Array] -or $Value -is [System.Collections.IList]) {
        return $false
    }

    return ($Value.PSObject -and $Value.PSObject.Properties)
}

function Set-KitSourceEntry {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Sources,

        [AllowEmptyString()]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$LayerId
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $Sources[$Path] = $LayerId
}

function Merge-KitJsonObject {
    param(
        [AllowNull()]
        $Base,

        [AllowNull()]
        $Overlay,

        [Parameter(Mandatory)]
        [string]$LayerId,

        [AllowEmptyString()]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$Sources
    )

    if ($null -eq $Overlay) {
        Set-KitSourceEntry -Sources $Sources -Path $Path -LayerId $LayerId
        return $null
    }

    if (-not (Test-KitJsonObject -Value $Overlay)) {
        Set-KitSourceEntry -Sources $Sources -Path $Path -LayerId $LayerId
        return Copy-KitJsonValue -Value $Overlay
    }

    $result = if (Test-KitJsonObject -Value $Base) {
        Copy-KitJsonValue -Value $Base
    } else {
        [pscustomobject]@{}
    }

    foreach ($property in $Overlay.PSObject.Properties) {
        $childPath = if ([string]::IsNullOrWhiteSpace($Path)) { $property.Name } else { "$Path.$($property.Name)" }
        if ($null -eq $property.Value) {
            if ($result.PSObject.Properties[$property.Name]) {
                $result.PSObject.Properties.Remove($property.Name)
            }
            Set-KitSourceEntry -Sources $Sources -Path $childPath -LayerId $LayerId
            continue
        }

        $existing = $null
        if ($result.PSObject.Properties[$property.Name]) {
            $existing = $result.PSObject.Properties[$property.Name].Value
        }

        $merged = Merge-KitJsonObject -Base $existing -Overlay $property.Value -LayerId $LayerId -Path $childPath -Sources $Sources
        if ($result.PSObject.Properties[$property.Name]) {
            $result.PSObject.Properties[$property.Name].Value = $merged
        } else {
            Add-Member -InputObject $result -NotePropertyName $property.Name -NotePropertyValue $merged
        }
    }

    return $result
}

function ConvertTo-KitPathMap {
    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    $map = @{}
    if ($null -eq $Configuration.paths) {
        return $map
    }

    foreach ($property in $Configuration.paths.PSObject.Properties) {
        $map[$property.Name] = [string]$property.Value
    }

    foreach ($key in @($map.Keys)) {
        $map[$key] = Resolve-KitPath -Path $map[$key] -PathMap $map
    }

    return $map
}

function Resolve-KitEffectiveConfiguration {
    param(
        [string]$ConfigLayersPath = "manifests/config-layers.json",

        [string]$StackName = "default",

        [switch]$IncludeLocal,

        [string]$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    )

    $resolvedManifestPath = Resolve-KitRepoPath -RepoRoot $RepoRoot -Path $ConfigLayersPath
    $manifest = Read-KitJsonFile -Path $resolvedManifestPath
    $stack = @($manifest.stacks | Where-Object { $_.name -eq $StackName })[0]
    if ($null -eq $stack) {
        throw "配置层级 stack 不存在：$StackName"
    }

    $layerIndex = @{}
    foreach ($layer in @($manifest.layers)) {
        $layerIndex[[string]$layer.id] = $layer
    }

    $layerIds = @($stack.layers)
    if ($IncludeLocal -and -not [string]::IsNullOrWhiteSpace([string]$manifest.localOverrideLayer)) {
        $layerIds += [string]$manifest.localOverrideLayer
    }

    $effective = [pscustomobject]@{}
    $sources = @{}
    $appliedLayers = @()
    $warnings = @()

    foreach ($layerId in $layerIds) {
        if (-not $layerIndex.ContainsKey([string]$layerId)) {
            throw "配置层级引用未知 layer：$layerId"
        }

        $layer = $layerIndex[[string]$layerId]
        $layerPath = Resolve-KitRepoPath -RepoRoot $RepoRoot -Path ([string]$layer.path)
        $exists = Test-Path -LiteralPath $layerPath
        if (-not $exists) {
            if ($layer.required) {
                throw "必需配置层不存在：$($layer.path)"
            }

            $warnings += "可选配置层不存在，已跳过：$($layer.path)"
            continue
        }

        $fragment = Read-KitJsonFile -Path $layerPath
        $effective = Merge-KitJsonObject -Base $effective -Overlay $fragment -LayerId ([string]$layer.id) -Path "" -Sources $sources
        $appliedLayers += [pscustomobject]@{
            id = [string]$layer.id
            kind = [string]$layer.kind
            path = [string]$layer.path
            tracked = [bool]$layer.tracked
        }
    }

    if ($effective.PSObject.Properties["`$schema"]) {
        $effective.PSObject.Properties.Remove("`$schema")
    }

    if ($effective.PSObject.Properties["layerId"]) {
        $effective.PSObject.Properties.Remove("layerId")
    }

    if ($effective.PSObject.Properties["notes"]) {
        $effective.PSObject.Properties.Remove("notes")
    }

    $pathMap = ConvertTo-KitPathMap -Configuration $effective
    $pathSources = @()
    foreach ($key in @($pathMap.Keys | Sort-Object)) {
        $sourcePath = "paths.$key"
        $pathSources += [pscustomobject]@{
            key = [string]$key
            value = [string]$pathMap[$key]
            sourceLayer = [string]$sources[$sourcePath]
        }
    }

    return [pscustomobject]@{
        reportType = "effective-configuration"
        stackName = $StackName
        includeLocal = [bool]$IncludeLocal
        mergePolicy = $manifest.mergePolicy
        appliedLayers = $appliedLayers
        configuration = $effective
        pathSources = $pathSources
        warnings = $warnings
        safety = $manifest.safety
    }
}
