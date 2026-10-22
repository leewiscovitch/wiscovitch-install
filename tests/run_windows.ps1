# Run the Windows page's PowerShell blocks, in order, on a fresh Windows machine.
#
# Usage: run_windows.ps1 -Dir BLOCKDIR [-Target ci|vm|desktop]
#   ci       GitHub's Windows Server runner (default)
#   vm       a real Windows 11 machine, run directly over SSH (no desktop session)
#   desktop  a real Windows 11 machine, run inside the user's desktop session
#            (via tests/windows_desktop_task.ps1), like pasting into Terminal
#
# Each block runs in its own Windows PowerShell 5.1 process, like a fresh paste.
# A block fails if it writes a PowerShell error, or if any of its statements leaves
# a non-zero native exit code, except winget codes that only mean "already
# installed" / "nothing to upgrade" / "not installed".
# Results go to BLOCKDIR\results.tsv (name, status, note) and BLOCKDIR\NNN.log.
param([Parameter(Mandatory)] [string] $Dir, [ValidateSet('ci', 'vm', 'desktop')] [string] $Target = 'ci',
      [string] $GitName = 'CI Test', [string] $GitEmail = 'ci@example.com')

$results = Join-Path $Dir 'results.tsv'
Set-Content -Path $results -Value $null -Encoding utf8

# Blocks that can't run here, with the reason shown in the report
$skip = [ordered]@{
    'Get-WindowsUpdate[^\r\n]*-Install' = 'installs updates and reboots (30+ min)'
    'Restart-Computer'                  = 'the test reboots separately and checks afterwards'
}
if ($Target -ne 'desktop') { $skip['Stop-Process -Name explorer'] = 'no desktop session' }
if ($Target -eq 'ci') {
    $skip['UpdateScanMethod'] = 'Windows Server has no Microsoft Store'
    $skip['winget upgrade --all'] = 'would upgrade every tool on the CI image (install steps exercise winget)'
} elseif ($Target -eq 'vm') {
    # Over SSH the winget command can't start (no desktop session); the page's
    # "Over SSH" install block covers the same packages and is run instead.
    $skip['(?m)^winget '] = 'winget command needs a desktop session (Over SSH block runs instead)'
    $skip['Repair-WinGetPackageManager'] = 'MSIX installs need a desktop session'
}
$tmp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }

$wingetOk = '-1978335189, -1978335135, -1978335212'  # no upgrade, already installed, not installed
if ($Target -eq 'vm') {
    # Over SSH there's no desktop session, so MSIX packages (e.g. Windows Terminal) can't
    # be installed: 0x80073D19 "a user was logged off". Pasting into Terminal is fine.
    $wingetOk += ', -2147009255'
}

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
    [void]$sb.AppendLine('$ProgressPreference = "SilentlyContinue"')   # progress bars turn into XML noise in logs
    if ($code -match 'Read-Host') {
        $answers = '@{ "Git name" = ''' + $GitName.Replace("'", "''") + '''; "Git email" = ''' + $GitEmail.Replace("'", "''") + ''' }'
        [void]$sb.AppendLine('function Read-Host { param($Prompt) ' + $answers + '[$Prompt] }')
    }
    foreach ($st in $ast.EndBlock.Statements) {
        [void]$sb.AppendLine('$global:LASTEXITCODE = 0')
        [void]$sb.AppendLine($st.Extent.Text)
        $label = ($st.Extent.Text -split "`n")[0].Trim().Replace("'", "''")
        [void]$sb.AppendLine("if (`$LASTEXITCODE -and `$okCodes -notcontains `$LASTEXITCODE) { `$nativeFailures += 'exit ' + `$LASTEXITCODE + ' from: $label' }")
    }
    [void]$sb.AppendLine('if ($nativeFailures) { $nativeFailures | ForEach-Object { "NATIVE FAILURE: $_" }; exit 3 }')
    # $Error also holds errors that cmdlets and modules hid with -ErrorAction SilentlyContinue,
    # so print each one with where it came from, to tell real failures from hidden noise
    [void]$sb.AppendLine('if ($Error.Count) { "POWERSHELL ERRORS: $($Error.Count)"; $Error | ForEach-Object { "  $($_.ToString()) (from $($_.InvocationInfo.MyCommand))" }; exit 2 }')
    [void]$sb.AppendLine('exit 0')

    $script = Join-Path $tmp "$name.ps1"
    Set-Content -Path $script -Value $sb.ToString() -Encoding utf8
    $log = Join-Path $Dir "$name.log"
    # Out-File keeps the log UTF-8; plain *> in Windows PowerShell writes UTF-16
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script *>&1 | Out-File -FilePath $log -Encoding utf8
    switch ($LASTEXITCODE) {
        0       { Add-Result $name 'pass' '' }
        2       { Add-Result $name 'fail' 'PowerShell error' }
        3       { Add-Result $name 'fail' ((Select-String -Path $log -Pattern 'NATIVE FAILURE: (.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) -join '; ') }
        default { Add-Result $name 'fail' "exit $LASTEXITCODE" }
    }
}
# Pass/fail is decided by summarize.py from results.tsv, not by this script's exit code
exit 0
