function Assert-KitEqual {
    param(
        [AllowNull()]
        $Actual,

        [AllowNull()]
        $Expected
    )

    if ($Actual -ne $Expected) {
        throw "期望 <$Expected>，实际 <$Actual>。"
    }
}

function Assert-KitNotNullOrEmpty {
    param(
        [AllowNull()]
        $Actual
    )

    if ($null -eq $Actual) {
        throw "期望值不为空，实际为 null。"
    }

    if ($Actual -is [string] -and [string]::IsNullOrEmpty($Actual)) {
        throw "期望字符串不为空。"
    }
}

function Assert-KitNullOrEmpty {
    param(
        [AllowNull()]
        $Actual
    )

    if ($null -eq $Actual) {
        return
    }

    if ($Actual -is [string] -and [string]::IsNullOrEmpty($Actual)) {
        return
    }

    if ($Actual -is [System.Array] -or $Actual -is [System.Collections.ICollection]) {
        if ($Actual.Count -eq 0) {
            return
        }
    }

    throw "期望为空，实际为 <$Actual>。"
}

function Assert-KitMatch {
    param(
        [string]$Actual,
        [string]$Pattern
    )

    if ($Actual -notmatch $Pattern) {
        throw "期望 <$Actual> 匹配 <$Pattern>。"
    }
}

function Assert-KitNotMatch {
    param(
        [string]$Actual,
        [string]$Pattern
    )

    if ($Actual -match $Pattern) {
        throw "期望 <$Actual> 不匹配 <$Pattern>。"
    }
}

function Assert-KitThrows {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [string]$ExpectedMessage
    )

    $thrown = $null
    try {
        & $ScriptBlock
    } catch {
        $thrown = $_
    }

    if ($null -eq $thrown) {
        throw "期望脚本抛出异常，但未抛出。"
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedMessage) -and $thrown.Exception.Message -notlike "*$ExpectedMessage*") {
        throw "异常消息不匹配。期望包含 <$ExpectedMessage>，实际为 <$($thrown.Exception.Message)>。"
    }
}

function Assert-KitDoesNotThrow {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock
    } catch {
        throw "期望脚本不抛出异常，实际为 <$($_.Exception.Message)>。"
    }
}
