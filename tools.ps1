# ============================================================
#  TOOLS WIN CMD PRO - Bo cong cu IT Systems & Support
#  Chay: irm https://tools.transflong.eu.cc | iex
# ============================================================

$ScriptUrl   = 'https://tools.transflong.eu.cc'
# Neu host script tren GitHub, doi thanh:
# $ScriptUrl = 'https://raw.githubusercontent.com/<user>/<repo>/main/tools.ps1'
$WaitSeconds = 5

# Nmap portable (tu upload zip len GitHub Releases cua ban, roi dien URL)
$NmapPortableUrl = 'https://github.com/<user>/<repo>/releases/download/<tag>/nmap-portable.zip'
$NmapPortableDir = "$env:ProgramData\ITTools\nmap"

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# ------------------------------------------------------------
# Ep quyen Administrator
# ------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host 'Dang yeu cau quyen Administrator...' -ForegroundColor Yellow
    try {
        if ($PSCommandPath) {
            Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        } else {
            $cmd = "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; irm $ScriptUrl | iex"
            Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        }
    } catch {
        Write-Host 'Tu choi quyen Administrator. Tool khong the chay.' -ForegroundColor Red
    }
    return
}

$Host.UI.RawUI.WindowTitle = 'IT SYSTEM TOOLKIT (Administrator)'

# ------------------------------------------------------------
# Giao dien (khung can giua) & Ham tien ich
# ------------------------------------------------------------
$script:BoxWidth = 62

function Get-Pad([int]$w = $script:BoxWidth) {
    try { $cw = $Host.UI.RawUI.WindowSize.Width } catch { $cw = 120 }
    return (' ' * [math]::Max(0, [math]::Floor(($cw - $w) / 2)))
}

function Draw-Header([string]$title) {
    Clear-Host
    $inner = $script:BoxWidth - 2
    $line  = '+' + ('-' * $inner) + '+'
    if ($title.Length -gt $inner - 2) { $title = $title.Substring(0, $inner - 2) }
    $left  = [math]::Floor(($inner - $title.Length) / 2)
    $mid   = (' ' * $left) + $title + (' ' * ($inner - $left - $title.Length))
    $pad   = Get-Pad

    Write-Host ''
    Write-Host ($pad + $line) -ForegroundColor Cyan
    Write-Host $pad -NoNewline
    Write-Host '|' -NoNewline -ForegroundColor Cyan
    Write-Host $mid -NoNewline -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host '|' -ForegroundColor Cyan
    Write-Host ($pad + $line) -ForegroundColor Cyan
    Write-Host ''
}

function Write-BoxSep([string]$label = '') {
    $inner = $script:BoxWidth - 2
    $txt = if ($label) { "--[ $label ]" } else { '' }
    Write-Host ((Get-Pad) + '+' + $txt.PadRight($inner, '-') + '+') -ForegroundColor DarkGray
}

function Write-BoxItem([string]$text, [string]$color = 'White') {
    $inner = $script:BoxWidth - 4
    if ($text.Length -gt $inner) { $text = $text.Substring(0, $inner) }
    Write-Host (Get-Pad) -NoNewline
    Write-Host '| ' -NoNewline -ForegroundColor DarkGray
    Write-Host $text.PadRight($inner) -NoNewline -ForegroundColor $color
    Write-Host ' |' -ForegroundColor DarkGray
}

function Read-Choice([string]$prompt = 'Lua chon cua ban') {
    Write-Host ''
    Write-Host ((Get-Pad) + "  $prompt > ") -NoNewline -ForegroundColor Yellow
    return (Read-Host)
}

