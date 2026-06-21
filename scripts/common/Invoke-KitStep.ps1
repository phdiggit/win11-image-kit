function Resolve-KitRepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,

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

function Invoke-KitStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [hashtable]$Arguments = @{},

        [bool]$Enabled = $true,

        [bool]$SupportsWhatIf = $false,

        [bool]$ForwardWhatIf = $false,

        [string]$StepKind = "步骤"
    )

    if (-not (Get-Command Write-KitLog -ErrorAction SilentlyContinue)) {
        throw "Invoke-KitStep 需要先加载 Write-Log.ps1"
    }

    if (-not $Enabled) {
        Write-KitLog ("跳过{0}：{1}" -f $StepKind, $Name)
        return
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw ("{0}脚本不存在：{1}" -f $StepKind, $ScriptPath)
    }

    $stepArguments = @{} + $Arguments
    if ($SupportsWhatIf -and $ForwardWhatIf) {
        $stepArguments["WhatIf"] = $true
    }

    Write-KitLog ("执行{0}：{1}" -f $StepKind, $Name)
    & $ScriptPath @stepArguments
}
