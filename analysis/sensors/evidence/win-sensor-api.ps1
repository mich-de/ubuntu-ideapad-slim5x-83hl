$t = @('Accelerometer','Gyrometer','LightSensor','Magnetometer','Inclinometer','OrientationSensor','SimpleOrientationSensor','ProximitySensor','Barometer','Compass','HingeAngleSensor','ActivitySensor','Pedometer','HumanPresenceSensor')
foreach($n in $t){
  try {
    $ty = [type]"Windows.Devices.Sensors.$n,Windows.Devices.Sensors,ContentType=WindowsRuntime"
    $m = $ty.GetMethod('GetDefault',[type[]]@())
    if($m){ $s = $m.Invoke($null,@()); if($s){ $r=$null; try{$r=$s.GetCurrentReading()}catch{}; "$n : PRESENT id=$($s.DeviceId)"; if($r){ ($r | Format-List | Out-String).Trim() } } else { "$n : null" } }
    else { "$n : no GetDefault()" }
  } catch { "$n : ERR $($_.Exception.Message)" }
}
"--- sensor device interfaces"
Get-PnpDevice -PresentOnly -Class Sensor | ForEach-Object { $_.InstanceId; Get-ItemProperty -Path ("HKLM:\SYSTEM\CurrentControlSet\Enum\"+$_.InstanceId+"\Device Parameters") -ErrorAction SilentlyContinue | Out-String -Width 300 }