function Write-Ok($m)   { Write-Host "  [OK] $m"  -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  [!] WARN: $m" -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "  [X] ERR: $m" -ForegroundColor Red }
function Write-Step($m) { Write-Host "`n  -> $m" -ForegroundColor Cyan }
function Pause-Back     { Write-Host ''; Read-Host '  Bam Enter de quay lai menu' | Out-Null }
function Confirm-YN($q) { return ((Read-Host "  $q (Y/N)") -match '^[yY]') }

function Wait-Countdown([int]$Seconds, [string]$Label) {
    Write-Host "  $Label - nhan S de bo qua cho" -ForegroundColor DarkGray
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        $left = [int][math]::Ceiling(($end - (Get-Date)).TotalSeconds)
        Write-Host -NoNewline ("`r    Con lai: {0:00}:{1:00}   " -f [math]::Floor($left / 60), ($left % 60))
        try {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq 'S') { break }
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    Write-Host ''
}

function Get-FreeC {
    return (Get-PSDrive ($env:SystemDrive.TrimEnd(':'))).Free
}
function Show-Freed($before) {
    $after = Get-FreeC
    Write-Host ''
    Write-Ok ("Trong o {0} truoc: {1} GB | sau: {2} GB | giai phong: {3} MB" -f `
        $env:SystemDrive, [math]::Round($before / 1GB, 2), [math]::Round($after / 1GB, 2), [math]::Round(($after - $before) / 1MB, 1))
}
function Clear-Folder($path) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------
# 1. NETWORK TOOLS
# ------------------------------------------------------------
function Select-PhysicalNic {
    $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    if ($nics.Count -eq 0) { $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue) }
    if ($nics.Count -eq 0) { Write-Err 'Khong tim thay card mang vat ly.'; return @() }
    if ($nics.Count -eq 1) {
        Write-Ok ("Tu dong chon: {0} ({1})" -f $nics[0].Name, $nics[0].InterfaceDescription)
        return $nics
    }
    Write-Host '  Tim thay nhieu card mang:'
    for ($i = 0; $i -lt $nics.Count; $i++) {
        Write-Host ("  {0}. {1}  [{2}]  {3}" -f ($i + 1), $nics[$i].Name, $nics[$i].Status, $nics[$i].InterfaceDescription)
    }
    $c = Read-Host '  Chon so (Enter = tat ca, 0 = huy)'
    if ($c -eq '0') { return @() }
    if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $nics.Count) { return @($nics[[int]$c - 1]) }
    return $nics
}

function Net-ResetIP {
    Draw-Header 'RESET IP & FLUSH DNS'
    Write-Host '  Thu tu: release -> cho -> flushdns -> cho -> registerdns -> cho -> renew'
    Write-Host ("  Moi lan cho: {0} giay. Mang se MAT trong luc chay." -f $WaitSeconds) -ForegroundColor Yellow
    if ($env:SESSIONNAME -like 'RDP*') {
        Write-Warn 'Ban dang ket noi qua RDP - release IP se lam MAT ket noi cua ban!'
    }
    if (-not (Confirm-YN 'Tiep tuc?')) { return }

    Write-Step 'ipconfig /release'
    ipconfig /release | Out-Null
    Wait-Countdown $WaitSeconds 'Cho sau release'

    Write-Step 'ipconfig /flushdns'
    ipconfig /flushdns | Out-Null
    Wait-Countdown $WaitSeconds 'Cho sau flushdns'

    Write-Step 'ipconfig /registerdns'
    ipconfig /registerdns | Out-Null
    Wait-Countdown $WaitSeconds 'Cho sau registerdns'

    Write-Step 'ipconfig /renew'
    ipconfig /renew | Out-Null
    Start-Sleep -Seconds 5

    Write-Host ''
    Write-Ok 'Hoan tat. Dia chi IP hien tai:'
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.PrefixOrigin -ne 'WellKnown' } |
        Format-Table InterfaceAlias, IPAddress -AutoSize
}

function Net-RefreshNic {
    Draw-Header 'REFRESH NETWORK INTERFACE'
    $sel = @(Select-PhysicalNic)
    if ($sel.Count -eq 0) { return }
    $names = @($sel | ForEach-Object { $_.Name })

    Write-Host ("  Se tat NIC, cho {0} giay roi bat lai." -f $WaitSeconds) -ForegroundColor Yellow
    if (-not (Confirm-YN 'Tiep tuc?')) { return }

    try {
        foreach ($n in $names) {
            Write-Step "Tat NIC: $n"
            cmd /c "netsh interface set interface name=`"$n`" admin=disabled" | Out-Null
        }
        Wait-Countdown $WaitSeconds 'Cho truoc khi bat lai NIC'
    }
    finally {
        foreach ($n in $names) {
            Write-Step "Bat NIC: $n"
            cmd /c "netsh interface set interface name=`"$n`" admin=enabled" | Out-Null
        }
    }
    Start-Sleep -Seconds 5
    Write-Host ''
    Get-NetAdapter -Name $names -ErrorAction SilentlyContinue | Format-Table Name, Status, LinkSpeed -AutoSize
}

function Net-ReconnectDrives {
    Draw-Header 'RECONNECT NETWORK DRIVE'
    Write-Host '  O mang map trong phien Admin KHAC phien nguoi dung thuong (UAC),' -ForegroundColor DarkGray
    Write-Host '  nen tool se chay phan nay duoi quyen nguoi dung thuong de Explorer thay duoc.' -ForegroundColor DarkGray
    Write-Host ''

    $child = @'
$log  = 'C:\Users\Public\nd_log.txt'
$done = 'C:\Users\Public\nd_done.flag'
Remove-Item $log, $done -Force -ErrorAction SilentlyContinue
$out = New-Object System.Collections.Generic.List[string]
try {
    $maps = @{}
    Get-SmbMapping -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.LocalPath) { $maps[$_.LocalPath.TrimEnd(':').ToUpper()] = $_.RemotePath }
    }
    Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object {
        $l = $_.PSChildName.ToUpper()
        $r = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).RemotePath
        if ($r -and -not $maps.ContainsKey($l)) { $maps[$l] = $r }
    }
    if ($maps.Count -eq 0) { $out.Add('Khong tim thay o mang nao dang map.') }
    foreach ($k in ($maps.Keys | Sort-Object)) {
        $remote = $maps[$k]
        $server = ($remote -replace '^\\\\', '').Split('\')[0]
        $out.Add(("{0}: -> {1}   (server: {2})" -f $k, $remote, $server))
        $null = cmd /c "net use ${k}: /delete /y < nul 2>&1"
        $res  = cmd /c "net use ${k}: `"$remote`" /persistent:yes < nul 2>&1"
        $out.Add('    ' + (($res | Out-String).Trim()))
    }
} catch { $out.Add('Loi: ' + $_.Exception.Message) }
$out | Set-Content $log -Encoding UTF8
'ok' | Set-Content $done
'@

    $childPath = 'C:\Users\Public\nd_reconnect.ps1'
    $logPath   = 'C:\Users\Public\nd_log.txt'
    $donePath  = 'C:\Users\Public\nd_done.flag'
    Remove-Item $logPath, $donePath -Force -ErrorAction SilentlyContinue
    Set-Content -Path $childPath -Value $child -Encoding ASCII

    Write-Step 'Dang tim va ket noi lai cac o mang...'
    $ok = $false
    try {
        & runas.exe /trustlevel:0x20000 "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $childPath" | Out-Null
        for ($i = 0; $i -lt 60; $i++) {
            if (Test-Path $donePath) { $ok = $true; break }
            Start-Sleep -Seconds 1
        }
    } catch {}

    if (-not $ok) {
        Write-Warn 'Khong chay duoc duoi quyen nguoi dung thuong, thu chay truc tiep trong phien Admin...'
        try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $childPath | Out-Null; $ok = (Test-Path $donePath) } catch {}
    }

    if ($ok -and (Test-Path $logPath)) {
        Write-Host ''
        Get-Content $logPath | ForEach-Object { Write-Host $_ }
        Write-Host ''
        Write-Ok 'Hoan tat.'
    } else {
        Write-Err 'Khong doc duoc ket qua.'
    }
    Remove-Item $childPath, $logPath, $donePath -Force -ErrorAction SilentlyContinue
}

function Resolve-Ipv4($hostOrIp) {
    if ($hostOrIp -match '^\d{1,3}(\.\d{1,3}){3}$') { return $hostOrIp }
    try {
        $a = [System.Net.Dns]::GetHostAddresses($hostOrIp) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        if ($a) { return $a.IPAddressToString }
    } catch {}
    return $null
}

