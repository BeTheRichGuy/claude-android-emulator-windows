<#
.SYNOPSIS
  Sets up a local Android emulator on Windows and connects it to Claude Code through mobile-mcp.

.DESCRIPTION
  Downloads everything from the official sources (Microsoft OpenJDK, Google Android SDK, npm).
  Nothing needs administrator rights. Safe to run again: finished steps are skipped.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\setup.ps1
  powershell -ExecutionPolicy Bypass -File .\setup.ps1 -AvdName phone -ApiLevel 34
#>
param(
  [string]$SdkRoot = 'C:\Android\Sdk',
  [string]$AndroidHome = 'C:\Android\home',
  [string]$AvdName = 'claude',
  [int]$ApiLevel = 35,
  [string]$Device = 'pixel_7',
  [string]$JdkRoot = "$env:LOCALAPPDATA\Java",
  [string]$MobileMcpVersion = '1.0.17'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Invoke-WebRequest is very slow with the progress bar on

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

if ("$SdkRoot$AndroidHome" -match '[^\x00-\x7F]') {
  throw 'SdkRoot and AndroidHome must be ASCII-only paths. The emulator breaks on non-ASCII paths (for example a non-English user name).'
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js 20 or newer is required (https://nodejs.org).' }

# 1. Java 17 (needed by sdkmanager / avdmanager). Zip build, so no installer and no admin prompt.
Step 'Java 17'
$jdk = Get-ChildItem $JdkRoot -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $jdk) {
  New-Item -ItemType Directory -Force $JdkRoot | Out-Null
  $zip = Join-Path $env:TEMP 'microsoft-jdk-17.zip'
  Invoke-WebRequest 'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip' -OutFile $zip -UseBasicParsing
  tar -xf $zip -C $JdkRoot
  Remove-Item $zip
  $jdk = Get-ChildItem $JdkRoot -Directory -Filter 'jdk-17*' | Select-Object -First 1
}
$env:JAVA_HOME = $jdk.FullName
Write-Host "JAVA_HOME = $env:JAVA_HOME"

# 2. Android command-line tools
Step 'Android command-line tools'
$sdkmanager = Join-Path $SdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
$avdmanager = Join-Path $SdkRoot 'cmdline-tools\latest\bin\avdmanager.bat'
if (-not (Test-Path $sdkmanager)) {
  $page = (Invoke-WebRequest 'https://developer.android.com/studio' -UseBasicParsing).Content
  $name = [regex]::Match($page, 'commandlinetools-win-\d+_latest\.zip').Value
  if (-not $name) { throw 'Could not find the command-line tools download on developer.android.com/studio.' }
  $zip = Join-Path $env:TEMP $name
  $tmp = Join-Path $env:TEMP 'android-cmdline-tools'
  Invoke-WebRequest "https://dl.google.com/android/repository/$name" -OutFile $zip -UseBasicParsing
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force $tmp, (Join-Path $SdkRoot 'cmdline-tools') | Out-Null
  tar -xf $zip -C $tmp
  Move-Item (Join-Path $tmp 'cmdline-tools') (Join-Path $SdkRoot 'cmdline-tools\latest')
  Remove-Item $zip, $tmp -Recurse -Force
}
Write-Host "SDK = $SdkRoot"

# 3. Environment variables, user scope only
Step 'Environment variables (user scope)'
$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:ANDROID_USER_HOME = $AndroidHome
$env:ANDROID_AVD_HOME = Join-Path $AndroidHome 'avd'
foreach ($n in 'JAVA_HOME', 'ANDROID_HOME', 'ANDROID_SDK_ROOT', 'ANDROID_USER_HOME', 'ANDROID_AVD_HOME') {
  [Environment]::SetEnvironmentVariable($n, (Get-Item "env:$n").Value, 'User')
}
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @($userPath -split ';' | Where-Object { $_ })
$add = @("$env:JAVA_HOME\bin", "$SdkRoot\cmdline-tools\latest\bin", "$SdkRoot\platform-tools", "$SdkRoot\emulator") |
  Where-Object { $parts -notcontains $_ }
if ($add) { [Environment]::SetEnvironmentVariable('Path', (($parts + $add) -join ';'), 'User') }
Write-Host 'Set JAVA_HOME, ANDROID_HOME, ANDROID_SDK_ROOT, ANDROID_USER_HOME, ANDROID_AVD_HOME and PATH.'

# 4. SDK packages. You read and accept Google's licenses yourself.
Step 'Android SDK licenses (read them, then answer y to accept)'
& $sdkmanager --licenses
$image = "system-images;android-$ApiLevel;google_apis_playstore;x86_64"
Step "platform-tools, emulator and the Android $ApiLevel Google Play image (about 2 GB)"
& $sdkmanager 'platform-tools' 'emulator' "platforms;android-$ApiLevel" $image
if ($LASTEXITCODE -ne 0) { throw 'sdkmanager failed. Did you accept the licenses?' }

# 5. Hardware acceleration
Step 'Hardware acceleration'
$emulator = Join-Path $SdkRoot 'emulator\emulator.exe'
$accel = (& $emulator -accel-check 2>&1) -join "`n"
if ($accel -match 'usable') { Write-Host ($accel -split "`n" | Where-Object { $_ -match 'usable' }) }
else {
  Write-Warning "No usable hypervisor. Turn on 'Windows Hypervisor Platform' in Windows Features, reboot, then run this again.`n$accel"
}

# 6. Virtual device
Step "Virtual device '$AvdName'"
$avdDir = Join-Path $env:ANDROID_AVD_HOME "$AvdName.avd"
if (-not (Test-Path $avdDir)) {
  'no' | & $avdmanager create avd -n $AvdName -k $image -d $Device
  $cfg = Join-Path $avdDir 'config.ini'
  if (-not (Test-Path $cfg)) { throw "avdmanager did not create $cfg" }
  # avdmanager defaults: Play Store off, 2 GB RAM, software GPU, and a data partition in <temp> (logins lost on reboot).
  $set = @{ 'PlayStore.enabled' = 'yes'; 'hw.ramSize' = '4096'; 'hw.gpu.enabled' = 'yes'; 'hw.gpu.mode' = 'host'; 'hw.keyboard' = 'yes' }
  $lines = Get-Content $cfg | Where-Object { $_ -notmatch '^disk\.dataPartition\.path=' } | ForEach-Object {
    $k = $_.Split('=')[0]
    if ($set.ContainsKey($k)) { "$k=$($set[$k])" } else { $_ }
  }
  Set-Content $cfg $lines -Encoding ASCII
  Write-Host "Created $avdDir"
} else { Write-Host "Already exists: $avdDir" }

# 7. mobile-mcp, registered in Claude Code for all projects
Step "mobile-mcp $MobileMcpVersion"
npm install -g "@mobilenext/mobile-mcp@$MobileMcpVersion"
$entry = Join-Path (npm root -g) '@mobilenext\mobile-mcp\lib\index.js'
$sdkFwd = $SdkRoot -replace '\\', '/'
# MOBILEMCP_LEGACY_ROBOT=1: the bundled mobilecli does not find local emulators on Windows; this talks to adb directly.
$addArgs = @('mcp', 'add', '--scope', 'user', 'mobile-mcp',
  '-e', "ANDROID_HOME=$sdkFwd", '-e', 'MOBILEMCP_LEGACY_ROBOT=1', '-e', 'MOBILEMCP_DISABLE_TELEMETRY=1',
  '--', 'node', $entry)
if (Get-Command claude -ErrorAction SilentlyContinue) {
  $ErrorActionPreference = 'Continue'
  claude mcp remove mobile-mcp -s user 2>&1 | Out-Null
  $ErrorActionPreference = 'Stop'
  & claude @addArgs
} else {
  Write-Warning 'Claude Code (claude) not found. Register mobile-mcp yourself:'
  Write-Host ("claude " + (($addArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join ' '))
}

Step 'Done'
Write-Host "Start the emulator:  .\start-emulator.cmd $AvdName"
Write-Host 'Then open a new Claude Code session and ask it to use the phone.'
Write-Host 'Sign in to Google (Play Store) and other apps yourself in the emulator window.'
