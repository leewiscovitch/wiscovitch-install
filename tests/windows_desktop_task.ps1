# Run a PowerShell script inside tech's logged-on desktop session, from a remote
# (SSH) session. Things that need a desktop session (the winget command, MSIX/Store
# installs, Windows Update installs, Explorer) work there. Waits for it to finish
# and prints its output.
#
# Usage: windows_desktop_task.ps1 -Script C:\path\to\script.ps1 [-TimeoutMinutes 60]
# Needs: the user logged on at the console (e.g. auto-login), and an admin SSH session.
param([Parameter(Mandatory)] [string] $Script, [int] $TimeoutMinutes = 60, [switch] $NotElevated)

$name = 'ci-desktop-task'
$out = [IO.Path]::ChangeExtension($Script, '.out.txt')
$done = [IO.Path]::ChangeExtension($Script, '.exit.txt')
Remove-Item $out, $done -ErrorAction Ignore

# An active desktop session at the screen (console) or over RDP (rdp-tcp#N)
$session = (quser 2>$null | Select-String -Pattern '^\s*>?(\S+)\s+(console|rdp-tcp#\d+)\s+\d+\s+Active').Matches
if (-not $session) { throw "No active desktop session; the user must be logged on (at the screen, over RDP, or by auto-login)." }
$user = $session[0].Groups[1].Value
"desktop session: $user on $($session[0].Groups[2].Value)"

# The wrapper records output and the script's exit code where SSH can read them
$wrapper = @"
`$ProgressPreference = 'SilentlyContinue'
try { & '$Script' *>&1 | Out-File -FilePath '$out' -Encoding utf8; `$code = if (`$LASTEXITCODE) { `$LASTEXITCODE } elseif (`$?) { 0 } else { 1 } }
catch { `$_ | Out-File -FilePath '$out' -Append -Encoding utf8; `$code = 1 }
Set-Content -Path '$done' -Value `$code
"@
$wrapperPath = [IO.Path]::ChangeExtension($Script, '.wrapper.ps1')
Set-Content -Path $wrapperPath -Value $wrapper -Encoding utf8

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapperPath`""
# Interactive logon type = runs inside the user's existing desktop session; Highest = elevated
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel $(if ($NotElevated) { 'Limited' } else { 'Highest' })
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $name
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while (-not (Test-Path $done) -and (Get-Date) -lt $deadline) { Start-Sleep 3 }
Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction Ignore
if (Test-Path $out) { Get-Content $out }
if (-not (Test-Path $done)) { "TIMED OUT after $TimeoutMinutes min"; exit 124 }
exit [int](Get-Content $done)