function Net-FixVpnRoute {
    Draw-Header 'FIX ROUTE VPN'

    $vpnAlias  = $null
    $vpnServer = $null

    $conns  = @(Get-VpnConnection -ErrorAction SilentlyContinue) + @(Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue)
    $active = $conns | Where-Object { $_.ConnectionStatus -eq 'Connected' } | Select-Object -First 1

    if ($active) {
        $vpnAlias  = $active.Name
        $vpnServer = $active.ServerAddress
        Write-Ok "VPN Windows dang ket noi: $vpnAlias (server: $vpnServer)"
    }
    else {
        $pattern = '\bTAP\b|Wintun|WireGuard|OpenVPN|Fortinet|FortiClient|AnyConnect|Cisco|Juniper|Pulse Secure|GlobalProtect|Palo Alto|SonicWall|NordLynx|Proton|Check Point|VPN'
        $nic = Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' -and -not $_.HardwareInterface -and ($_.InterfaceDescription -match $pattern -or $_.Name -match 'VPN') } |
            Select-Object -First 1
        if (-not $nic) {
            Write-Err 'VPN chua ket noi: khong thay VPN Windows dang Connected hay card VPN dang Up.'
            return
        }
        $vpnAlias = $nic.Name
        Write-Ok "Card VPN dang hoat dong: $vpnAlias ($($nic.InterfaceDescription))"
        Write-Warn 'Day la VPN cua ben thu 3, khong tu doc duoc dia chi may chu.'
    }

    $vpnCfg = Get-NetIPConfiguration -InterfaceAlias $vpnAlias -ErrorAction SilentlyContinue
    if (-not $vpnCfg -or -not $vpnCfg.IPv4Address) {
        Write-Err "Khong lay duoc IP cua card VPN '$vpnAlias' (VPN chua nhan IP?)."
        return
    }
    $vpnIp  = ($vpnCfg.IPv4Address | Select-Object -First 1).IPAddress
    $vpnIdx = $vpnCfg.InterfaceIndex

    $serverIp = $null
    if ($vpnServer) { $serverIp = Resolve-Ipv4 $vpnServer }
    if (-not $serverIp) {
        $inp = Read-Host '  Nhap IP hoac hostname may chu VPN'
        if ($inp) { $serverIp = Resolve-Ipv4 $inp.Trim() }
    }
    if (-not $serverIp) { Write-Err 'Khong xac dinh duoc IP may chu VPN.'; return }

    $physIdx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | ForEach-Object { $_.ifIndex })
    $lan = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $physIdx -contains $_.InterfaceIndex -and $_.IPv4DefaultGateway -and $_.IPv4Address } |
        Sort-Object { (Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric } |
        Select-Object -First 1
    if (-not $lan) { Write-Err 'Khong tim thay card LAN vat ly nao co Gateway.'; return }

    $lanIp  = ($lan.IPv4Address | Select-Object -First 1).IPAddress
    $lanGw  = $lan.IPv4DefaultGateway.NextHop
    $lanIdx = $lan.InterfaceIndex

    Write-Host ''
    Write-Host ("  VPN        : {0}  | IP {1}  | IfIndex {2}" -f $vpnAlias, $vpnIp, $vpnIdx)
    Write-Host ("  May chu VPN: {0}" -f $serverIp)
    Write-Host ("  LAN vat ly : {0}  | IP {1}  | Gateway {2}  | IfIndex {3}" -f $lan.InterfaceAlias, $lanIp, $lanGw, $lanIdx)
    Write-Host ''

    Write-Step ("Them route {0}/32 -> Gateway {1} (qua {2})" -f $serverIp, $lanGw, $lan.InterfaceAlias)
    try {
        Get-NetRoute -DestinationPrefix "$serverIp/32" -ErrorAction SilentlyContinue |
            Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        New-NetRoute -DestinationPrefix "$serverIp/32" -InterfaceIndex $lanIdx -NextHop $lanGw `
            -RouteMetric 1 -PolicyStore ActiveStore -ErrorAction Stop | Out-Null
        Write-Ok 'Da them route.'
        Get-NetRoute -DestinationPrefix "$serverIp/32" -ErrorAction SilentlyContinue |
            Format-Table ifIndex, DestinationPrefix, NextHop, RouteMetric -AutoSize
        Write-Host '  Luu y: route nay mat sau khi khoi dong lai may.' -ForegroundColor DarkGray
    } catch {
        Write-Err ("Khong them duoc route: {0}" -f $_.Exception.Message)
    }
}

function Net-Diagnostics {
    Draw-Header 'KIEM TRA KET NOI MANG'
    $target = Read-Host '  Nhap IP/Domain can test (mac dinh: 8.8.8.8)'
    if ([string]::IsNullOrWhiteSpace($target)) { $target = '8.8.8.8' }

    Write-Step "Pinging $target..."
    Test-Connection -ComputerName $target -Count 4

    Write-Step "Tracert $target..."
    Test-NetConnection -ComputerName $target -TraceRoute
}

function Net-PortCheck {
    Draw-Header 'CONG DANG KET NOI (NETSTAT)'
    Get-NetTCPConnection | Where-Object State -eq 'Established' |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess -First 15 |
        Format-Table -AutoSize
}

# ---------------- NMAP ----------------
function Get-NmapPath {
    $c = Get-Command nmap.exe -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in @(
        "$env:ProgramFiles\Nmap\nmap.exe",
        "${env:ProgramFiles(x86)}\Nmap\nmap.exe"
    )) { if (Test-Path $p) { return $p } }
    $portable = Get-ChildItem $NmapPortableDir -Recurse -Filter nmap.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portable) { return $portable.FullName }
    return $null
}

function Install-Nmap {
    Write-Step 'Nmap chua co, dang cai dat...'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Insecure.Nmap -e --silent --accept-package-agreements --accept-source-agreements
        $p = Get-NmapPath
        if ($p) { return $p }
        Write-Warn 'winget khong cai duoc, thu tai ban portable...'
    }
    if ($NmapPortableUrl -match '<user>') {
        Write-Err 'Chua cau hinh $NmapPortableUrl (repo GitHub cua ban).'
        return $null
    }
    try {
        New-Item -ItemType Directory -Path $NmapPortableDir -Force | Out-Null
        $zip = Join-Path $env:TEMP 'nmap-portable.zip'
        Invoke-WebRequest -Uri $NmapPortableUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $NmapPortableDir -Force
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        return (Get-NmapPath)
    } catch {
        Write-Err ("Tai nmap that bai: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Get-LocalCidr {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.IPv4Address } | Select-Object -First 1
    if (-not $cfg) { return $null }
    $a = $cfg.IPv4Address | Select-Object -First 1
    return ('{0}/{1}' -f $a.IPAddress, $a.PrefixLength)
}

function Net-Nmap {
    Draw-Header 'NMAP - QUET MANG'
    $nmap = Get-NmapPath
    if (-not $nmap) { $nmap = Install-Nmap }
    if (-not $nmap) { return }
    Write-Ok "Nmap: $nmap"

    Write-Host ''
    Write-Host '  Chi quet he thong/mang ban duoc phep quan tri.' -ForegroundColor Yellow
    $cidr = Get-LocalCidr
    Write-Host ''
    Write-BoxSep 'Kieu quet'
    Write-BoxItem '[1] Tim thiet bi dang online trong LAN (ping sweep)'
    Write-BoxItem '[2] Quet nhanh cac port pho bien (-F)'
    Write-BoxItem '[3] Quet port + phien ban dich vu (-sV)'
    Write-BoxItem '[4] Tu nhap tham so nmap'
    Write-BoxItem '[0] Huy' 'Red'
    Write-BoxSep
    $mode = Read-Choice 'Chon'
    if ($mode -eq '0' -or [string]::IsNullOrWhiteSpace($mode)) { return }

    $defaultTarget = if ($cidr) { $cidr } else { '192.168.1.0/24' }
    $target = Read-Host ("  Nhap IP / domain / dai mang (Enter = {0})" -f $defaultTarget)
    if ([string]::IsNullOrWhiteSpace($target)) { $target = $defaultTarget }
    if ($target -notmatch '^[A-Za-z0-9\.\-:/,\s]+$') { Write-Err 'Target chua ky tu khong hop le.'; return }

    $targets = @($target -split '\s+' | Where-Object { $_ })

    switch ($mode) {
        '1' { $nmapArgs = @('-sn') + $targets }
        '2' { $nmapArgs = @('-F', '-T4') + $targets }
        '3' { $nmapArgs = @('-sV', '-T4') + $targets }
        '4' {
            $custom = Read-Host '  Nhap tham so (VD: -p 22,80,443 -sV)'
            $nmapArgs = @($custom -split '\s+' | Where-Object { $_ }) + $targets
        }
        default { Write-Warn 'Lua chon khong hop le.'; return }
    }

    $outFile = $null
    if (Confirm-YN 'Luu ket qua ra Desktop?') {
        $outFile = Join-Path $env:USERPROFILE ("Desktop\nmap_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $nmapArgs += @('-oN', $outFile)
    }

    Write-Step ("nmap {0}" -f ($nmapArgs -join ' '))
    & $nmap @nmapArgs

    if ($outFile -and (Test-Path $outFile)) { Write-Ok "Da luu: $outFile" }
}

function Menu-Network {
    while ($true) {
        Draw-Header 'NETWORK FIX & DIAGNOSTICS'
        Write-BoxSep 'Chuc nang chinh'
        Write-BoxItem '[1] Reset IP & Flush DNS (Go nghen mang)'
        Write-BoxItem '[2] Reset Network Card (Disable/Enable)'
        Write-BoxItem '[3] Reconnect Network Drive (quyen User)'
        Write-BoxItem '[4] Fix Route VPN (Dinh tuyen cho VPN)'
        Write-BoxSep 'Chuan doan IT'
        Write-BoxItem '[5] Ping / Tracert kiem tra ket noi' 'Yellow'
        Write-BoxItem '[6] Cong dang mo (Open Ports & Connections)' 'Yellow'
        Write-BoxItem '[7] Nmap - Quet thiet bi / port trong mang' 'Cyan'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai Menu chinh' 'Red'
        Write-BoxSep

        switch (Read-Choice) {
            '1' { Net-ResetIP; Pause-Back }
            '2' { Net-RefreshNic; Pause-Back }
            '3' { Net-ReconnectDrives; Pause-Back }
            '4' { Net-FixVpnRoute; Pause-Back }
            '5' { Net-Diagnostics; Pause-Back }
            '6' { Net-PortCheck; Pause-Back }
            '7' { Net-Nmap; Pause-Back }
            '0' { return }
        }
    }
}

# ------------------------------------------------------------
# 2. SYSTEM CLEANUP & REPAIR
# ------------------------------------------------------------
function Clean-Quick {
    Draw-Header 'CLEAN UP - DON NHANH'
    $before = Get-FreeC

    Write-Step 'File tam nguoi dung';        Clear-Folder $env:TEMP
    Write-Step 'File tam Windows';           Clear-Folder "$env:SystemRoot\Temp"
    Write-Step 'Prefetch';                   Clear-Folder "$env:SystemRoot\Prefetch"

    Write-Step 'Cache Windows Update'
    Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
    Clear-Folder "$env:SystemRoot\SoftwareDistribution\Download"
    Start-Service bits, wuauserv -ErrorAction SilentlyContinue

    Write-Step 'Cache thumbnail va icon'
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue

    Write-Step 'Cache DNS'
    ipconfig /flushdns | Out-Null

    Write-Step 'Bao cao loi va log cu'
    Clear-Folder "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
    Clear-Folder "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
    Remove-Item "$env:SystemRoot\Logs\CBS\*.log" -Force -ErrorAction SilentlyContinue

    Write-Step 'Thung rac'
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue

    Show-Freed $before
}

function Clean-Deep {
    Draw-Header 'CLEAN UP - DON SAU'
    Write-Host '  Gom: file tam moi user, crash dump, shader cache, Delivery Optimization,'
    Write-Host '  va DISM StartComponentCleanup (co the mat vai phut).' -ForegroundColor Yellow
    if (-not (Confirm-YN 'Tiep tuc?')) { return }
    $before = Get-FreeC

    Write-Step 'File tam cua tat ca user'
    Get-ChildItem "$env:SystemDrive\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Clear-Folder "$($_.FullName)\AppData\Local\Temp"
        Clear-Folder "$($_.FullName)\AppData\Local\CrashDumps"
    }

    Write-Step 'Crash dump / Minidump'
    Clear-Folder "$env:SystemRoot\Minidump"
    Remove-Item "$env:SystemRoot\MEMORY.DMP" -Force -ErrorAction SilentlyContinue

    Write-Step 'Shader cache (DirectX / NVIDIA / AMD)'
    Clear-Folder "$env:LOCALAPPDATA\D3DSCache"
    Clear-Folder "$env:LOCALAPPDATA\NVIDIA\DXCache"
    Clear-Folder "$env:LOCALAPPDATA\NVIDIA\GLCache"
    Clear-Folder "$env:LOCALAPPDATA\AMD\DxCache"

    Write-Step 'Delivery Optimization cache'
    Clear-Folder "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"

    Write-Step 'DISM StartComponentCleanup (WinSxS)'
    dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet | Out-Null

    Write-Step 'Thung rac'
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue

    if (Test-Path "$env:SystemDrive\Windows.old") {
        Write-Warn 'Phat hien thu muc Windows.old (ban Windows cu). Xoa bang: Settings > System > Storage > Temporary files.'
    }
    Show-Freed $before
}

function Clean-BrowserApp {
    Draw-Header 'CLEAN UP - CACHE BROWSER & TEAMS'
    Write-Host '  Chi xoa cache. KHONG xoa cookie, mat khau, lich su, dang nhap.' -ForegroundColor Green
    if (Confirm-YN 'Dong Chrome/Edge/Brave/Firefox/Teams dang mo de xoa sach hon?') {
        'chrome', 'msedge', 'brave', 'firefox', 'Teams', 'ms-teams' | ForEach-Object {
            Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
    }
    $before = Get-FreeC

    Write-Step 'Chrome / Edge / Brave'
    $roots = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    )
    $subs = 'Cache', 'Code Cache', 'GPUCache', 'GrShaderCache', 'ShaderCache', 'Service Worker\CacheStorage', 'Service Worker\ScriptCache'
    foreach ($r in $roots) {
        if (Test-Path $r) {
            Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^(Default|Profile \d+|Guest Profile)$' } |
                ForEach-Object { foreach ($s in $subs) { Clear-Folder (Join-Path $_.FullName $s) } }
        }
    }

    Write-Step 'Firefox'
    Get-ChildItem "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Clear-Folder (Join-Path $_.FullName 'cache2') }

    Write-Step 'Office file cache va Teams'
    Clear-Folder "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
    foreach ($s in 'Cache', 'Code Cache', 'GPUCache', 'blob_storage', 'tmp', 'Service Worker\CacheStorage') {
        Clear-Folder (Join-Path "$env:APPDATA\Microsoft\Teams" $s)
    }

    Show-Freed $before
}

function Clean-BrowserAppWithBackup {
    Draw-Header 'DON CACHE BROWSER (CO BACKUP PROFILE)'

    $backupRoot = "$env:USERPROFILE\Desktop\Browser_Backups_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "  [i] Du lieu backup se duoc luu tai: $backupRoot" -ForegroundColor Cyan

    if (Confirm-YN 'Dong Chrome/Edge/Brave/Firefox truoc khi Backup & Xoa?') {
        'chrome', 'msedge', 'brave', 'firefox', 'Teams', 'ms-teams' | ForEach-Object {
            Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
    }

    $before = Get-FreeC

    $browsers = @(
        @{ Name = 'Chrome'; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
        @{ Name = 'Edge';   Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
        @{ Name = 'Brave';  Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" }
    )

    $importantFiles = @('Bookmarks', 'History', 'Favicons', 'Login Data', 'Web Data', 'Preferences')
    $cacheSubs = @('Cache', 'Code Cache', 'GPUCache', 'GrShaderCache', 'ShaderCache', 'Service Worker\CacheStorage', 'Service Worker\ScriptCache')

    foreach ($b in $browsers) {
        if (Test-Path $b.Path) {
            Write-Step "Dang xu ly trinh duyet: $($b.Name)"
            $profiles = Get-ChildItem $b.Path -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^(Default|Profile \d+|Guest Profile)$' }

            foreach ($p in $profiles) {
                $destDir = Join-Path $backupRoot "$($b.Name)\$($p.Name)"
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null

                foreach ($file in $importantFiles) {
                    $srcFile = Join-Path $p.FullName $file
                    if (Test-Path $srcFile) {
                        Copy-Item -Path $srcFile -Destination $destDir -Force -ErrorAction SilentlyContinue
                    }
                }
                Write-Ok "Da backup du lieu cot loi ($($p.Name))"

                foreach ($s in $cacheSubs) {
                    Clear-Folder (Join-Path $p.FullName $s)
                }
            }
        }
    }

    $ffPath = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffPath) {
        Write-Step 'Dang xu ly Firefox'
        Get-ChildItem $ffPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $ffBackupDir = Join-Path $backupRoot "Firefox\$($_.Name)"
            New-Item -ItemType Directory -Path $ffBackupDir -Force | Out-Null
            if (Test-Path "$($_.FullName)\places.sqlite") {
                Copy-Item -Path "$($_.FullName)\places.sqlite" -Destination $ffBackupDir -Force -ErrorAction SilentlyContinue
                Write-Ok 'Da backup Bookmarks/History Firefox'
            }
            Clear-Folder (Join-Path $_.FullName 'cache2')
        }
    }

    Show-Freed $before
    Write-Host ''
    Write-Ok 'Hoan tat! Thu muc backup tai Desktop:'
    Write-Host "  -> $backupRoot" -ForegroundColor Yellow
}

function Clean-Repair {
    Draw-Header 'KIEM TRA & SUA FILE HE THONG'
    Write-Host '  Chay DISM RestoreHealth roi sfc /scannow. Co the mat 10-30 phut.' -ForegroundColor Yellow
    if (-not (Confirm-YN 'Tiep tuc?')) { return }
    Write-Step 'DISM /Online /Cleanup-Image /RestoreHealth'
    dism.exe /Online /Cleanup-Image /RestoreHealth
    Write-Step 'sfc /scannow'
    sfc.exe /scannow
}

function Disk-Chkdsk {
    Draw-Header 'KIEM TRA O DIA (CHKDSK)'
    Write-Warn 'Che do Read-Only: chi quet doc loi o C:, khong sua.'
    if (Confirm-YN 'Ban co muon quet doc loi o C (Read-Only)?') {
        chkdsk.exe C:
    }
}

function Show-DiskUsage {
    Draw-Header 'FOLDER CHIEM NHIEU DUNG LUONG'
    Write-Host '  Dang quet, co the mat 1-3 phut...' -ForegroundColor DarkGray
    function Top-Folders($root) {
        Write-Host "`n  Top thu muc trong $root" -ForegroundColor Cyan
        Get-ChildItem $root -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
            ForEach-Object {
                Write-Host -NoNewline ("`r    Dang quet: {0,-50}" -f $_.Name)
                $sum = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                [pscustomobject]@{ Folder = $_.FullName; GB = [math]::Round($sum / 1GB, 2) }
            } | Sort-Object GB -Descending | Select-Object -First 12 | Format-Table -AutoSize
    }
    Top-Folders "$env:SystemDrive\"
    Top-Folders $env:USERPROFILE
}

