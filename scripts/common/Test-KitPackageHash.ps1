function Test-KitPackageHash {
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [AllowEmptyString()]
        [string]$ExpectedHash,

        [switch]$PassThru
    )

    $result = [ordered]@{
        status = "skipped"
        reason = "hash-not-required"
        source = $Source
        expectedHash = $ExpectedHash
        actualHash = ""
        message = "未配置 SHA256，跳过校验。"
    }

    if ([string]::IsNullOrWhiteSpace($ExpectedHash)) {
        if ($PassThru) {
            return [pscustomobject]$result
        }

        return
    }

    if ($ExpectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
        $result["status"] = "failed"
        $result["reason"] = "hash-invalid"
        $result["message"] = "SHA256 格式无效：$Source"
        if ($PassThru) {
            return [pscustomobject]$result
        }

        throw "SHA256 格式无效：$Source"
    }

    $stream = [System.IO.File]::OpenRead($Source)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $actualHash = ([System.BitConverter]::ToString($sha256.ComputeHash($stream)) -replace "-", "").ToLowerInvariant()
        } finally {
            $sha256.Dispose()
        }
    } finally {
        $stream.Dispose()
    }
    $result["actualHash"] = $actualHash
    $result["expectedHash"] = $ExpectedHash.ToLowerInvariant()
    if ($actualHash -ne $ExpectedHash.ToLowerInvariant()) {
        $result["status"] = "failed"
        $result["reason"] = "hash-mismatch"
        $result["message"] = "SHA256 校验失败：$Source"
        if ($PassThru) {
            return [pscustomobject]$result
        }

        throw "SHA256 校验失败：$Source"
    }

    $result["status"] = "succeeded"
    $result["reason"] = "hash-verified"
    $result["message"] = "SHA256 校验通过：$Source"

    if (Get-Command Write-KitLog -ErrorAction SilentlyContinue) {
        Write-KitLog "SHA256 校验通过：$Source" "OK"
    }

    if ($PassThru) {
        return [pscustomobject]$result
    }
}
