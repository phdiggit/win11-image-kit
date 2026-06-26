param(
    [string]$ScopeManifestPath = "manifests/customization-scope.json",
    [switch]$CheckPackageFiles,
    [string]$ReportPath,
    [string]$LogPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\common\Write-Log.ps1"
. "$PSScriptRoot\..\common\Resolve-KitPath.ps1"
. "$PSScriptRoot\..\common\Resolve-KitOutputPath.ps1"
. "$PSScriptRoot\..\common\New-StepResult.ps1"

$script:Failed = 0
$script:Warnings = 0
$script:Results = @()
$script:StepResults = @()
$RepoRoot = (Resolve-Path -LiteralPath "$PSScriptRoot\..\..").Path
$script:ValidationStartedAt = Get-Date
$script:ValidationRunStamp = $script:ValidationStartedAt.ToString("yyyyMMdd-HHmmss")
$script:ValidationReportPath = $null
$script:ValidationReportRequired = $false
$script:RequestedValidationReportPath = $ReportPath
$script:RequestedValidationLogPath = $LogPath

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

    $stepResultArgs = @{
        Name = $Message
        Message = $Message
    }

    switch ($Level) {
        "OK" {
            $stepResultArgs.Required = $true
            $stepResultArgs.Status = "unchanged"
            Write-Host $line -ForegroundColor Green
        }
        "WARN" {
            $script:Warnings++
            $stepResultArgs.Required = $false
            $stepResultArgs.Status = "unchanged"
            $stepResultArgs.Warnings = @($Message)
            Write-Host $line -ForegroundColor Yellow
        }
        "ERROR" {
            $script:Failed++
            $stepResultArgs.Required = $true
            $stepResultArgs.Status = "failed"
            $stepResultArgs.Errors = @($Message)
            Write-Host $line -ForegroundColor Red
        }
    }

    $script:StepResults += New-KitStepResult @stepResultArgs
    Write-KitLogFileLine -Line $line
}

