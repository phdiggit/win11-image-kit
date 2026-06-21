[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PathsManifestPath = "manifests/paths.json"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

$pathMap = Get-KitPathMap -ManifestPath $PathsManifestPath
$codePath = Resolve-KitPath -Path '${ToolRoot}\vscode-portable\Code.exe' -PathMap $pathMap
$directoryCommand = '"{0}" "%V"' -f $codePath
$fileCommand = '"{0}" "%1"' -f $codePath

Write-KitLog "应用系统级配置"

if ($PSCmdlet.ShouldProcess("HKCR\Directory\shell\VSCode", "添加 VSCode 目录右键菜单")) {
    reg.exe add "HKCR\Directory\shell\VSCode" /ve /d "通过 Code 打开" /f | Out-Null
    reg.exe add "HKCR\Directory\shell\VSCode" /v Icon /d $codePath /f | Out-Null
    reg.exe add "HKCR\Directory\shell\VSCode\command" /ve /d $directoryCommand /f | Out-Null
}

if ($PSCmdlet.ShouldProcess("HKCR\*\shell\VSCode", "添加 VSCode 文件右键菜单")) {
    reg.exe add "HKCR\*\shell\VSCode" /ve /d "通过 Code 打开" /f | Out-Null
    reg.exe add "HKCR\*\shell\VSCode" /v Icon /d $codePath /f | Out-Null
    reg.exe add "HKCR\*\shell\VSCode\command" /ve /d $fileCommand /f | Out-Null
}

Write-KitLog "系统级配置完成" "OK"
