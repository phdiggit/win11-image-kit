if ($null -eq $Global:KitLogSession) {
    $Global:KitLogSession = [ordered]@{
        Path = $null
        Required = $false
        FailureNotified = $false
    }
}

function Set-KitLogPath {
    param(
        [AllowEmptyString()]
        [string]$Path,

        [switch]$Required
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Clear-KitLogPath
        return
    }

    $Global:KitLogSession.Path = $Path
    $Global:KitLogSession.Required = [bool]$Required
    $Global:KitLogSession.FailureNotified = $false

    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force -WhatIf:$false | Out-Null
        }
    } catch {
        $message = "初始化日志文件路径失败：$Path - $($_.Exception.Message)"
        if ($Required) {
            throw $message
        }

        Write-Host ("[WARN] {0}，已降级为仅控制台输出。" -f $message) -ForegroundColor Yellow
        Clear-KitLogPath
    }
}

function Clear-KitLogPath {
    $Global:KitLogSession.Path = $null
    $Global:KitLogSession.Required = $false
    $Global:KitLogSession.FailureNotified = $false
}

function Get-KitLogPath {
    return [string]$Global:KitLogSession.Path
}

function Write-KitLogFileLine {
    param(
        [Parameter(Mandatory)]
        [string]$Line,

        [AllowEmptyString()]
        [string]$LogPath,

        [switch]$Required
    )

    $effectivePath = $LogPath
    $requiredWrite = [bool]$Required

    if ([string]::IsNullOrWhiteSpace($effectivePath)) {
        $effectivePath = Get-KitLogPath
        $requiredWrite = [bool]$Global:KitLogSession.Required
    }

    if ([string]::IsNullOrWhiteSpace($effectivePath)) {
        return
    }

    try {
        $directory = Split-Path -Path $effectivePath -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force -WhatIf:$false | Out-Null
        }

        Add-Content -LiteralPath $effectivePath -Value $Line -Encoding UTF8 -WhatIf:$false
    } catch {
        $message = "写入日志文件失败：$effectivePath - $($_.Exception.Message)"
        if ($requiredWrite) {
            throw $message
        }

        if (-not $Global:KitLogSession.FailureNotified) {
            Write-Host ("[WARN] {0}，已降级为仅控制台输出。" -f $message) -ForegroundColor Yellow
            $Global:KitLogSession.FailureNotified = $true
        }

        if ($effectivePath -eq $Global:KitLogSession.Path) {
            Clear-KitLogPath
        }
    }
}

function Write-KitTextFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Content,

        [string]$Description = "文件",

        [switch]$Required
    )

    try {
        $directory = Split-Path -Path $Path -Parent
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force -WhatIf:$false | Out-Null
        }

        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8 -WhatIf:$false
    } catch {
        $message = "写入$Description 失败：$Path - $($_.Exception.Message)"
        if ($Required) {
            throw $message
        }

        Write-Host ("[WARN] {0}，已跳过该输出。" -f $message) -ForegroundColor Yellow
        return $false
    }

    return $true
}

function Write-KitLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "OK")]
        [string]$Level = "INFO",

        [AllowEmptyString()]
        [string]$LogPath
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    Write-KitLogFileLine -Line $line -LogPath $LogPath
}