function Get-KitReportingSection {
    param(
        [Parameter(Mandatory)]
        $ScopeConfig,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($ScopeConfig.PSObject.Properties.Name -notcontains "reporting") {
        return $null
    }

    if ($ScopeConfig.reporting.PSObject.Properties.Name -notcontains $Name) {
        return $null
    }

    $section = $ScopeConfig.reporting.$Name
    if ($null -eq $section -or -not $section.enabled) {
        return $null
    }

    return $section
}

function Resolve-KitArtifactSpec {
    param(
        [AllowEmptyString()]
        [string]$ExplicitPath,

        [AllowEmptyString()]
        [string]$AutoDirectory,

        [Parameter(Mandatory)]
        [string]$FileName,

        [hashtable]$PathMap
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return [pscustomobject]@{
            path = Resolve-KitOutputPath -Path $ExplicitPath -PathMap $PathMap -RepoRoot $RepoRoot
            required = $true
            source = "explicit"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($AutoDirectory)) {
        $directory = Resolve-KitOutputPath -Path $AutoDirectory -PathMap $PathMap -RepoRoot $RepoRoot
        return [pscustomobject]@{
            path = Join-Path -Path $directory -ChildPath $FileName
            required = $false
            source = "profile"
        }
    }

    return [pscustomobject]@{
        path = $null
        required = $false
        source = "none"
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
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath $Path))
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
        if ($expectedType -eq "integer") {
            if ($actualType -ne "number") {
                $errors += "$Path 类型错误：期望 integer，实际 $actualType"
                return $errors
            }

            try {
                $numericValue = [double]$Value
                if ($numericValue -ne [Math]::Floor($numericValue)) {
                    $errors += "$Path 类型错误：期望 integer，实际 number"
                }
            } catch {
                $errors += "$Path 类型错误：期望 integer，实际 $actualType"
            }

            $actualType = "integer"
        }

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

    if ((Test-JsonProperty -Object $Schema -Name "minimum") -and $null -ne $Value) {
        $minimum = [double](Get-JsonPropertyValue -Object $Schema -Name "minimum")
        try {
            if ([double]$Value -lt $minimum) {
                $errors += "$Path 小于最小值：$minimum"
            }
        } catch {
            $errors += "$Path 无法按数字比较 minimum：$minimum"
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
        @{ Manifest = "build-lock.json"; Schema = "build-lock.schema.json" },
        @{ Manifest = "capability-registry.json"; Schema = "capability-registry.schema.json" },
        @{ Manifest = "config-layers.json"; Schema = "config-layers.schema.json" },
        @{ Manifest = "context-scope.json"; Schema = "context-scope.schema.json" },
        @{ Manifest = "customization-scope.json"; Schema = "customization-scope.schema.json" },
        @{ Manifest = "defender-exclusions.json"; Schema = "defender-exclusions.schema.json" },
        @{ Manifest = "junctions.json"; Schema = "junctions.schema.json" },
        @{ Manifest = "paths.json"; Schema = "paths.schema.json" },
        @{ Manifest = "paths.local.example.json"; Schema = "config-layer-fragment.schema.json" },
        @{ Manifest = "quality-gates.json"; Schema = "quality-gates.schema.json" },
        @{ Manifest = "services.json"; Schema = "services.schema.json" },
        @{ Manifest = "software.json"; Schema = "software.schema.json" },
        @{ Manifest = "sysprep-appx-gate.json"; Schema = "sysprep-appx-gate.schema.json" }
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

function Test-ConfigLayersReference {
    param(
        [Parameter(Mandatory)]
        $ScopeConfig
    )

    $configLayersManifest = if ($ScopeConfig.PSObject.Properties.Name -contains "configLayersManifest" -and -not [string]::IsNullOrWhiteSpace([string]$ScopeConfig.configLayersManifest)) {
        [string]$ScopeConfig.configLayersManifest
    } else {
        "manifests/config-layers.json"
    }

    Test-ReferencedPath -Description "configLayersManifest" -Path $configLayersManifest
    $configLayersPath = Resolve-RepoPath -Path $configLayersManifest
    if (-not (Test-Path -LiteralPath $configLayersPath)) {
        return
    }

    $configLayers = Read-JsonFile -Path $configLayersPath
    $defaultStack = if ($ScopeConfig.PSObject.Properties.Name -contains "defaultStack" -and -not [string]::IsNullOrWhiteSpace([string]$ScopeConfig.defaultStack)) {
        [string]$ScopeConfig.defaultStack
    } else {
        "default"
    }

    $stackNames = @($configLayers.stacks | ForEach-Object { [string]$_.name })
    if ($stackNames -contains $defaultStack) {
        Write-CheckResult -Level OK -Message ("defaultStack 存在：{0}" -f $defaultStack)
    } else {
        Write-CheckResult -Level ERROR -Message ("defaultStack 不存在于 config-layers stacks：{0}" -f $defaultStack)
    }

    foreach ($layer in @($configLayers.layers)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$layer.path) -and $layer.required) {
            Test-ReferencedPath -Description ("config layer {0}" -f $layer.id) -Path ([string]$layer.path)
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$layer.schema)) {
            Test-ReferencedPath -Description ("config layer schema {0}" -f $layer.id) -Path ([string]$layer.schema)
        }
    }
}

function Test-Issue15LocalOverridePolicy {
    $examplePath = Resolve-RepoPath -Path "manifests/paths.local.example.json"
    if (Test-Path -LiteralPath $examplePath) {
        $exampleText = Get-Content -LiteralPath $examplePath -Raw -Encoding UTF8
        $unsafePatterns = @(
            "\\\\192\.168\.1\.37",
            "token",
            "secret",
            "password",
            "apikey",
            "api_key"
        )
        $unsafeMatches = @($unsafePatterns | Where-Object { $exampleText -match $_ })
        if ($unsafeMatches.Count -eq 0) {
            Write-CheckResult -Level OK -Message "paths.local.example.json 未包含已知私有 NAS 或凭据模式"
        } else {
            Write-CheckResult -Level ERROR -Message ("paths.local.example.json 包含不安全示例模式：{0}" -f ($unsafeMatches -join ", "))
        }
    }

    $buildLockPath = Resolve-RepoPath -Path "manifests/build-lock.json"
    if (Test-Path -LiteralPath $buildLockPath) {
        $buildLock = Read-JsonFile -Path $buildLockPath
        $requiredLocalEntries = @($buildLock.entries | Where-Object {
            $_.required -and [string]$_.path -eq "manifests/paths.local.json"
        })
        if ($requiredLocalEntries.Count -eq 0) {
            Write-CheckResult -Level OK -Message "paths.local.json 未进入 Build Lock required entries"
        } else {
            Write-CheckResult -Level ERROR -Message "paths.local.json 不得进入 Build Lock required entries"
        }
    }

    $trackedLocal = @(& git -C $RepoRoot ls-files -- "manifests/paths.local.json" 2>$null)
    if ($trackedLocal.Count -eq 0) {
        Write-CheckResult -Level OK -Message "paths.local.json 未被 Git 跟踪"
    } else {
        Write-CheckResult -Level ERROR -Message "paths.local.json 不得被 Git 跟踪"
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
        $SoftwareManifest
    )

    $allowedEnsure = @("present", "absent", "latest", "pinned", "manual")
    $allowedSource = @("winget", "chocolatey", "msi", "powershell", "manual", "none")
    $allowedScope = @("machine", "current-user", "default-user", "none")
    $allowedInstallMode = @("planned", "manual", "disabled")

    foreach ($package in @($SoftwareManifest.software)) {
        if ([string]::IsNullOrWhiteSpace([string]$package.id)) {
            Write-CheckResult -Level ERROR -Message "软件 Ensure-State 条目缺少 id"
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.displayName)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State 条目缺少 displayName：{0}" -f $package.id)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.ensure)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State 条目缺少 ensure：{0}" -f $package.id)
        } elseif ($allowedEnsure -notcontains [string]$package.ensure) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State ensure 无效：{0} -> {1}" -f $package.id, $package.ensure)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.source)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State 条目缺少 source：{0}" -f $package.id)
        } elseif ($allowedSource -notcontains [string]$package.source) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State source 无效：{0} -> {1}" -f $package.id, $package.source)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.packageId)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State 条目缺少 packageId：{0}" -f $package.id)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.scope)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State 条目缺少 scope：{0}" -f $package.id)
        } elseif ($allowedScope -notcontains [string]$package.scope) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State scope 无效：{0} -> {1}" -f $package.id, $package.scope)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.installMode)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State 条目缺少 installMode：{0}" -f $package.id)
        } elseif ($allowedInstallMode -notcontains [string]$package.installMode) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State installMode 无效：{0} -> {1}" -f $package.id, $package.installMode)
        }

        try {
            [void][int]$package.priority
        } catch {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State priority 必须是整数：{0}" -f $package.id)
        }

        if ([string]::IsNullOrWhiteSpace([string]$package.notes)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State 条目缺少 notes：{0}" -f $package.id)
        }

        if (Test-JsonProperty -Object $package -Name "tags") {
            foreach ($tag in @($package.tags)) {
                if ((Get-JsonTypeName -Value $tag) -ne "string") {
                    Write-CheckResult -Level ERROR -Message ("软件 Ensure-State tags 必须是 string 数组：{0}" -f $package.id)
                }
            }
        }

        if ($package.ensure -eq "pinned" -and [string]::IsNullOrWhiteSpace([string]$package.version)) {
            Write-CheckResult -Level ERROR -Message ("软件 Ensure-State pinned 条目必须提供 version：{0}" -f $package.id)
        }

        if ($package.installMode -eq "disabled" -and $package.ensure -eq "present") {
            Write-CheckResult -Level WARN -Message ("禁用条目不会自动达到 present 状态：{0}" -f $package.id)
        }

        if ($package.installMode -eq "planned" -and $package.source -eq "none") {
            Write-CheckResult -Level WARN -Message ("planned 条目 source=none 时只能输出人工计划：{0}" -f $package.id)
        }
    }
}

