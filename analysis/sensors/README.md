# Sensori Lenovo IdeaPad Slim 5x 14Q8X9 (83HL) su Linux

## Conclusione
**Strada C per tutti e tre i dispositivi: non c'è hardware da pilotare.** I tre nodi ACPI sono
segnaposto ereditati dal firmware di riferimento Qualcomm CRD; Windows carica i driver ma non
espone alcun sensore. Non servono DTS, moduli, libssc/hexagonrpcd né configurazione
iio-sensor-proxy. Nessuna modifica alla ISO è necessaria (opzionale: lo script di test).

| Dispositivo Windows | ACPI | Chip reale | Bus | Strada |
|---|---|---|---|---|
| All-Ways Aware Sensor Platform - Display | QCOM0693 (`\_SB.SEN2`) | nessuno rilevato | (SSC dell'ADSP) | C |
| All-Ways Aware Sensor Platform - Keyboard | QCOM0694 (`\_SB.SEN3`) | nessuno rilevato | (SSC dell'ADSP) | C |
| Qualcomm Human Presence Sensor | QCOM06D9 (`\_SB.HPS0`) | nessuno (manca il backend camera always-on) | - | C |

Unico sensore fisico confermato: interruttore Hall del coperchio, già nel DTS Glathe
(`x1p42100-lenovo-ideapad-slim5x.dtsi:93-105`, gpio-keys su `tlmm 92`, SW_LID).

## Evidenze
1. **Windows non espone nessun sensore** (misurato su questa macchina, PowerShell ARM64 senza
   admin; script in `evidence/`, output in `evidence/windows-output.txt`):
   - `Windows.Devices.Sensors.*::GetDefault()` restituisce `null` per Accelerometer, Gyrometer,
     LightSensor, Magnetometer, Inclinometer, OrientationSensor, SimpleOrientationSensor,
     Barometer, Compass, HumanPresenceSensor.
   - `DeviceInformation.FindAllAsync` sulla classe GUID_DEVINTERFACE_SENSOR
     `{BA1BB692-9B7A-4833-9A1E-525ED134E7E2}`: `count=0`; la chiave
     `HKLM\SYSTEM\CurrentControlSet\Control\DeviceClasses\{BA1BB692-...}` non esiste.
   - I tre device PnP sono "OK" solo perché il driver UMDF si carica sul nodo ACPI
     (stack `WUDFRd` + `ACPI`), non perché esista un chip.
2. **Nessuna configurazione Lenovo: è quella generica della scheda CRD.**
   - `acpi/DSDT1.dsl:304` `Name (PSUB, "CRD08380")`; hardware ID
     `ACPI\VEN_QCOM&DEV_0693&SUBSYS_CRD08380`.
   - Unico pacchetto di configurazione: `qcsensorsconfigcrd8380.inf_arm64_7a3b28b1a9e52390`
     (`qcSensorsConfigCrd8380.inf`, match solo `SUBSYS_CRD08380`); file `hw_platform` = `CRD`.
     I .json descrivono i chip della CRD/IDP (LSM6DSV su I3C istanze 1/2, AK991x, TCS3430,
     TMD2755, LPS22DF), tutti su bus dell'ADSP con rail `/pmic/client/sensor_vddio`: nessun
     file specifico Lenovo/83HL.
   - `SEN2`/`SEN3` (`acpi/DSDT1.dsl:57549-57640`) non hanno `_CRS`: nessun I2C/GPIO lato APSS,
     solo `_DEP` su IPC0/ADSP/ARPC. Niente da tradurre in DT.
3. **Presenza umana**: `qcHumanPresenceSensor.dll` è un involucro che si aggancia
   all'interfaccia di un altro driver ("Presence Sensor driver", stringhe
   `CreatePresenceDeviceHandleAndRegisterNotification`, `InitializeSensorInstanceIfPresenceIsUp`).
   Il backend Qualcomm è la camera always-on `QCOM0D06` (`qcAlwaysOnSensing.inf`,
   "Spectra ISP Camera Always On Sensing Device"): in Windows quel device **non è presente**
   (`Get-PnpDevice` non lo elenca) e l'unica camera è USB (Chicony `USB\VID_04F2&PID_B81B`),
   non MIPI. `HPS0` (`acpi/DSDT1.dsl:58056-58064`) non ha risorse.
4. **Scheda tecnica Lenovo (PSREF)**: nessuna voce "sensor" in tutto il documento; camera
   "FHD 1080p, with privacy shutter, fixed focus" (niente IR/ToF).
   https://psref.lenovo.com/syspool/Sys/PDF/IdeaPad/IdeaPad_Slim_5_14Q8X9/IdeaPad_Slim_5_14Q8X9_Spec.PDF
   (il 2-in-1 14Q8X9, altro modello, elenca invece "Accelerometer (G) sensor").

## Perché non A né B
- **A (IIO + nodo DT / i2c-gpio)**: richiede un chip, un indirizzo e pin noti. Qui non esiste
  alcun dato specifico della macchina; copiare i pin della CRD o del Dell XPS 9345 / T14s
  significherebbe pilotare GPIO a caso su una scheda diversa (rischio di blocco all'avvio).
  Non è stato prodotto alcun DTS.
- **B (libssc + hexagonrpcd)**: il Sensor Core dell'ADSP con i .json CRD su questa macchina non
  trova sensori nemmeno sotto Windows (punto 1); su Linux darebbe lo stesso risultato.
  Nessun pacchetto scaricato.

## Limiti dell'analisi (non verificabile da WSL)
- Il registro sensori persistito dall'ADSP
  (`C:\Windows\System32\drivers\DriverData\Qualcomm\fastRPC\persist\sensors\registry`) e il log
  ETW `qcSensors` richiedono admin: non letti. La conclusione poggia su API Windows + INF + PSREF.
- Un chip saldato ma non configurato da Lenovo non è escludibile al 100% senza aprire il
  laptop; sarebbe comunque inutilizzato anche da Windows.
- Chiamata API fatta dalla sessione utente tramite `powershell.exe` da WSL; per conferma
  manuale: Impostazioni > Sistema > Schermo (nessuna "luminosità automatica in base alla luce")
  e Impostazioni > Privacy > "Rilevamento presenza" (assente).

## File
- `83hl-sensors-test`: stampa dispositivi IIO (attesi: nessuno), SW_LID, stato remoteproc.
  Esce con errore solo se manca l'interruttore del coperchio.
- `evidence/win-sensor-api.ps1`, `evidence/win-sensor-interfaces.ps1`,
  `evidence/windows-output.txt`: interrogazioni Windows riproducibili (sola lettura).

## Integrazione ISO
Niente di obbligatorio. Opzionale: copiare `sensors/83hl-sensors-test` in
`overlay/usr/local/bin/83hl-sensors-test` (o richiamarlo da `83hl-test`). iio-sensor-proxy può
restare installato: senza dispositivi IIO resta inattivo.
