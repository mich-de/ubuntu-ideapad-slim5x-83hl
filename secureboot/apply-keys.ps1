# STEP 3 (Windows, PowerShell as Administrator). ONLY while the firmware is in SETUP MODE
# (BIOS > Secure Boot > "Reset to Setup Mode"/"Clear keys"). Needs in this folder: PK.bin KEK.bin dbx.bin
# (from dump-keys.ps1) and db-new.esl (from make-db-esl.py).
# Re-installs your ORIGINAL PK/KEK/dbx and a db = original + the extra Microsoft certificates, PK last.
# This is the script that worked on the 83HL (BIOS PUCN55WW). It is NOT tested on any other model.
param($dir = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$log = "$dir\apply-log.txt"; "== $(Get-Date)" | Out-File $log
function L($m){ $m | Tee-Object -FilePath $log -Append }
function Cur($n){ try { (Get-SecureBootUEFI $n).Bytes } catch { $null } }
function Same($a,$b){ if($null -eq $a -or $null -eq $b){return $false}; [Convert]::ToBase64String($a) -eq [Convert]::ToBase64String($b) }
$sm = (Get-SecureBootUEFI SetupMode).Bytes[0]
L "SetupMode=$sm"
if ($sm -ne 1) { L "ABORT: firmware is not in Setup Mode"; exit 1 }
$t = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$dbx = [IO.File]::ReadAllBytes("$dir\dbx.bin")
if (-not (Same (Cur dbx) $dbx)) { Set-SecureBootUEFI -Name dbx -ContentFilePath "$dir\dbx.bin" -Time $t | Out-Null; L "dbx restored" } else { L "dbx unchanged" }
Set-SecureBootUEFI -Name db -ContentFilePath "$dir\db-new.esl" -Time $t | Out-Null; L "db written (original + extra certs)"
$kek = [IO.File]::ReadAllBytes("$dir\KEK.bin")
if (-not (Same (Cur KEK) $kek)) { Set-SecureBootUEFI -Name KEK -ContentFilePath "$dir\KEK.bin" -Time $t | Out-Null; L "KEK restored" } else { L "KEK unchanged" }
Set-SecureBootUEFI -Name PK -ContentFilePath "$dir\PK.bin" -Time $t | Out-Null; L "PK (vendor) restored last"
L ("SetupMode now=" + (Get-SecureBootUEFI SetupMode).Bytes[0])
L ("db ok=" + (Same (Cur db) ([IO.File]::ReadAllBytes("$dir\db-new.esl"))) + " KEK ok=" + (Same (Cur KEK) $kek) + " PK ok=" + (Same (Cur PK) ([IO.File]::ReadAllBytes("$dir\PK.bin"))))
L "DONE - now re-enable Secure Boot in the BIOS"
