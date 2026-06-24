$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
. (Join-Path $RepoRoot "tests\pester\TestHelpers.ps1")
. (Join-Path $RepoRoot "scripts\common\Resolve-KitPath.ps1")

Describe "Resolve-KitPath" {
    BeforeEach {
        $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
        . (Join-Path $script:RepoRoot "tests\pester\TestHelpers.ps1")
        . (Join-Path $script:RepoRoot "scripts\common\Resolve-KitPath.ps1")
    }

    It "解析 PackageRoot、ToolRoot 和 DataRoot token" {
        $pathMap = @{
            PackageRoot = "\\nas\backup\packages"
            ToolRoot = "C:\tools"
            DataRoot = "D:\Data"
        }

        Assert-KitEqual (Resolve-KitPath -Path '${PackageRoot}\dev\vscode.zip' -PathMap $pathMap) "\\nas\backup\packages\dev\vscode.zip"
        Assert-KitEqual (Resolve-KitPath -Path '${ToolRoot}\vscode-portable' -PathMap $pathMap) "C:\tools\vscode-portable"
        Assert-KitEqual (Resolve-KitPath -Path '${DataRoot}\Projects' -PathMap $pathMap) "D:\Data\Projects"
    }

    It "支持嵌套 token 解析" {
        $pathMap = @{
            PackageRoot = "\\nas\backup\packages"
            ToolRoot = '${PackageRoot}\tools'
            DataRoot = "D:\Data"
        }

        Assert-KitEqual (Resolve-KitPath -Path '${ToolRoot}\git' -PathMap $pathMap) "\\nas\backup\packages\tools\git"
    }

    It "保留未知 token 的当前行为" {
        $pathMap = @{
            PackageRoot = "\\nas\backup\packages"
            ToolRoot = "C:\tools"
            DataRoot = "D:\Data"
        }

        Assert-KitEqual (Resolve-KitPath -Path '${UnknownRoot}\payload' -PathMap $pathMap) '${UnknownRoot}\payload'
    }

    It "普通路径直接透传" {
        $pathMap = @{
            PackageRoot = "\\nas\backup\packages"
            ToolRoot = "C:\tools"
            DataRoot = "D:\Data"
        }

        Assert-KitEqual (Resolve-KitPath -Path 'relative\path.txt' -PathMap $pathMap) 'relative\path.txt'
    }

    It "中文路径内容不会被解析过程破坏" {
        $pathMap = @{
            PackageRoot = "D:\安装包"
            ToolRoot = "C:\工具"
            DataRoot = "D:\资料"
        }

        Assert-KitEqual (Resolve-KitPath -Path '${PackageRoot}\输入法\配置.json' -PathMap $pathMap) "D:\安装包\输入法\配置.json"
    }

    It "从临时 paths manifest 读取 path map 时不访问真实 NAS" {
        $manifestPath = Join-Path $TestDrive "paths.json"
        @'
{
  "paths": {
    "PackageRoot": "X:\\offline-packages",
    "ToolRoot": "${PackageRoot}\\tools",
    "DataRoot": "D:\\Data"
  }
}
'@ | Set-Content -LiteralPath $manifestPath -Encoding UTF8

        $pathMap = Get-KitPathMap -ManifestPath $manifestPath

        Assert-KitEqual $pathMap["PackageRoot"] "X:\offline-packages"
        Assert-KitEqual $pathMap["ToolRoot"] "X:\offline-packages\tools"
        Assert-KitEqual $pathMap["DataRoot"] "D:\Data"
    }
}
