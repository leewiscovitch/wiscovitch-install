# Run the Windows page's PowerShell blocks, in order, on a fresh GitHub runner.
#
# Usage: run_windows.ps1 -Dir BLOCKDIR
#
# Each block runs in its own Windows PowerShell 5.1 process, like a fresh paste.
# A block fails if it writes a PowerShell error, or if any of its statements leaves
# a non-zero native exit code, except winget codes that only mean "already
# installed" / "nothing to upgrade" / "not installed".
# Results go to BLOCKDIR\results.tsv (name, status, note) and BLOCKDIR\NNN.log.
param([Parameter(Mandatory)] [string] $Dir)

$results = Join-Path $Dir 'results.tsv'
Set-Content -Path $results -Value $null -Encoding utf8

# Blocks that can't run on a CI server, with the reason shown in the report
$skip = [ordered]@{
    'Get-WindowsUpdate[^\r\n]*-Install' = 'installs updates and reboots'
    'UpdateScanMethod'                  = 'Windows Server has no Microsoft Store'
    'Stop-Process -Name explorer'       = 'restarts the desktop shell'
}

$wingetOk = '-1978335189, -1978335135, -1978335212'  # no upgrade, already installed, not installed

function Add-Result($name, $status, $note) {
    Add-Content -Path $results -Value "$name`t$status`t$note" -Encoding utf8
}

foreach ($f in Get-ChildItem -Path $Dir -Filter *.powershell | Sort-Object Name) {
    $name = $f.BaseName
    $code = Get-Content -Path $f.FullName -Raw
    $reason = foreach ($k in $skip.Keys) { if ($code -match $k) { $skip[$k]; break } }
    if ($reason) { Add-Result $name 'skip' $reason; continue }

    # Rebuild the block statement by statement, checking the native exit code after each
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$null, [ref]$null)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('$nativeFailures = @(); $okCodes = @(' + $wingetOk + ')')
    if ($code -match 'Read-Host') {
        [void]$sb.AppendLine('function Read-Host { param($Prompt) @{ "Git name" = "CI Test"; "Git email" = "ci@example.com" }[$Prompt] }')
    }
    foreach ($st in $ast.EndBlock.Statements) {
        [void]$sb.AppendLine('$global:LASTEXITCODE = 0')
        [void]$sb.AppendLine($st.Extent.Text)
        $label = ($st.Extent.Text -split "`n")[0].Trim().Replace("'", "''")
        [void]$sb.AppendLine("if (`$LASTEXITCODE -and `$okCodes -notcontains `$LASTEXITCODE) { `$nativeFailures += 'exit ' + `$LASTEXITCODE + ' from: $label' }")
    }
    [void]$sb.AppendLine('if ($nativeFailures) { $nativeFailures | ForEach-Object { "NATIVE FAILURE: $_" }; exit 3 }')
    [void]$sb.AppendLine('if ($Error.Count) { "POWERSHELL ERRORS: $($Error.Count)"; exit 2 }')
    [void]$sb.AppendLine('exit 0')

    $script = Join-Path $env:RUNNER_TEMP "$name.ps1"
    Set-Content -Path $script -Value $sb.ToString() -Encoding utf8
    $log = Join-Path $Dir "$name.log"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script *> $log
    switch ($LASTEXITCODE) {
        0       { Add-Result $name 'pass' '' }
        2       { Add-Result $name 'fail' 'PowerShell error' }
        3       { Add-Result $name 'fail' ((Select-String -Path $log -Pattern 'NATIVE FAILURE: (.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join '; ') }
        default { Add-Result $name 'fail' "exit $LASTEXITCODE" }
    }
}