function Menu-Cleanup {
    while ($true) {
        Draw-Header 'DON DEP & SUA LOI HE THONG'
        Write-BoxSep 'Toi uu dung luong'
        Write-BoxItem '[1] Don nhanh (Temp, Prefetch, DNS, Recycle Bin)'
        Write-BoxItem '[2] Don sau (Crash Dumps, WinSxS, Temp Users)'
        Write-BoxItem '[3] Chi xoa Cache Browsers & Teams/Office'
        Write-BoxItem '[4] Vua BACKUP vua xoa Cache Browsers (An toan)' 'Green'
        Write-BoxItem '[5] Phan tich Folder chiem dung luong lon'
        Write-BoxSep 'Sua loi He dieu hanh'
        Write-BoxItem '[6] Sua loi System Files (DISM & SFC Scannow)' 'Yellow'
        Write-BoxItem '[7] Kiem tra o dia (CHKDSK)' 'Yellow'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai Menu chinh' 'Red'
        Write-BoxSep

        switch (Read-Choice) {
            '1' { Clean-Quick; Pause-Back }
            '2' { Clean-Deep; Pause-Back }
            '3' { Clean-BrowserApp; Pause-Back }
            '4' { Clean-BrowserAppWithBackup; Pause-Back }
            '5' { Show-DiskUsage; Pause-Back }
            '6' { Clean-Repair; Pause-Back }
            '7' { Disk-Chkdsk; Pause-Back }
            '0' { return }
        }
    }
}

