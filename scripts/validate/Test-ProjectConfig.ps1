param(
    [string]$ScopeManifestPath = "$PSScriptRoot\..\..\manifests\customization-scope.json",
    [switch]$CheckPackageFiles,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"

$script:Failed = 0
$script:Warnings = 0
$script:Results = @()
$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path

function Write-CheckResult {
    param(
        [ValidateSet("OK", "WARN", "ERROR")]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $line = "[{0}] {1}" -f $Level, $Message
    $script:Results += [pscustomobject]@{
        level = $Level
        message = $Message
    }

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

function Get-JsonTypeName {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return "null"
    }

    if ($Value -is [string]) {
        return "string"
    }

    if ($Value -is [bool]) {
        return "boolean"
    }

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return "number"
    }

    if ($Value -is [System.Array] -or $Value -is [System.Collections.IList]) {
        return "array"
    }

    if ($Value.PSObject -and $Value.PSObject.Properties) {
        return "object"
    }

    return $Value.GetType().Name
}

function Test-JsonProperty {
    param(
        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Get-JsonPropertyValue {
    param(
        [Parameter(Mandatory)]
        $Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    return $Object.PSObject.Properties[$Name].Value
}

function Resolve-JsonSchemaRef {
    param(
        [Parameter(Mandatory)]
        $RootSchema,

        [Parameter(Mandatory)]
        [string]$Ref
    )

    if (-not $Ref.StartsWith("#/")) {
        throw "只支持本地 JSON Schema `$ref：$Ref"
    }

    $current = $RootSchema
    foreach ($part in $Ref.Substring(2).Split("/")) {
        $name = $part.Replace("~1", "/").Replace("~0", "~")
        if (-not (Test-JsonProperty -Object $current -Name $name)) {
            throw "JSON Schema `$ref 无法解析：$Ref"
        }

        $current = Get-JsonPropertyValue -Object $current -Name $name
    }

    return $current
}

function Test-JsonSchemaNode {
    param(
        [AllowNull()]
        $Value,

        [Parameter(Mandatory)]
        $Schema,

        [Parameter(Mandatory)]
        $RootSchema,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $errors = @()
    $arrayItems = $null

    if (Test-JsonProperty -Object $Schema -Name '$ref') {
        $refSchema = Resolve-JsonSchemaRef -RootSchema $RootSchema -Ref (Get-JsonPropertyValue -Object $Schema -Name '$ref')
        return @(Test-JsonSchemaNode -Value $Value -Schema $refSchema -RootSchema $RootSchema -Path $Path)
    }

    if (Test-JsonProperty -Object $Schema -Name "allOf") {
        foreach ($subSchema in @(Get-JsonPropertyValue -Object $Schema -Name "allOf")) {
            $errors += @(Test-JsonSchemaNode -Value $Value -Schema $subSchema -RootSchema $RootSchema -Path $Path)
        }
    }

    if (Test-JsonProperty -Object $Schema -Name "anyOf") {
        $matched = $false
        foreach ($subSchema in @(Get-JsonPropertyValue -Object $Schema -Name "anyOf")) {
            $subErrors = @(Test-JsonSchemaNode -Value $Value -Schema $subSchema -RootSchema $RootSchema -Path $Path)
            if ($subErrors.Count -eq 0) {
                $matched = $true
                break
            }
        }

        if (-not $matched) {
            $errors += "$Path 不满足 anyOf 条件"
        }
    }

    if (Test-JsonProperty -Object $Schema -Name "if") {
        $ifSchema = Get-JsonPropertyValue -Object $Schema -Name "if"
        $ifErrors = @(Test-JsonSchemaNode -Value $Value -Schema $ifSchema -RootSchema $RootSchema -Path $Path)
        if ($ifErrors.Count -eq 0 -and (Test-JsonProperty -Object $Schema -Name "then")) {
            $thenSchema = Get-JsonPropertyValue -Object $Schema -Name "then"
            $errors += @(Test-JsonSchemaNode -Value $Value -Schema $thenSchema -RootSchema $RootSchema -Path $Path)
        }
    }

    if (Test-JsonProperty -Object $Schema -Name "type") {
        $expectedType = [string](Get-JsonPropertyValue -Object $Schema -Name "type")
        $actualType = Get-JsonTypeName -Value $Value
        if ($expectedType -eq "array" -and $actualType -ne "array") {
            if ($null -eq $Value) {
                $arrayItems = @()
            } else {
                $arrayItems = @($Value)
            }

            $actualType = "array"
        }

        if ($actualType -ne $expectedType) {
            $errors += "$Path 类型错误：期望 $expectedType，实际 $actualType"
            return $errors
        }
    }

    if (Test-JsonProperty -Object $Schema -Name "const") {
        $expectedConst = Get-JsonPropertyValue -Object $Schema -Name "const"
        if ([string]$Value -ne [string]$expectedConst) {
            $errors += "$Path 常量值错误：期望 $expectedConst，实际 $Value"
        }
    }

    if (Test-JsonProperty -Object $Schema -Name "enum") {
        $allowedValues = @((Get-JsonPropertyValue -Object $Schema -Name "enum") | ForEach-Object { [string]$_ })
        if ($allowedValues -notcontains [string]$Value) {
            $errors += "$Path 枚举值无效：$Value"
        }
    }

    if ((Test-JsonProperty -Object $Schema -Name "pattern") -and $null -ne $Value) {
        $pattern = [string](Get-JsonPropertyValue -Object $Schema -Name "pattern")
        if ([string]$Value -notmatch $pattern) {
            $errors += "$Path 不匹配正则：$pattern"
        }
    }

    $actualTypeForChildren = Get-JsonTypeName -Value $Value
    if ($null -ne $arrayItems) {
        $actualTypeForChildren = "array"
    }

    if ($actualTypeForChildren -eq "object") {
        if (Test-JsonProperty -Object $Schema -Name "required") {
            foreach ($requiredName in @(Get-JsonPropertyValue -Object $Schema -Name "required")) {
                if (-not (Test-JsonProperty -Object $Value -Name ([string]$requiredName))) {
                    $errors += "$Path 缺少必填字段：$requiredName"
                }
            }
        }

        $knownProperties = @()
        if (Test-JsonProperty -Object $Schema -Name "properties") {
            $propertiesSchema = Get-JsonPropertyValue -Object $Schema -Name "properties"
            foreach ($propertySchema in $propertiesSchema.PSObject.Properties) {
                $knownProperties += $propertySchema.Name
                if (Test-JsonProperty -Object $Value -Name $propertySchema.Name) {
                    $childValue = Get-JsonPropertyValue -Object $Value -Name $propertySchema.Name
                    $errors += @(Test-JsonSchemaNode -Value $childValue -Schema $propertySchema.Value -RootSchema $RootSchema -Path "$Path.$($propertySchema.Name)")
                }
            }
        }

        if (Test-JsonProperty -Object $Schema -Name "additionalProperties") {
            $additionalRule = Get-JsonPropertyValue -Object $Schema -Name "additionalProperties"
            foreach ($actualProperty in $Value.PSObject.Properties) {
                if ($knownProperties -contains $actualProperty.Name) {
                    continue
                }

                if ($additionalRule -is [bool]) {
                    if (-not $additionalRule) {
                        $errors += "$Path 不允许额外字段：$($actualProperty.Name)"
                    }
                } else {
                    $errors += @(Test-JsonSchemaNode -Value $actualProperty.Value -Schema $additionalRule -RootSchema $RootSchema -Path "$Path.$($actualProperty.Name)")
                }
            }
        }
    }

    if ($actualTypeForChildren -eq "array" -and (Test-JsonProperty -Object $Schema -Name "items")) {
        $itemSchema = Get-JsonPropertyValue -Object $Schema -Name "items"
        $index = 0
        $items = if ($null -ne $arrayItems) { $arrayItems } else { @($Value) }
        foreach ($item in $items) {
            $errors += @(Test-JsonSchemaNode -Value $item -Schema $itemSchema -RootSchema $RootSchema -Path "$Path[$index]")
            $index++
        }
    }

    return $errors
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

function Test-JsonSchemaFiles {
    $schemaPairs = @(
        @{ Manifest = "appx-cleanup.json"; Schema = "appx-cleanup.schema.json" },
        @{ Manifest = "customization-scope.json"; Schema = "customization-scope.schema.json" },
        @{ Manifest = "defender-exclusions.json"; Schema = "defender-exclusions.schema.json" },
        @{ Manifest = "junctions.json"; Schema = "junctions.schema.json" },
        @{ Manifest = "paths.json"; Schema = "paths.schema.json" },
        @{ Manifest = "services.json"; Schema = "services.schema.json" },
        @{ Manifest = "software.json"; Schema = "software.schema.json" }
    )

    foreach ($pair in $schemaPairs) {
        $manifestPath = Join-Path (Join-Path $RepoRoot "manifests") $pair.Manifest
        $schemaPath = Join-Path (Join-Path $RepoRoot "schemas") $pair.Schema

        try {
            $manifest = Read-JsonFile -Path $manifestPath
            $schema = Read-JsonFile -Path $schemaPath
            $schemaErrors = @(Test-JsonSchemaNode -Value $manifest -Schema $schema -RootSchema $schema -Path $pair.Manifest)
            if ($schemaErrors.Count -eq 0) {
                Write-CheckResult -Level OK -Message ("Schema 校验通过：{0}" -f $pair.Manifest)
            } else {
                foreach ($schemaError in $schemaErrors) {
                    Write-CheckResult -Level ERROR -Message ("Schema 校验失败：{0}" -f $schemaError)
                }
            }
        } catch {
            Write-CheckResult -Level ERROR -Message ("Schema 校验异常：{0} - {1}" -f $pair.Manifest, $_.Exception.Message)
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

    $allowedStages = @("golden-image", "post-deploy", "manual")
    $allowedTypes = @("archive", "zip", "installer", "manual")
    $allowedArchiveFormats = @("zip", "tar.gz")

    foreach ($package in $SoftwareManifest.packages) {
        if ([string]::IsNullOrWhiteSpace([string]$package.name)) {
            Write-CheckResult -Level ERROR -Message "软件包缺少 name"
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.version)) {
            Write-CheckResult -Level ERROR -Message ("软件包缺少 version：{0}" -f $package.name)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.stage)) {
            Write-CheckResult -Level ERROR -Message ("软件包缺少 stage：{0}" -f $package.name)
        } elseif ($allowedStages -notcontains [string]$package.stage) {
            Write-CheckResult -Level ERROR -Message ("软件包 stage 无效：{0} -> {1}" -f $package.name, $package.stage)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.type)) {
            Write-CheckResult -Level ERROR -Message ("软件包缺少 type：{0}" -f $package.name)
        } elseif ($allowedTypes -notcontains [string]$package.type) {
            Write-CheckResult -Level ERROR -Message ("软件包 type 无效：{0} -> {1}" -f $package.name, $package.type)
        }

        if ($package.type -eq "archive" -and [string]::IsNullOrWhiteSpace([string]$package.archiveFormat)) {
            Write-CheckResult -Level ERROR -Message ("归档包缺少 archiveFormat：{0}" -f $package.name)
        } elseif ($package.archiveFormat -and $allowedArchiveFormats -notcontains [string]$package.archiveFormat) {
            Write-CheckResult -Level ERROR -Message ("归档格式无效：{0} -> {1}" -f $package.name, $package.archiveFormat)
        }

        if ($package.type -eq "zip") {
            Write-CheckResult -Level WARN -Message ("软件包仍使用旧 type=zip，建议改为 type=archive + archiveFormat=zip：{0}" -f $package.name)
        }

        if ($package.type -in @("archive", "zip", "installer")) {
            if ([string]::IsNullOrWhiteSpace([string]$package.source)) {
                Write-CheckResult -Level ERROR -Message ("软件包缺少 source：{0}" -f $package.name)
            }

            if ([string]::IsNullOrWhiteSpace([string]$package.destination)) {
                Write-CheckResult -Level ERROR -Message ("软件包缺少 destination：{0}" -f $package.name)
            }
        }

        if ($package.type -eq "installer" -and $null -eq $package.silentInstall) {
            Write-CheckResult -Level ERROR -Message ("安装器缺少 silentInstall：{0}" -f $package.name)
        }

        $expectedHash = [string]$package.sha256
        if (-not [string]::IsNullOrWhiteSpace($expectedHash) -and $expectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
            Write-CheckResult -Level ERROR -Message ("SHA256 格式无效：{0}" -f $package.name)
        }

        if ($CheckPackageFiles) {
            $source = Resolve-KitPath -Path $package.source -PathMap $PathMap
            if (Test-Path -LiteralPath $source) {
                Write-CheckResult -Level OK -Message ("安装介质存在：{0}" -f $package.name)
                if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
                    $actualHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
                    if ($actualHash -eq $expectedHash.ToLowerInvariant()) {
                        Write-CheckResult -Level OK -Message ("SHA256 匹配：{0}" -f $package.name)
                    } else {
                        Write-CheckResult -Level ERROR -Message ("SHA256 不匹配：{0}" -f $package.name)
                    }
                }
            } else {
                Write-CheckResult -Level WARN -Message ("安装介质不存在或 NAS 不可达：{0} -> {1}" -f $package.name, $source)
            }
        }
    }
}

function Write-ValidationReport {
    param(
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $resolvedPath = Resolve-RepoPath -Path $Path
    $reportDirectory = Split-Path -Path $resolvedPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $okCount = @($script:Results | Where-Object { $_.level -eq "OK" }).Count
    $report = [pscustomobject]@{
        generatedAt = (Get-Date).ToString("s")
        repoRoot = $RepoRoot
        failed = $script:Failed
        warnings = $script:Warnings
        passed = $okCount
        results = $script:Results
    }

    if ([IO.Path]::GetExtension($resolvedPath).ToLowerInvariant() -eq ".md") {
        $lines = @(
            "# 项目配置验证报告",
            "",
            "- 生成时间：$($report.generatedAt)",
            "- 仓库根目录：$RepoRoot",
            "- 通过：$okCount",
            "- 警告：$script:Warnings",
            "- 错误：$script:Failed",
            "",
            "| 级别 | 消息 |",
            "|---|---|"
        )

        foreach ($result in $script:Results) {
            $message = ([string]$result.message).Replace("|", "\|")
            $lines += "| $($result.level) | $message |"
        }

        Set-Content -LiteralPath $resolvedPath -Value $lines -Encoding UTF8
    } else {
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedPath -Encoding UTF8
    }

    Write-Host ("[OK] 验证报告已写入：{0}" -f $resolvedPath) -ForegroundColor Green
}

$resolvedScopePath = Resolve-RepoPath -Path $ScopeManifestPath
if (-not (Test-Path -LiteralPath $resolvedScopePath)) {
    Write-CheckResult -Level ERROR -Message "总定制清单不存在：$ScopeManifestPath"
    Write-ValidationReport -Path $ReportPath
    exit 1
}

Test-JsonFiles
Test-JsonSchemaFiles
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

Write-ValidationReport -Path $ReportPath

if ($script:Failed -gt 0) {
    Write-Host ("项目配置验证失败：{0} 个错误，{1} 个警告。" -f $script:Failed, $script:Warnings) -ForegroundColor Red
    exit 1
}

Write-Host ("项目配置验证通过：0 个错误，{0} 个警告。" -f $script:Warnings) -ForegroundColor Green
