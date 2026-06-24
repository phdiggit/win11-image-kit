@{
    Severity = @(
        'Error',
        'Warning'
    )

    ExcludeRules = @(
        # 本仓库脚本以中文控制台日志为主，当前阶段先不把 Write-Host 日志风格作为阻断项。
        'PSAvoidUsingWriteHost',

        # 现有危险脚本已经通过任务约定和 -WhatIf/显式入口治理，后续再逐步细化每个函数的 ShouldProcess。
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @(
                '5.1',
                '7.0'
            )
        }
    }
}
