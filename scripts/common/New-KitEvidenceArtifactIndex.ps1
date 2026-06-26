#Requires -Version 5.1

function Get-KitEvidenceArtifactValue {
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

function Resolve-KitEvidenceArtifactRepoPath {
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

function New-KitEvidenceArtifactIndex {
    [CmdletBinding()]
    param(
        [string]$ArtifactIndexPath = "tests/fixtures/evidence-chain/sample-artifact-index.json",

        [Parameter(Mandatory)]
        [string]$RunId,

        [string]$UpstreamRunId,

        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
    }

    $resolvedPath = Resolve-KitEvidenceArtifactRepoPath -RepoRoot $RepoRoot -Path $ArtifactIndexPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return @()
    }

    $index = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $artifacts = @()
    foreach ($artifact in @($index.artifacts)) {
        $artifactRunId = [string](Get-KitEvidenceArtifactValue -InputObject $artifact -Name "runId" -DefaultValue $RunId)
        if ($artifactRunId -eq "kit-run-20260626T123456Z-a659a041") {
            $artifactRunId = $RunId
        }

        $artifactUpstreamRunId = [string](Get-KitEvidenceArtifactValue -InputObject $artifact -Name "upstreamRunId" -DefaultValue $UpstreamRunId)
        if ($artifactUpstreamRunId -eq "kit-run-20260626T123456Z-a659a041") {
            $artifactUpstreamRunId = $RunId
        }

        $entry = [ordered]@{
            kind = [string]$artifact.kind
            producerId = [string]$artifact.producerId
            stage = [string]$artifact.stage
            runId = $artifactRunId
            private = [bool]$artifact.private
            redacted = [bool]$artifact.redacted
        }

        foreach ($name in @("path", "logicalName", "sha256", "status")) {
            $value = Get-KitEvidenceArtifactValue -InputObject $artifact -Name $name -DefaultValue $null
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                $entry[$name] = [string]$value
            }
        }

        $sizeBytes = Get-KitEvidenceArtifactValue -InputObject $artifact -Name "sizeBytes" -DefaultValue $null
        if ($null -ne $sizeBytes) {
            $entry["sizeBytes"] = [int64]$sizeBytes
        }

        if (-not [string]::IsNullOrWhiteSpace($artifactUpstreamRunId)) {
            $entry["upstreamRunId"] = $artifactUpstreamRunId
        }

        $artifacts += [pscustomobject]$entry
    }

    return @($artifacts)
}