function Test-ServiceManifest {
    param(
        [Parameter(Mandatory)]
        $ServiceManifest
    )

    $allowedEnsure = @("running", "stopped", "disabled", "manual", "absent", "ignore")
    $allowedStartupType = @("automatic", "manual", "disabled", "unchanged")
    $allowedScope = @("machine", "none")
    $allowedChangeMode = @("planned", "manual", "disabled")

    foreach ($service in @($ServiceManifest.services)) {
        if ([string]::IsNullOrWhiteSpace([string]$service.name)) {
            Write-CheckResult -Level ERROR -Message "服务 Ensure-State 条目缺少 name"
            continue
        }

        if ([string]::IsNullOrWhiteSpace([string]$service.displayName)) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State 条目缺少 displayName：{0}" -f $service.name)
        }

        if ([string]::IsNullOrWhiteSpace([string]$service.ensure)) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State 条目缺少 ensure：{0}" -f $service.name)
        } elseif ($allowedEnsure -notcontains [string]$service.ensure) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State ensure 无效：{0} -> {1}" -f $service.name, $service.ensure)
        }

        if ([string]::IsNullOrWhiteSpace([string]$service.startupType)) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State 条目缺少 startupType：{0}" -f $service.name)
        } elseif ($allowedStartupType -notcontains [string]$service.startupType) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State startupType 无效：{0} -> {1}" -f $service.name, $service.startupType)
        }

        if ([string]::IsNullOrWhiteSpace([string]$service.scope)) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State 条目缺少 scope：{0}" -f $service.name)
        } elseif ($allowedScope -notcontains [string]$service.scope) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State scope 无效：{0} -> {1}" -f $service.name, $service.scope)
        }

        if ([string]::IsNullOrWhiteSpace([string]$service.changeMode)) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State 条目缺少 changeMode：{0}" -f $service.name)
        } elseif ($allowedChangeMode -notcontains [string]$service.changeMode) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State changeMode 无效：{0} -> {1}" -f $service.name, $service.changeMode)
        }

        try {
            [void][int]$service.priority
        } catch {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State priority 必须是整数：{0}" -f $service.name)
        }

        if ([string]::IsNullOrWhiteSpace([string]$service.reason)) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State 条目缺少 reason：{0}" -f $service.name)
        }

        if ([string]::IsNullOrWhiteSpace([string]$service.notes)) {
            Write-CheckResult -Level ERROR -Message ("服务 Ensure-State 条目缺少 notes：{0}" -f $service.name)
        }

        if ($service.changeMode -eq "disabled" -and $service.ensure -eq "running") {
            Write-CheckResult -Level WARN -Message ("禁用条目不会自动达到 running 状态：{0}" -f $service.name)
        }

        if ($service.ensure -eq "disabled" -and $service.startupType -ne "disabled") {
            Write-CheckResult -Level WARN -Message ("服务 ensure=disabled 时建议 startupType=disabled：{0}" -f $service.name)
        }

        if ($service.ensure -eq "ignore" -and $service.changeMode -eq "planned") {
            Write-CheckResult -Level WARN -Message ("服务 ensure=ignore 时通常不需要 planned 变更：{0}" -f $service.name)
        }
    }
}

