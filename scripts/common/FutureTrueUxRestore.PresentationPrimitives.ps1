#Requires -Version 5.1

function Get-FutureTrueUxRestorePresentationRepoRoot {
    param(
        [Parameter(Mandatory)]
        [string]$PresentationScriptRoot
    )

    (Resolve-Path -LiteralPath (Join-Path $PresentationScriptRoot "..\..")).Path
}

function Resolve-FutureTrueUxRestorePresentationPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }

    (Resolve-Path -LiteralPath (Join-Path $RepoRoot $Path)).Path
}

function Read-FutureTrueUxRestorePresentationJson {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-FutureTrueUxRestorePresentationPath -RepoRoot $RepoRoot -Path $Path
    Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-FutureTrueUxRestorePresentationHeader {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host $Title
}

function Write-FutureTrueUxRestorePresentationLine {
    param(
        [Parameter(Mandatory)]
        [string]$Label,

        [AllowNull()]
        $Value
    )

    Write-Host ("{0}: {1}" -f $Label, $Value)
}

function Write-FutureTrueUxRestorePresentationList {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [AllowNull()]
        $Items,

        [Parameter(Mandatory)]
        [scriptblock]$FormatItem
    )

    Write-Host $Title
    foreach ($item in @($Items)) {
        Write-Host ("- {0}" -f (& $FormatItem $item))
    }
}

function Write-FutureTrueUxRestorePresentationObjectProperties {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [AllowNull()]
        $InputObject
    )

    Write-Host $Title
    if ($null -eq $InputObject) {
        return
    }

    foreach ($property in @($InputObject.PSObject.Properties)) {
        Write-Host ("- {0}: {1}" -f $property.Name, $property.Value)
    }
}

function Write-FutureTrueUxRestorePresentationReportJson {
    param(
        [Parameter(Mandatory)]
        $ReportObject,

        [int]$Depth = 12
    )

    $ReportObject | ConvertTo-Json -Depth $Depth
}
