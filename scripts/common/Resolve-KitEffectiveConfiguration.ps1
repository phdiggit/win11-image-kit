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

function ConvertTo-KitHashtable {
    param(
        [AllowNull()]
        $InputObject
    )

    $result = @{}
    if ($null -eq $InputObject) {
        return $result
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            $result[[string]$key] = $InputObject[$key]
        }
        return $result
    }

    if ($InputObject.PSObject -and $InputObject.PSObject.Properties) {
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[[string]$property.Name] = $property.Value
        }
    }

    return $result
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

function New-KitPathOverrideFragment {
    param(
        [AllowNull()]
        [hashtable]$PathOverride
    )

    $paths = [pscustomobject]@{}
    foreach ($key in @($PathOverride.Keys | Sort-Object)) {
        Add-Member -InputObject $paths -NotePropertyName ([string]$key) -NotePropertyValue ([string]$PathOverride[$key])
    }

    return [pscustomobject]@{
        layerId = "cli-explicit"
        paths = $paths
    }
}

function Get-KitConfigurationStackNames {
    param(
        [string]$ConfigLayersPath = "manifests/config-layers.json",

        [string]$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    )

    $resolvedManifestPath = Resolve-KitRepoPath -RepoRoot $RepoRoot -Path $ConfigLayersPath
    $manifest = Read-KitJsonFile -Path $resolvedManifestPath
    return @($manifest.stacks | ForEach-Object { [string]$_.name })
}

function Resolve-KitEffectiveConfiguration {
    param(
        [string]$ConfigLayersPath = "manifests/config-layers.json",

        [string]$StackName = "default",

        [switch]$IncludeLocal,

        [hashtable]$PathOverride,

        [switch]$RedactLocalValues,

        [string]$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    )

    $resolvedManifestPath = Resolve-KitRepoPath -RepoRoot $RepoRoot -Path $ConfigLayersPath
    $manifest = Read-KitJsonFile -Path $resolvedManifestPath
    $stack = @($manifest.stacks | Where-Object { $_.name -eq $StackName })[0]
    if ($null -eq $stack) {
        throw "Configuration stack not found: $StackName"
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
            throw "Configuration stack references unknown layer: $layerId"
        }

        $layer = $layerIndex[[string]$layerId]
        $layerPath = Resolve-KitRepoPath -RepoRoot $RepoRoot -Path ([string]$layer.path)
        $exists = Test-Path -LiteralPath $layerPath
        if (-not $exists) {
            if ($layer.required) {
                throw "Required configuration layer is missing: $($layer.path)"
            }

            $warnings += "Optional configuration layer is missing and was skipped: $($layer.path)"
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

    $overrideMap = ConvertTo-KitHashtable -InputObject $PathOverride
    if ($overrideMap.Count -gt 0) {
        $overrideFragment = New-KitPathOverrideFragment -PathOverride $overrideMap
        $effective = Merge-KitJsonObject -Base $effective -Overlay $overrideFragment -LayerId "cli-explicit" -Path "" -Sources $sources
        $appliedLayers += [pscustomobject]@{
            id = "cli-explicit"
            kind = "cli"
            path = "<command-line>"
            tracked = $false
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
            redactedValue = $(if ($RedactLocalValues -and [string]$sources[$sourcePath] -eq "local-private") { "<redacted>" } else { [string]$pathMap[$key] })
            sourceLayer = [string]$sources[$sourcePath]
        }
    }

    return [pscustomobject]@{
        reportType = "effective-configuration"
        stackName = $StackName
        includeLocal = [bool]$IncludeLocal
        redactedLocalValues = [bool]$RedactLocalValues
        mergePolicy = $manifest.mergePolicy
        appliedLayers = $appliedLayers
        configuration = $effective
        pathSources = $pathSources
        warnings = $warnings
        safety = $manifest.safety
    }
}