function Write-ValidationReport {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required
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
    $stepSummary = Get-KitStepResultSummary -Results $script:StepResults
    $report = [pscustomobject]@{
        generatedAt = (Get-Date).ToString("s")
        repoRoot = $RepoRoot
        failed = $script:Failed
        warnings = $script:Warnings
        passed = $okCount
        results = $script:Results
        stepResults = $script:StepResults
        stepSummary = $stepSummary
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
            "- StepResult 总数：$($stepSummary.total)",
            "- StepResult 阻断失败：$($stepSummary.failedRequiredCount)",
            "",
            "| 级别 | 消息 |",
            "|---|---|"
        )

        foreach ($result in $script:Results) {
            $message = ([string]$result.message).Replace("|", "\|")
            $lines += "| $($result.level) | $message |"
        }

        $written = Write-KitTextFile -Path $resolvedPath -Content $lines -Description "项目配置验证报告" -Required:$Required
    } else {
        $written = Write-KitTextFile -Path $resolvedPath -Content ($report | ConvertTo-Json -Depth 8) -Description "项目配置验证报告" -Required:$Required
    }

    if ($written) {
        $line = "[OK] 验证报告已写入：{0}" -f $resolvedPath
        Write-Host $line -ForegroundColor Green
        Write-KitLogFileLine -Line $line
    }
}

$initialLogSpec = Resolve-KitArtifactSpec -ExplicitPath $LogPath -AutoDirectory $null -FileName "unused.log" -PathMap $null
if (-not [string]::IsNullOrWhiteSpace($initialLogSpec.path)) {
    Set-KitLogPath -Path $initialLogSpec.path -Required:$initialLogSpec.required
}

$initialReportSpec = Resolve-KitArtifactSpec -ExplicitPath $ReportPath -AutoDirectory $null -FileName "unused.md" -PathMap $null
$script:ValidationReportPath = $initialReportSpec.path
$script:ValidationReportRequired = $initialReportSpec.required

$resolvedScopePath = Resolve-RepoPath -Path $ScopeManifestPath
if (-not (Test-Path -LiteralPath $resolvedScopePath)) {
    Write-CheckResult -Level ERROR -Message "总定制清单不存在：$ScopeManifestPath"
    Write-ValidationReport -Path $script:ValidationReportPath -Required:$script:ValidationReportRequired
    Clear-KitLogPath
    exit 1
}

