param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [switch]$CheckPackageFiles
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

$script:Failed = 0
$script:Warnings = 0
$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Write-CheckResult {
    param(
        [ValidateSet("OK", "WARN", "ERROR")]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $line = "[{0}] {1}" -f $Level, $Message
    switch ($Level) {
        "OK" {
            Write-Host $line -ForegroundColor Green
        }
        "WARN" {
            $script:Warnings++
            Write-Host $line -ForegroundColor Yellow
        }
        "ERROR" {
            $script:Failed++
            Write-Host $line -ForegroundColor Red
        }
    }
}

function Resolve-RepoPath {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path -Path $RepoRoot -ChildPath $Path
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-JsonFiles {
    $jsonFiles = Get-ChildItem -Path (Join-Path $RepoRoot "manifests"), (Join-Path $RepoRoot "schemas") -Recurse -Filter *.json
    foreach ($file in $jsonFiles) {
        try {
            Read-JsonFile -Path $file.FullName | Out-Null
            Write-CheckResult -Level OK -Message ("JSON 可解析：{0}" -f (Resolve-Path -LiteralPath $file.FullName -Relative))
        } catch {
            Write-CheckResult -Level ERROR -Message ("JSON 解析失败：{0} - {1}" -f $file.FullName, $_.Exception.Message)
        }
    }
}

function Test-PowerShellFiles {
    $scriptFiles = Get-ChildItem -Path (Join-Path $RepoRoot "scripts") -Recurse -Filter *.ps1
    foreach ($file in $scriptFiles) {
        try {
            [scriptblock]::Create((Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)) | Out-Null
            Write-CheckResult -Level OK -Message ("PowerShell 可解析：{0}" -f (Resolve-Path -LiteralPath $file.FullName -Relative))
        } catch {
            Write-CheckResult -Level ERROR -Message ("PowerShell 解析失败：{0} - {1}" -f $file.FullName, $_.Exception.Message)
        }
    }
}

function Test-ReferencedPath {
    param(
        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-RepoPath -Path $Path
    if (Test-Path -LiteralPath $resolvedPath) {
        Write-CheckResult -Level OK -Message ("引用存在：{0} -> {1}" -f $Description, $Path)
    } else {
        Write-CheckResult -Level ERROR -Message ("引用不存在：{0} -> {1}" -f $Description, $Path)
    }
}

function Get-ObjectStrings {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return
        }

        if ($InputObject -is [string]) {
            $InputObject
            return
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            foreach ($item in $InputObject) {
                Get-ObjectStrings -InputObject $item
            }
            return
        }

        if ($InputObject.PSObject -and $InputObject.PSObject.Properties) {
            foreach ($property in $InputObject.PSObject.Properties) {
                Get-ObjectStrings -InputObject $property.Value
            }
        }
    }
}

function Test-PathTokens {
    param(
        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    $manifestFiles = Get-ChildItem -Path (Join-Path $RepoRoot "manifests") -Recurse -Filter *.json
    foreach ($file in $manifestFiles) {
        $manifest = Read-JsonFile -Path $file.FullName
        $strings = @($manifest | Get-ObjectStrings | Where-Object { $_ -match '\$\{[^}]+\}' })
        foreach ($value in $strings) {
            $resolved = Resolve-KitPath -Path $value -PathMap $PathMap
            if ($resolved -match '\$\{[^}]+\}') {
                Write-CheckResult -Level ERROR -Message ("路径变量未解析：{0} -> {1}" -f (Resolve-Path -LiteralPath $file.FullName -Relative), $value)
            } else {
                Write-CheckResult -Level OK -Message ("路径变量可解析：{0}" -f $value)
            }
        }
    }
}

function Test-DisallowedPaths {
    $targets = @(
        @{
            Pattern = '\\\\192\.168\.1\.37\\images'
            Message = "发现旧 images 共享路径"
        },
        @{
            Pattern = '\\\\192\.168\.1\.37\\backups\\packages'
            Message = "发现旧 packages 共享路径"
        },
        @{
            Pattern = 'C:\\tools'
            Message = "脚本或 manifest 中发现硬编码 C:\tools"
        }
    )

    $files = Get-ChildItem -Path (Join-Path $RepoRoot "scripts"), (Join-Path $RepoRoot "manifests") -Recurse -File |
        Where-Object { $_.Extension -in @(".ps1", ".cmd", ".json") }

    foreach ($target in $targets) {
        foreach ($file in $files) {
            if ($file.FullName -eq $PSCommandPath) {
                continue
            }

            if ($file.FullName -eq (Join-Path $RepoRoot "manifests\paths.json") -and $target.Pattern -eq 'C:\\tools') {
                continue
            }

            $matches = Select-String -LiteralPath $file.FullName -Pattern $target.Pattern -AllMatches
            foreach ($match in $matches) {
                Write-CheckResult -Level ERROR -Message ("{0}：{1}:{2}" -f $target.Message, (Resolve-Path -LiteralPath $file.FullName -Relative), $match.LineNumber)
            }
        }
    }
}

function Test-SoftwareManifest {
    param(
        [Parameter(Mandatory)]
        $SoftwareManifest,

        [Parameter(Mandatory)]
        [hashtable]$PathMap
    )

    foreach ($package in $SoftwareManifest.packages) {
        if ($package.type -eq "archive" -and [string]::IsNullOrWhiteSpace([string]$package.archiveFormat)) {
            Write-CheckResult -Level ERROR -Message ("归档包缺少 archiveFormat：{0}" -f $package.name)
        }

        if ($package.type -eq "zip") {
            Write-CheckResult -Level WARN -Message ("软件包仍使用旧 type=zip，建议改为 type=archive + archiveFormat=zip：{0}" -f $package.name)
        }

        if ($CheckPackageFiles) {
            $source = Resolve-KitPath -Path $package.source -PathMap $PathMap
            if (Test-Path -LiteralPath $source) {
                Write-CheckResult -Level OK -Message ("安装介质存在：{0}" -f $package.name)
            } else {
                Write-CheckResult -Level WARN -Message ("安装介质不存在或 NAS 不可达：{0} -> {1}" -f $package.name, $source)
            }
        }
    }
}

$resolvedScopePath = Resolve-RepoPath -Path $ScopeManifestPath
if (-not (Test-Path -LiteralPath $resolvedScopePath)) {
    Write-CheckResult -Level ERROR -Message "总定制清单不存在：$ScopeManifestPath"
    exit 1
}

Test-JsonFiles
Test-PowerShellFiles

$scope = Read-JsonFile -Path $resolvedScopePath
$pathsManifestPath = Resolve-RepoPath -Path $scope.pathsManifest
Test-ReferencedPath -Description "pathsManifest" -Path $scope.pathsManifest

$pathMap = Get-KitPathMap -ManifestPath $pathsManifestPath
Test-ReferencedPath -Description "Defender 排除项清单" -Path $scope.system.windowsDefender.exclusionsManifest
Test-ReferencedPath -Description "AppX 清理清单" -Path $scope.appx.removeManifest
Test-ReferencedPath -Description "软件清单" -Path $scope.applications.softwareManifest
Test-ReferencedPath -Description "服务清单" -Path $scope.applications.servicesManifest
Test-ReferencedPath -Description "Junction 清单" -Path $scope.applications.junctionsManifest

Test-PathTokens -PathMap $pathMap
Test-DisallowedPaths

$softwareManifestPath = Resolve-RepoPath -Path $scope.applications.softwareManifest
$softwareManifest = Read-JsonFile -Path $softwareManifestPath
Test-SoftwareManifest -SoftwareManifest $softwareManifest -PathMap $pathMap

if ($script:Failed -gt 0) {
    Write-Host ("项目配置验证失败：{0} 个错误，{1} 个警告。" -f $script:Failed, $script:Warnings) -ForegroundColor Red
    exit 1
}

Write-Host ("项目配置验证通过：0 个错误，{0} 个警告。" -f $script:Warnings) -ForegroundColor Green
