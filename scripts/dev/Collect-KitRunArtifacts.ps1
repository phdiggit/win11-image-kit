[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$RunRoot,

    [string]$DestinationPath,

    [switch]$IncludeWindowsEventLogs,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

$allowedExtensions = @(".log", ".json", ".md", ".txt", ".csv", ".xml")
$blockedExtensions = @(".wim", ".esd", ".iso", ".vhd", ".vhdx", ".exe", ".msi", ".zip", ".7z", ".rar", ".lic", ".key", ".pfx", ".pem", ".ppk")
$defaultDirectories = @("logs", "reports")

function Resolve-KitFullPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ([IO.Path]::IsPathRooted($expanded)) {
        return [IO.Path]::GetFullPath($expanded)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path (Get-Location).Path -ChildPath $expanded))
}

function Test-KitPathInsideRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $normalizedPath = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

    if ($normalizedPath.Equals($normalizedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $prefix = $normalizedRoot + [IO.Path]::DirectorySeparatorChar
    return $normalizedPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-KitRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-KitPathInsideRoot -Root $Root -Path $Path)) {
        throw "路径不在 RunRoot 内：$Path"
    }

    $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $normalizedPath = [IO.Path]::GetFullPath($Path)
    return $normalizedPath.Substring($normalizedRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-KitSecretRelativePath {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    $segments = $RelativePath -split '[\\/]'
    foreach ($segment in $segments) {
        if ($segment.Equals("secrets", [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Add-KitSkippedFile {
    param(
        [System.Collections.ArrayList]$SkippedFiles,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    [void]$SkippedFiles.Add([pscustomobject]@{
        relativePath = $RelativePath
        reason = $Reason
    })
}

function Get-KitFileSha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
}

function Get-KitCandidateFiles {
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [string[]]$Directories
    )

    $seen = @{}
    $files = New-Object System.Collections.ArrayList

    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue)) {
        $key = $file.FullName.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            [void]$files.Add($file)
        }
    }

    foreach ($directoryName in $Directories) {
        $directoryPath = Join-Path -Path $Root -ChildPath $directoryName
        if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
            continue
        }

        foreach ($file in @(Get-ChildItem -LiteralPath $directoryPath -Recurse -File -ErrorAction SilentlyContinue)) {
            $key = $file.FullName.ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                [void]$files.Add($file)
            }
        }
    }

    return @($files)
}

function Export-KitWindowsEventLogs {
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $eventLogRoot = Join-Path -Path $Root -ChildPath "eventlogs"
    if (-not $PSCmdlet.ShouldProcess($eventLogRoot, "导出 Application/System Windows Event Log")) {
        return
    }

    New-Item -ItemType Directory -Path $eventLogRoot -Force | Out-Null
    foreach ($logName in @("Application", "System")) {
        $destination = Join-Path -Path $eventLogRoot -ChildPath ("{0}.evtx" -f $logName)
        & wevtutil.exe epl $logName $destination /ow:true
        if ($LASTEXITCODE -ne 0) {
            throw "导出 Windows Event Log 失败：$logName"
        }
    }
}

$resolvedRunRoot = (Resolve-Path -LiteralPath $RunRoot -ErrorAction Stop).Path
if (-not (Test-Path -LiteralPath $resolvedRunRoot -PathType Container)) {
    throw "RunRoot 不存在或不是目录：$RunRoot"
}

if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $DestinationPath = Join-Path -Path $resolvedRunRoot -ChildPath ("kit-run-artifacts-{0}.zip" -f $timestamp)
}

$resolvedDestinationPath = Resolve-KitFullPath -Path $DestinationPath
if ((Test-Path -LiteralPath $resolvedDestinationPath) -and -not $Force) {
    throw "DestinationPath 已存在，请使用 -Force 覆盖：$resolvedDestinationPath"
}

if ($IncludeWindowsEventLogs) {
    Export-KitWindowsEventLogs -Root $resolvedRunRoot
}

$directories = @($defaultDirectories)
$effectiveAllowedExtensions = @($allowedExtensions)
if ($IncludeWindowsEventLogs) {
    $directories += "eventlogs"
    $effectiveAllowedExtensions += ".evtx"
}

$includedFiles = New-Object System.Collections.ArrayList
$skippedFiles = New-Object System.Collections.ArrayList
$sourceFiles = New-Object System.Collections.ArrayList

foreach ($file in Get-KitCandidateFiles -Root $resolvedRunRoot -Directories $directories) {
    if (-not (Test-KitPathInsideRoot -Root $resolvedRunRoot -Path $file.FullName)) {
        continue
    }

    $relativePath = ConvertTo-KitRelativePath -Root $resolvedRunRoot -Path $file.FullName
    $extension = $file.Extension.ToLowerInvariant()

    if (Test-KitSecretRelativePath -RelativePath $relativePath) {
        Add-KitSkippedFile -SkippedFiles $skippedFiles -RelativePath $relativePath -Reason "secrets-path"
        continue
    }

    if ($blockedExtensions -contains $extension) {
        Add-KitSkippedFile -SkippedFiles $skippedFiles -RelativePath $relativePath -Reason "blocked-extension"
        continue
    }

    if ($effectiveAllowedExtensions -notcontains $extension) {
        Add-KitSkippedFile -SkippedFiles $skippedFiles -RelativePath $relativePath -Reason "unsupported-extension"
        continue
    }

    $hash = Get-KitFileSha256 -Path $file.FullName
    [void]$includedFiles.Add([pscustomobject]@{
        relativePath = $relativePath
        length = [int64]$file.Length
        sha256 = $hash
    })
    [void]$sourceFiles.Add([pscustomobject]@{
        fullName = $file.FullName
        relativePath = $relativePath
    })
}

$totalBytes = 0L
foreach ($item in $includedFiles) {
    $totalBytes += [int64]$item.length
}

$manifest = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("s")
    runRoot = $resolvedRunRoot
    destinationPath = $resolvedDestinationPath
    includedFiles = @($includedFiles)
    skippedFiles = @($skippedFiles)
    fileCount = @($includedFiles).Count
    totalBytes = $totalBytes
}

if (-not $PSCmdlet.ShouldProcess($resolvedDestinationPath, "创建 VM 测试日志归档")) {
    return
}

$destinationDirectory = Split-Path -Path $resolvedDestinationPath -Parent
if (-not [string]::IsNullOrWhiteSpace($destinationDirectory) -and -not (Test-Path -LiteralPath $destinationDirectory)) {
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
}

$stagingRoot = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ("win11-image-kit-artifacts-{0}" -f ([guid]::NewGuid().ToString("N")))
try {
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    foreach ($sourceFile in $sourceFiles) {
        $targetPath = Join-Path -Path $stagingRoot -ChildPath $sourceFile.relativePath
        $targetDirectory = Split-Path -Path $targetPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($targetDirectory) -and -not (Test-Path -LiteralPath $targetDirectory)) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $sourceFile.fullName -Destination $targetPath -Force
    }

    $manifestPath = Join-Path -Path $stagingRoot -ChildPath "artifact-manifest.json"
    Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 8) -Encoding UTF8

    Compress-Archive -Path (Join-Path -Path $stagingRoot -ChildPath "*") -DestinationPath $resolvedDestinationPath -Force:$Force
    Write-Output ("已创建 VM 测试日志归档：{0}" -f $resolvedDestinationPath)
} finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