# ------------------------------------------------------------
# 3. IT TOOLS & DIAGNOSTICS
# ------------------------------------------------------------
function Office-Check {
    Draw-Header 'KIEM TRA & GO KEY OFFICE'

    $roots = @("$env:ProgramFiles\Microsoft Office", "${env:ProgramFiles(x86)}\Microsoft Office") | Where-Object { $_ -and (Test-Path $_) }
    $files = @()
    foreach ($r in $roots) {
        $files += Get-ChildItem $r -Recurse -Filter ospp.vbs -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
    $files = @($files | Select-Object -Unique)
    if ($files.Count -eq 0) { Write-Err 'Khong tim thay ospp.vbs (Office chua cai hoac khong phai ban desktop).'; return }

    $found = @()
    foreach ($f in $files) {
        Write-Host ("  == {0}" -f $f) -ForegroundColor Cyan
        $lines = @(& cscript.exe //nologo $f /dstatus 2>&1 | ForEach-Object { "$_" })
        $lines | ForEach-Object { Write-Host "  $_" }

        $name = ''; $status = ''
        foreach ($l in $lines) {
            if     ($l -match '(?i)^\s*LICENSE NAME:\s*(.+)$')   { $name   = $Matches[1].Trim() }
            elseif ($l -match '(?i)^\s*LICENSE STATUS:\s*(.+)$') { $status = $Matches[1].Trim() }
            elseif ($l -match '(?i)product key:\s*([A-Za-z0-9]{5})\s*$') {
                $found += [pscustomobject]@{ Key = $Matches[1].ToUpper(); Name = $name; Status = $status; File = $f }
            }
        }
    }

    Write-Host ''
    if ($found.Count -gt 0) {
        Write-Host '  Key dang cai:' -ForegroundColor Cyan
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host ("  {0}. {1}   {2}   {3}" -f ($i + 1), $found[$i].Key, $found[$i].Status, $found[$i].Name)
        }
    } else {
        Write-Warn 'Khong tu doc duoc danh sach key (co the do Office khac ngon ngu). Van co the nhap tay.'
    }

    Write-Host ''
    $in = Read-Host '  Go key: nhap so thu tu / A = tat ca / 5 ky tu cuoi cua key (cach nhau bang dau cach). Enter = bo qua'
    if ([string]::IsNullOrWhiteSpace($in)) { return }

    $jobs = @()
    foreach ($t in ($in -split '[\s,;]+' | Where-Object { $_ })) {
        if ($t -match '^[aA]$') {
            foreach ($x in $found) { $jobs += @{ Key = $x.Key; File = $x.File } }
        }
        elseif ($t -match '^\d{1,2}$') {
            $n = [int]$t
            if ($n -ge 1 -and $n -le $found.Count) { $jobs += @{ Key = $found[$n - 1].Key; File = $found[$n - 1].File } }
            else { Write-Warn "Bo qua so khong hop le: $t" }
        }
        elseif ($t -match '^[A-Za-z0-9]{5}$') {
            $m = $found | Where-Object { $_.Key -eq $t.ToUpper() } | Select-Object -First 1
            $file = if ($m) { $m.File } else { $files[0] }
            $jobs += @{ Key = $t.ToUpper(); File = $file }
        }
        else { Write-Warn "Bo qua gia tri khong hop le: $t" }
    }
    if ($jobs.Count -eq 0) { return }

    Write-Host ''
    Write-Host ('  Se go key: ' + (($jobs | ForEach-Object { $_.Key }) -join ', ')) -ForegroundColor Yellow
    if (-not (Confirm-YN 'Xac nhan go (khong hoan tac duoc)?')) { return }

    foreach ($j in $jobs) {
        Write-Step ("unpkey: {0}" -f $j.Key)
        & cscript.exe //nologo $j.File "/unpkey:$($j.Key)" 2>&1 | ForEach-Object { Write-Host "  $_" }
    }
}

function Win-LicenseCheck {
    Draw-Header 'KIEM TRA BAN QUYEN WINDOWS'
    cscript //nologo $env:SystemRoot\System32\slmgr.vbs /dli
    cscript //nologo $env:SystemRoot\System32\slmgr.vbs /xpr
}

function Sys-HardwareInfo {
    [CmdletBinding()]
    param()

    # 1. Tính toán chiều rộng Console và lề để căn giữa bảng
    $hostWidth = 80
    try {
        if ($Host.UI.RawUI.WindowSize.Width -gt 0) {
            $hostWidth = $Host.UI.RawUI.WindowSize.Width
        }
    } catch {}

    $col1Width = 22
    $col2Width = 48
    $boxWidth  = $col1Width + $col2Width + 7
    $indent    = [math]::Max(0, [int](($hostWidth - $boxWidth) / 2))
    $spaces    = " " * $indent

    # Khung viền Unicode
    $borderTop    = "$spaces┌" + ("─" * ($col1Width + 2)) + "┬" + ("─" * ($col2Width + 2)) + "┐"
    $borderBottom = "$spaces└" + ("─" * ($col1Width + 2)) + "┴" + ("─" * ($col2Width + 2)) + "┘"
    $borderHeader = "$spaces╞" + ("═" * ($col1Width + 2)) + "╪" + ("═" * ($col2Width + 2)) + "╡"

    # Helper: In dòng thông tin key-value
    function Write-Row {
        param(
            [string]$Key,
            [string]$Value,
            [ConsoleColor]$KeyColor = [ConsoleColor]::Cyan,
            [ConsoleColor]$ValueColor = [ConsoleColor]::White
        )
        $kStr = if ($Key.Length -gt $col1Width) { $Key.Substring(0, $col1Width - 3) + "..." } else { $Key }
        $vStr = if ($Value.Length -gt $col2Width) { $Value.Substring(0, $col2Width - 3) + "..." } else { $Value }

        Write-Host "$spaces│ " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($kStr.PadRight($col1Width))" -NoNewline -ForegroundColor $KeyColor
        Write-Host " │ " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($vStr.PadRight($col2Width))" -NoNewline -ForegroundColor $ValueColor
        Write-Host " │" -ForegroundColor DarkGray
    }

    # Helper: In phân đoạn tiêu đề
    function Write-Section {
        param([string]$Title)
        $totalInner = $col1Width + $col2Width + 3
        $padded = " [ $Title ] ".PadRight($totalInner, "═")
        $padded = $padded.PadLeft([int](($totalInner + $padded.Length)/2), "═")

        Write-Host "$spaces╞" -NoNewline -ForegroundColor DarkGray
        Write-Host "$padded" -NoNewline -ForegroundColor Yellow
        Write-Host "╡" -ForegroundColor DarkGray
    }

    # 2. Thu thập dữ liệu phần cứng chi tiết
    $cs   = Get-CimInstance Win32_ComputerSystem
    $os   = Get-CimInstance Win32_OperatingSystem
    $bios = Get-CimInstance Win32_BIOS
    $mb   = Get-CimInstance Win32_BaseBoard
    $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1

    # RAM Details
    $ramModules = Get-CimInstance Win32_PhysicalMemory
    $ramSlotsObj = Get-CimInstance Win32_PhysicalMemoryArray | Select-Object -ExpandProperty MemoryDevices -ErrorAction SilentlyContinue
    $totalSlots = if ($ramSlotsObj) { ($ramSlotsObj | Measure-Object -Sum).Sum } else { $ramModules.Count }
    $usedSlots = $ramModules.Count
    $ramTotalGB = [math]::Round(($ramModules | Measure-Object Capacity -Sum).Sum / 1GB, 2)
    $ramSpeed = ($ramModules | Select-Object -ExpandProperty Speed | Sort-Object -Descending | Select-Object -First 1)
    
    $ramTypeRaw = $ramModules | Select-Object -First 1 -ExpandProperty SMBIOSMemoryType
    if (-not $ramTypeRaw -or $ramTypeRaw -eq 0) { $ramTypeRaw = $ramModules | Select-Object -First 1 -ExpandProperty MemoryType }
    $ramType = switch ($ramTypeRaw) {
        20 { "DDR" } 21 { "DDR2" } 24 { "DDR3" } 26 { "DDR4" } 30 { "LPDDR4" } 34 { "DDR5" } 35 { "LPDDR5" } default { "DDR / Standard" }
    }

    # Cache & CPU Clock
    $l2MB = if ($cpu.L2CacheSize) { "$([math]::Round($cpu.L2CacheSize / 1024, 2)) MB" } else { "N/A" }
    $l3MB = if ($cpu.L3CacheSize) { "$([math]::Round($cpu.L3CacheSize / 1024, 2)) MB" } else { "N/A" }
    $maxClock = "$([math]::Round($cpu.MaxClockSpeed / 1000, 2)) GHz ($($cpu.MaxClockSpeed) MHz)"

    # GPU & Storage
    $gpus  = Get-CimInstance Win32_VideoController
    $disks = Get-CimInstance Win32_DiskDrive

    # 3. Xuất bảng giao diện
    Write-Host ""
    Write-Host $borderTop -ForegroundColor DarkGray
    
    # Title Header
    $titleStr = "THONG TIN PHAN CUNG HE THONG (CPU-Z)"
    $titlePadded = $titleStr.PadRight($col1Width + $col2Width + 3)
    $titlePadded = $titlePadded.PadLeft([int](($col1Width + $col2Width + 3 + $titlePadded.Length)/2))
    Write-Host "$spaces│ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$titlePadded" -NoNewline -ForegroundColor Green
    Write-Host " │" -ForegroundColor DarkGray

    # SYSTEM & MOTHERBOARD
    Write-Section "BO MACH & HE THONG"
    Write-Row "Computer Name" "$($cs.DNSHostName)"
    Write-Row "OS Version" "$($os.Caption) ($($os.BuildNumber))"
    Write-Row "System Model" "$($cs.Manufacturer) $($cs.Model)"
    Write-Row "Serial Number" "$($bios.SerialNumber)" -KeyColor Yellow -ValueColor Yellow
    Write-Row "Motherboard" "$($mb.Manufacturer) $($mb.Product) (Rev $($mb.Version))"
    $biosDate = if ($bios.ReleaseDate -is [datetime]) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { $bios.ReleaseDate }
    Write-Row "BIOS Version" "$($bios.SMBIOSBIOSVersion) ($biosDate)"

    # CPU
    Write-Section "BO VI XULY (CPU)"
    Write-Row "Processor" "$($cpu.Name.Trim())"
    Write-Row "Socket / Package" "$($cpu.SocketDesignation)"
    Write-Row "Cores / Threads" "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads"
    Write-Row "Max Clock Speed" "$maxClock"
    Write-Row "L2 Cache" "$l2MB"
    Write-Row "L3 Cache" "$l3MB"

    # RAM
    Write-Section "BO NHO (RAM)"
    Write-Row "Total Capacity" "$ramTotalGB GB"
    Write-Row "Memory Type" "$ramType"
    Write-Row "DRAM Speed" "$ramSpeed MHz"
    Write-Row "Slots Occupied" "$usedSlots / $totalSlots slots"

    # GPU
    Write-Section "CARD DO HOA (GPU)"
    $gpuIdx = 1
    foreach ($gpu in $gpus) {
        $vramGB = if ($gpu.AdapterRAM) { "$([math]::Round($gpu.AdapterRAM / 1GB, 2)) GB" } else { "N/A" }
        $label = if ($gpus.Count -gt 1) { "GPU #$gpuIdx" } else { "GPU Model" }
        Write-Row $label "$($gpu.Name)"
        Write-Row "  └─ Driver & VRAM" "v$($gpu.DriverVersion) | VRAM: $vramGB" -KeyColor Gray
        $gpuIdx++
    }

    # STORAGE
    Write-Section "O CUNG (STORAGE)"
    $diskIdx = 1
    foreach ($disk in $disks) {
        $diskGB = if ($disk.Size) { [math]::Round($disk.Size / 1GB, 2) } else { 0 }
        $label = "Disk #$diskIdx"
        Write-Row $label "$($disk.Model)"
        Write-Row "  └─ Specs" "$diskGB GB ($($disk.InterfaceType) / $($disk.MediaType))" -KeyColor Gray
        $diskIdx++
    }

    Write-Host $borderBottom -ForegroundColor DarkGray
    Write-Host ""
}

function Fix-PrintSpooler {
    Draw-Header 'RESTART PRINT SPOOLER'
    Write-Step 'Dang dung dich vu Spooler va xoa spool temp...'
    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Clear-Folder "$env:SystemRoot\System32\spool\PRINTERS"
    Start-Service -Name Spooler
    Write-Ok 'Da khoi dong lai Print Spooler thanh cong!'
}

function Toggle-RDP {
    Draw-Header 'QUAN LY REMOTE DESKTOP (RDP)'
    $rdpKey = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
    $rdp = (Get-ItemProperty -Path $rdpKey).fDenyTSConnections
    if ($rdp -eq 1) {
        Write-Host '  Trang thai RDP hien tai: ' -NoNewline; Write-Host 'DANG TAT' -ForegroundColor Red
        if (Confirm-YN 'Ban co muon BAT Remote Desktop?') {
            Set-ItemProperty -Path $rdpKey -Name 'fDenyTSConnections' -Value 0
            Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'
            Write-Ok 'Da BAT Remote Desktop thanh cong!'
        }
    } else {
        Write-Host '  Trang thai RDP hien tai: ' -NoNewline; Write-Host 'DANG BAT' -ForegroundColor Green
        if (Confirm-YN 'Ban co muon TAT Remote Desktop?') {
            Set-ItemProperty -Path $rdpKey -Name 'fDenyTSConnections' -Value 1
            Write-Ok 'Da TAT Remote Desktop!'
        }
    }
}

function Menu-ITTools {
    while ($true) {
        Draw-Header 'CONG CU IT & HE THONG'
        Write-BoxSep 'Ban quyen & Thong tin'
        Write-BoxItem '[1] Kiem tra & Go Key Office (OSPP.vbs)'
        Write-BoxItem '[2] Kiem tra Ban quyen Windows (SLMGR)'
        Write-BoxItem '[3] Xem Thong tin Phan cung & BIOS'
        Write-BoxSep 'Dich vu & Khoi dong'
        Write-BoxItem '[4] Restart Print Spooler (Sua loi may in)' 'Green'
        Write-BoxItem '[5] Bat / Tat Remote Desktop (RDP)' 'Green'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai Menu chinh' 'Red'
        Write-BoxSep

        switch (Read-Choice) {
            '1' { Office-Check; Pause-Back }
            '2' { Win-LicenseCheck; Pause-Back }
            '3' { Sys-HardwareInfo; Pause-Back }
            '4' { Fix-PrintSpooler; Pause-Back }
            '5' { Toggle-RDP; Pause-Back }
            '0' { return }
        }
    }
}

# ------------------------------------------------------------
# 4. SYSINTERNALS LIVE
# ------------------------------------------------------------
function Menu-Sysinternals {
    $basePath = '\\live.sysinternals.com\tools'
    while ($true) {
        Draw-Header 'SYSINTERNALS TOOLS (LIVE)'
        Write-BoxSep 'Chay tu live.sysinternals.com'
        Write-BoxItem '[1] Process Explorer - Task Manager nang cao'
        Write-BoxItem '[2] Process Monitor  - Theo doi File/Registry'
        Write-BoxItem '[3] Autoruns         - Quan ly Startup'
        Write-BoxItem '[4] TCPView          - Xem port nang cao'
        Write-BoxItem '[5] BgInfo           - Thong tin Desktop'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai Menu chinh' 'Red'
        Write-BoxSep

        $exe = $null
        switch (Read-Choice) {
            '1' { $exe = 'procexp.exe' }
            '2' { $exe = 'procmon.exe' }
            '3' { $exe = 'autoruns.exe' }
            '4' { $exe = 'tcpview.exe' }
            '5' { $exe = 'bginfo.exe' }
            '0' { return }
        }
        if ($exe) {
            Write-Step "Dang mo $exe ..."
            try { Start-Process "$basePath\$exe" -ErrorAction Stop }
            catch { Write-Err ("Khong mo duoc {0}: {1}" -f $exe, $_.Exception.Message); Write-Host '  Kiem tra dich vu WebClient da chay chua.' -ForegroundColor DarkGray; Pause-Back }
        }
    }
}

# ============================================================
#  MENU CHINH
# ============================================================
$quit = $false
while (-not $quit) {
    Draw-Header 'IT SUPPORT TOOLKIT'
    Write-BoxSep 'Danh muc'
    Write-BoxItem '[1] NETWORK FIX       - Sua loi mang, IP, VPN, Nmap'
    Write-BoxItem '[2] SYSTEM CLEANUP    - Don dep Temp, Cache, WinSxS'
    Write-BoxItem '[3] IT & SYSTEM TOOLS - License Office, Spooler, RDP'
    Write-BoxItem '[4] SYSINTERNALS LIVE - Process Explorer, Autoruns'
    Write-BoxSep
    Write-BoxItem '[0] THOAT' 'Red'
    Write-BoxSep

    switch (Read-Choice 'Chon danh muc (0-4)') {
        '1' { Menu-Network }
        '2' { Menu-Cleanup }
        '3' { Menu-ITTools }
        '4' { Menu-Sysinternals }
        '0' { $quit = $true }
        default { Write-Warn 'Lua chon khong hop le!'; Start-Sleep -Seconds 1 }
    }
}
