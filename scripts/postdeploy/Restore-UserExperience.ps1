#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [string]$PathsManifestPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Invoke-KitStep.ps1"

$repoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Set-KitRegistryDword {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [int]$Value
    )

    $target = "{0}\{1}" -f $Path, $Name
    if ($PSCmdlet.ShouldProcess($target, "设置 DWORD 值为 $Value")) {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
        Write-KitLog "已设置资源管理器选项：$target = $Value" "OK"
    }
}

function Copy-KitConfigFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-KitLog "$Description 不存在，跳过：$Source" "WARN"
        return
    }

    if ($PSCmdlet.ShouldProcess($Destination, "复制 $Description")) {
        $destinationDirectory = Split-Path -Path $Destination -Parent
        if (-not (Test-Path -LiteralPath $destinationDirectory)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $Source -Destination $Destination -Force
        Write-KitLog "$Description 已复制：$Destination" "OK"
    }
}

function Import-KitDefaultAppAssociations {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$AssociationFile
    )

    if (-not (Test-Path -LiteralPath $AssociationFile)) {
        Write-KitLog "默认应用关联文件不存在，跳过：$AssociationFile" "WARN"
        return
    }

    if ($PSCmdlet.ShouldProcess($AssociationFile, "导入默认应用关联")) {
        Write-KitLog "导入默认应用关联：$AssociationFile"
        $argument = "/Import-DefaultAppAssociations:$AssociationFile"
        $output = & dism.exe /Online $argument 2>&1
        $exitCode = $LASTEXITCODE

        foreach ($line in @($output)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                Write-KitLog ([string]$line)
            }
        }

        if ($exitCode -ne 0) {
            throw "默认应用关联导入失败，exit code: $exitCode"
        }

        Write-KitLog "默认应用关联导入完成" "OK"
    }
}

Write-KitLog "开始恢复用户体验配置"

$ScopeManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $ScopeManifestPath
$scopeConfig = Get-Content -LiteralPath $ScopeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $PathsManifestPath) {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $scopeConfig.pathsManifest
} else {
    $PathsManifestPath = Resolve-KitRepoPath -RepoRoot $repoRoot -Path $PathsManifestPath
}

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath

if ($scopeConfig.system.defaultApps.enabled) {
    $associationFile = Resolve-KitPath -Path $scopeConfig.system.defaultApps.associationFile -PathMap $pathMap
    Import-KitDefaultAppAssociations -AssociationFile $associationFile -WhatIf:$WhatIfPreference
} else {
    Write-KitLog "默认应用关联已停用，跳过"
}

if ($scopeConfig.system.explorerOptions.enabled) {
    $advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $hideFileExt = if ($scopeConfig.system.explorerOptions.showFileExtensions) { 0 } else { 1 }
    $hidden = if ($scopeConfig.system.explorerOptions.showHiddenFiles) { 1 } else { 2 }

    Set-KitRegistryDword -Path $advancedPath -Name "HideFileExt" -Value $hideFileExt -WhatIf:$WhatIfPreference
    Set-KitRegistryDword -Path $advancedPath -Name "Hidden" -Value $hidden -WhatIf:$WhatIfPreference
} else {
    Write-KitLog "资源管理器选项已停用，跳过"
}

if ($scopeConfig.system.startMenu.enabled) {
    $startMenuConfigRoot = Resolve-KitPath -Path $scopeConfig.system.startMenu.config -PathMap $pathMap
    $layoutFile = Join-Path -Path $startMenuConfigRoot -ChildPath "LayoutModification.json"
    $defaultProfileLayout = "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.json"
    Copy-KitConfigFile `
        -Source $layoutFile `
        -Destination $defaultProfileLayout `
        -Description "开始菜单默认布局" `
        -WhatIf:$WhatIfPreference
} else {
    Write-KitLog "开始菜单配置已停用，跳过"
}

Write-KitLog "用户体验配置恢复完成" "OK"