Test-JsonFiles
Test-JsonSchemaFiles
Test-PowerShellFiles

$scope = Read-JsonFile -Path $resolvedScopePath
$pathsManifestPath = Resolve-RepoPath -Path $scope.pathsManifest
Test-ReferencedPath -Description "pathsManifest" -Path $scope.pathsManifest
Test-ConfigLayersReference -ScopeConfig $scope
Test-Issue15LocalOverridePolicy

$pathMap = Get-KitPathMap -ManifestPath $pathsManifestPath
$reportingConfig = Get-KitReportingSection -ScopeConfig $scope -Name "validation"

if (-not [string]::IsNullOrWhiteSpace($script:RequestedValidationLogPath) -and $script:RequestedValidationLogPath -match '\$\{[^}]+\}') {
    Clear-KitLogPath
    $resolvedLogSpec = Resolve-KitArtifactSpec -ExplicitPath $script:RequestedValidationLogPath -AutoDirectory $null -FileName "unused.log" -PathMap $pathMap
    Set-KitLogPath -Path $resolvedLogSpec.path -Required:$resolvedLogSpec.required
}

if (-not [string]::IsNullOrWhiteSpace($script:RequestedValidationReportPath) -and $script:RequestedValidationReportPath -match '\$\{[^}]+\}') {
    $resolvedReportSpec = Resolve-KitArtifactSpec -ExplicitPath $script:RequestedValidationReportPath -AutoDirectory $null -FileName "unused.md" -PathMap $pathMap
    $script:ValidationReportPath = $resolvedReportSpec.path
    $script:ValidationReportRequired = $resolvedReportSpec.required
}

if ([string]::IsNullOrWhiteSpace((Get-KitLogPath))) {
    $autoLogSpec = Resolve-KitArtifactSpec `
        -ExplicitPath $null `
        -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.logDirectory } else { $null }) `
        -FileName ("project-config-validation-{0}.log" -f $script:ValidationRunStamp) `
        -PathMap $pathMap
    if (-not [string]::IsNullOrWhiteSpace($autoLogSpec.path)) {
        Set-KitLogPath -Path $autoLogSpec.path -Required:$autoLogSpec.required
    }
}

if ([string]::IsNullOrWhiteSpace($script:ValidationReportPath)) {
    $autoReportSpec = Resolve-KitArtifactSpec `
        -ExplicitPath $null `
        -AutoDirectory $(if ($null -ne $reportingConfig) { [string]$reportingConfig.reportDirectory } else { $null }) `
        -FileName ("project-config-validation-{0}.md" -f $script:ValidationRunStamp) `
        -PathMap $pathMap
    $script:ValidationReportPath = $autoReportSpec.path
    $script:ValidationReportRequired = $autoReportSpec.required
}

Test-ReferencedPath -Description "Defender 排除项清单" -Path $scope.system.windowsDefender.exclusionsManifest
Test-ReferencedPath -Description "AppX 清理清单" -Path $scope.appx.removeManifest
Test-ReferencedPath -Description "软件清单" -Path $scope.applications.softwareManifest
Test-ReferencedPath -Description "服务清单" -Path $scope.applications.servicesManifest
Test-ReferencedPath -Description "Junction 清单" -Path $scope.applications.junctionsManifest

Test-PathTokens -PathMap $pathMap
Test-DisallowedPaths

$softwareManifestPath = Resolve-RepoPath -Path $scope.applications.softwareManifest
$softwareManifest = Read-JsonFile -Path $softwareManifestPath
Test-SoftwareManifest -SoftwareManifest $softwareManifest

$servicesManifestPath = Resolve-RepoPath -Path $scope.applications.servicesManifest
$servicesManifest = Read-JsonFile -Path $servicesManifestPath
Test-ServiceManifest -ServiceManifest $servicesManifest

Write-ValidationReport -Path $script:ValidationReportPath -Required:$script:ValidationReportRequired

if ($script:Failed -gt 0) {
    $line = "项目配置验证失败：{0} 个错误，{1} 个警告。" -f $script:Failed, $script:Warnings
    Write-Host $line -ForegroundColor Red
    Write-KitLogFileLine -Line $line
    Clear-KitLogPath
    exit 1
}

$line = "项目配置验证通过：0 个错误，{0} 个警告。" -f $script:Warnings
Write-Host $line -ForegroundColor Green
Write-KitLogFileLine -Line $line
Clear-KitLogPath
