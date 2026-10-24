# Offline checks for launcher/gradle-fallback.ps1; run by tests/test_gradle_fallback.py, or by hand:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\gradle_fallback_check.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'launcher\gradle-fallback.ps1')

$failures = @()
function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { Write-Host "ok   $Name" } else { Write-Host "FAIL $Name"; $script:failures += $Name }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("cyt-fallback-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    # The real properties file of this checkout.
    $real = Join-Path $root 'launcher\gradle\wrapper\gradle-wrapper.properties'
    $url = Read-WrapperProperty $real 'distributionUrl'
    $sha = Read-WrapperProperty $real 'distributionSha256Sum'
    Check 'distributionUrl is read and unescaped' ($url -match '^https://services\.gradle\.org/distributions/gradle-[\d.]+-bin\.zip$')
    Check 'distributionSha256Sum is a pinned SHA-256' ($sha -match '^[0-9a-f]{64}$')
    Check 'a missing key reads as null' ($null -eq (Read-WrapperProperty $real 'noSuchKey'))

    # Failure detection: the real message from a slow line, and things that must not trigger the fallback.
    $timeout = "Downloading https://services.gradle.org/distributions/gradle-8.9-bin.zip`nException in thread `"main`" java.io.IOException: Downloading from https://services.gradle.org/distributions/gradle-8.9-bin.zip failed: timeout (10000ms)"
    Check 'a download timeout triggers the fallback' (Test-GradleDownloadFailure $timeout)
    Check 'a compile error does not' (-not (Test-GradleDownloadFailure "error: cannot find symbol`n  symbol: variable foo`nFAILURE: Build failed with an exception."))
    Check 'a finished download that later fails does not' (-not (Test-GradleDownloadFailure "Downloading https://services.gradle.org/distributions/gradle-8.9-bin.zip`n....100%`nFAILURE: Build failed with an exception."))

    # Hash check on a tiny file.
    $zip = Join-Path $tmp 'tiny.zip'
    [IO.File]::WriteAllBytes($zip, [Text.Encoding]::ASCII.GetBytes('hello'))
    $hello = '2CF24DBA5FB0A30E26E83B2AC5B9E29E1B161E5C1FA7425E73043362938B9824'
    Check 'matching SHA-256 passes (any case)' ((Test-FileSha256 $zip $hello) -and (Test-FileSha256 $zip $hello.ToLower()))
    Check 'a different SHA-256 fails' (-not (Test-FileSha256 $zip ('0' * 64)))
    Check 'a missing file or empty hash fails' ((-not (Test-FileSha256 (Join-Path $tmp 'none.zip') $hello)) -and (-not (Test-FileSha256 $zip '')))

    # Pointing the wrapper at a local zip, then putting the file back byte for byte.
    $props = Join-Path $tmp 'gradle-wrapper.properties'
    Copy-Item $real $props
    $before = [IO.File]::ReadAllBytes($props)
    Set-WrapperDistributionUrl $props (ConvertTo-PropertiesFileUrl $zip)
    $after = [IO.File]::ReadAllText($props)
    Check 'distributionUrl now points at the local file' ($after -match '(?m)^distributionUrl=file\\:///')
    Check 'the local URL reads back as a file URL' ((Read-WrapperProperty $props 'distributionUrl') -match '^file:///')
    Check 'the pinned checksum line is untouched' ((Read-WrapperProperty $props 'distributionSha256Sum') -eq $sha)
    Check 'only the distributionUrl line changed' ((($after -split "`n").Count) -eq (([Text.Encoding]::UTF8.GetString($before) -split "`n").Count))
    [IO.File]::WriteAllBytes($props, $before)
    Check 'the original bytes are restorable' ([Linq.Enumerable]::SequenceEqual([byte[]][IO.File]::ReadAllBytes($props), [byte[]]$before))

    # A folder name with a space must survive as %20.
    $spaced = Join-Path $tmp 'my folder'
    New-Item -ItemType Directory -Path $spaced | Out-Null
    $zip2 = Join-Path $spaced 'g.zip'
    [IO.File]::WriteAllBytes($zip2, [byte[]](1, 2, 3))
    Check 'spaces are percent-encoded in the file URL' ((ConvertTo-PropertiesFileUrl $zip2) -match 'my%20folder')

    # Without a distributionUrl line the rewrite must refuse rather than write nothing.
    $bad = Join-Path $tmp 'bad.properties'
    Set-Content -LiteralPath $bad -Value 'networkTimeout=10000'
    $threw = $false
    try { Set-WrapperDistributionUrl $bad 'x' } catch { $threw = $true }
    Check 'a file with no distributionUrl is refused' $threw
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) { Write-Host "$($failures.Count) check(s) failed"; exit 1 }
Write-Host 'all checks passed'
