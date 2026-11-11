# STEP 1 (Windows, PowerShell as Administrator, Secure Boot ON): back up the current Secure Boot variables.
# Writes PK.bin KEK.bin db.bin dbx.bin next to this script. KEEP THEM SAFE: they are your way back.
$ErrorActionPreference = 'Stop'
foreach ($n in 'PK','KEK','db','dbx') {
  [IO.File]::WriteAllBytes("$PSScriptRoot\$n.bin", (Get-SecureBootUEFI $n).Bytes)
  "{0}.bin: {1} bytes" -f $n, (Get-Item "$PSScriptRoot\$n.bin").Length
}
