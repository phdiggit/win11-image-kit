function Test-KitIsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Assert-KitElevation {
    [CmdletBinding()]
    param(
        [string]$Operation = "当前脚本",

        [switch]$AllowWhatIfPreview
    )

    if (Test-KitIsAdministrator) {
        return
    }

    if ($AllowWhatIfPreview -and $WhatIfPreference) {
        $message = "{0} 当前在非管理员会话中运行，已降级为 WhatIf 预演，不会执行真实写入。" -f $Operation
        if (Get-Command Write-KitLog -ErrorAction SilentlyContinue) {
            Write-KitLog $message "WARN"
        } else {
            Write-Warning $message
        }

        return
    }

    throw ("{0} 需要在管理员 PowerShell 会话中执行。可先使用 -WhatIf 预演。" -f $Operation)
}