function Test-KitPackageHash {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [AllowEmptyString()]
        [string]$ExpectedHash
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedHash)) {
        return
    }

    if ($ExpectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "SHA256 格式无效：$Source"
    }

    $actualHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedHash.ToLowerInvariant()) {
        throw "SHA256 校验失败：$Source"
    }

    if (Get-Command Write-KitLog -ErrorAction SilentlyContinue) {
        Write-KitLog "SHA256 校验通过：$Source" "OK"
    }
}
