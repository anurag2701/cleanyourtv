# Dot-sourced by build-and-install.ps1. Runs the Gradle build and, when the wrapper cannot download Gradle
# ("Downloading ...gradle-8.9-bin.zip failed: timeout (10000ms)" on a slow or unstable line), fetches the same
# zip with a resumable download, checks it against the SHA-256 that gradle-wrapper.properties pins, points the
# wrapper at the local copy for that one build, and puts the properties file back afterwards.
#
# Nothing is trusted that is not pinned: with no distributionSha256Sum, or a zip that does not match it, the
# fallback refuses to run and leaves the properties file alone.

function Read-WrapperProperty {
    param([string]$File, [string]$Name)
    $line = Get-Content $File | Where-Object { $_ -match "^\s*$([regex]::Escape($Name))\s*=" } | Select-Object -First 1
    if (-not $line) { return $null }
    # A .properties file escapes ':' as '\:'.
    ($line -replace '^[^=]*=', '').Trim() -replace '\\:', ':'
}

function Test-FileSha256 {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path -LiteralPath $Path) -or -not $Expected) { return $false }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ieq $Expected.Trim()
}

function ConvertTo-PropertiesFileUrl {
    param([string]$Path)
    # file:///C:/Users/me/x.zip, with ':' escaped for a .properties value.
    ([Uri]::new((Resolve-Path -LiteralPath $Path).Path)).AbsoluteUri -replace ':', '\:'
}

function Set-WrapperDistributionUrl {
    param([string]$File, [string]$EscapedUrl)
    $text = [IO.File]::ReadAllText($File)
    $changed = [regex]::Replace($text, '(?m)^distributionUrl=.*$', { param($m) 'distributionUrl=' + $EscapedUrl })
    if ($changed -eq $text) { throw "no distributionUrl line in $File" }
    [IO.File]::WriteAllText($File, $changed, (New-Object Text.UTF8Encoding $false))
}

function Test-GradleDownloadFailure {
    param([string]$Log)
    # The wrapper's own message: "Downloading from https://services.gradle.org/.../gradle-8.9-bin.zip failed: timeout".
    # A later "Build failed" (a compile error, say) must not match.
    $Log -match 'Downloading from\s+https?://\S+\.zip\s+failed'
}

function Invoke-GradleOnce {
    param([string]$Task, [string]$LogFile)
    # cmd merges stderr into stdout, so PowerShell 5.1 does not turn Gradle's progress lines into errors while
    # $ErrorActionPreference is Stop; Tee-Object still shows them live and keeps a copy to look at.
    # Out-Host shows the lines without adding them to this function's output, which is only the exit code.
    cmd /c ".\gradlew.bat $Task -q --console=plain 2>&1" | Tee-Object -FilePath $LogFile | Out-Host
    $LASTEXITCODE
}

function Invoke-GradleBuild {
    param([string]$Task = 'assembleRelease')
    $log = Join-Path ([IO.Path]::GetTempPath()) 'cyt-gradle.log'
    $output = Invoke-GradleOnce -Task $Task -LogFile $log
    $code = [int]($output | Select-Object -Last 1)
    if ($code -eq 0) { return }

    $text = (Get-Content -LiteralPath $log -Raw)
    if (-not (Test-GradleDownloadFailure $text)) { throw 'Gradle build failed' }

    $props = Join-Path $PSScriptRoot 'gradle\wrapper\gradle-wrapper.properties'
    $url = Read-WrapperProperty $props 'distributionUrl'
    $sha = Read-WrapperProperty $props 'distributionSha256Sum'
    if (-not $url -or $url -notmatch '^https://services\.gradle\.org/') { throw "Gradle could not be downloaded, and distributionUrl is not Gradle's own site: $url" }
    if (-not $sha) { throw 'Gradle could not be downloaded, and gradle-wrapper.properties pins no distributionSha256Sum, so a manual download cannot be checked' }

    Write-Host 'Gradle could not be downloaded in time. Fetching it again with a resumable download (it is checked against the pinned SHA-256)...'
    $zip = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetFileName($url))
    & curl.exe -L -C - --retry 20 --retry-all-errors --retry-delay 2 --connect-timeout 20 -o $zip $url
    if ($LASTEXITCODE -ne 0) { throw "curl could not download $url" }
    if (-not (Test-FileSha256 $zip $sha)) {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        throw "The downloaded Gradle zip does not match the pinned SHA-256 ($sha); it was deleted"
    }

    $original = [IO.File]::ReadAllText($props)
    try {
        Set-WrapperDistributionUrl $props (ConvertTo-PropertiesFileUrl $zip)
        $output = Invoke-GradleOnce -Task $Task -LogFile $log
        $code = [int]($output | Select-Object -Last 1)
    } finally {
        [IO.File]::WriteAllText($props, $original, (New-Object Text.UTF8Encoding $false))
    }
    if ($code -ne 0) { throw 'Gradle build failed' }
}
