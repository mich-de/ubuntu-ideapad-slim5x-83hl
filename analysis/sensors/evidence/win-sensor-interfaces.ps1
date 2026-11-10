"arch=$env:PROCESSOR_ARCHITECTURE"
$g='{BA1BB692-9B7A-4833-9A1E-525ED134E7E2}'
"--- GUID_DEVINTERFACE_SENSOR interfaces"
$k="HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses\$g"
if(Test-Path $k){ Get-ChildItem $k | ForEach-Object { $_.PSChildName; Get-ChildItem $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object { '   '+$_.PSChildName; $c=Join-Path $_.PSPath 'Control'; if(Test-Path $c){ '     Linked='+(Get-ItemProperty $c -ErrorAction SilentlyContinue).Linked } } } } else { 'no key' }
"--- WinRT DeviceInformation sensors"
try {
 Add-Type -AssemblyName System.Runtime.WindowsRuntime
 $null=[Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
 $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
 $op=[Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync("System.Devices.InterfaceClassGuid:=`"$g`"")
 $t=$asTask.MakeGenericMethod([Windows.Devices.Enumeration.DeviceInformationCollection]).Invoke($null,@($op)); $t.Wait()
 "count="+$t.Result.Count; $t.Result | ForEach-Object { $_.Name+' | '+$_.Id+' | enabled='+$_.IsEnabled }
} catch { "ERR "+$_.Exception.Message }
"--- services"
Get-Service SensorService,SensrSvc,SensorDataService -ErrorAction SilentlyContinue | Format-Table -AutoSize Name,Status,StartType | Out-String
"--- auto rotation / ALS registry"
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AutoRotation' -ErrorAction SilentlyContinue | Out-String
