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
    if ($env:SESSIONNAME -like 'RDP*') {
        $rdpIf = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
        if ($rdpIf -and ($sel | Where-Object { $_.ifIndex -eq $rdpIf.InterfaceIndex })) {
            Write-Err 'Da chan reset adapter dang mang Default Gateway trong phien RDP de tranh mat ket noi.'
            return
        }
    }

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


# ---------------- QUICK DNS SWITCH ----------------
function Net-ChangeDNS {
    Draw-Header 'CHANGE DNS - QUICK SWITCH'

    $dnsProfiles = @{
        '1' = @{ Name = 'Cloudflare'; Primary = '1.1.1.1'; Secondary = '1.0.0.1' }
        '2' = @{ Name = 'Google';     Primary = '8.8.8.8'; Secondary = '8.8.4.4' }
        '3' = @{ Name = 'NextDNS';    Primary = '45.90.28.0'; Secondary = '45.90.30.0' }
        '4' = @{ Name = 'AdGuard';    Primary = '94.140.14.14'; Secondary = '94.140.15.15' }
        '5' = @{ Name = 'Quad9';      Primary = '9.9.9.9'; Secondary = '149.112.112.112' }
        '6' = @{ Name = 'OpenDNS';    Primary = '208.67.222.222'; Secondary = '208.67.220.220' }
    }

    Write-BoxSep 'DNS Provider'
    Write-BoxItem '[1] Cloudflare       1.1.1.1 / 1.0.0.1'
    Write-BoxItem '[2] Google           8.8.8.8 / 8.8.4.4'
    Write-BoxItem '[3] NextDNS          45.90.28.0 / 45.90.30.0'
    Write-BoxItem '[4] AdGuard DNS      94.140.14.14 / 94.140.15.15'
    Write-BoxItem '[5] Quad9            9.9.9.9 / 149.112.112.112'
    Write-BoxItem '[6] OpenDNS          208.67.222.222 / 208.67.220.220'
    Write-BoxItem '[7] Restore Automatic DNS (DHCP)' 'Yellow'
    Write-BoxItem '[0] Huy' 'Red'
    Write-BoxSep

    $choice = Read-Choice 'Chon DNS'
    if ($choice -eq '0' -or [string]::IsNullOrWhiteSpace($choice)) { return }
    if ($choice -notmatch '^[1-7]$') { Write-Warn 'Lua chon khong hop le.'; return }

    $nextDnsId = $null
    if ($choice -eq '3') {
        Write-Host ''
        Write-Host '  NextDNS: de trong = DNS IPv4 thong thuong (can Link IP tren dashboard NextDNS).' -ForegroundColor DarkGray
        Write-Host '  Nhap Configuration ID = cau hinh DoH ca nhan tren Windows 11.' -ForegroundColor DarkGray
        $nextDnsId = (Read-Host '  NextDNS Configuration ID (Enter = bo qua DoH)').Trim()
        if ($nextDnsId -and $nextDnsId -notmatch '^[A-Za-z0-9]{6}$') {
            Write-Err 'Configuration ID khong hop le (NextDNS ID thuong gom 6 ky tu).'
            return
        }
        if ($nextDnsId -and [Environment]::OSVersion.Version.Build -lt 22000) {
            Write-Warn 'Windows nay khong duoc tool bat DoH native. Se khong ap dung ID; hay dung NextDNS app/CLI hoac de trong de dung DNS IPv4.'
            return
        }
    }

    $sel = @(Select-PhysicalNic)
    if ($sel.Count -eq 0) { return }

    Write-Host ''
    Write-BoxSep 'DNS hien tai'
    foreach ($nic in $sel) {
        $current = @(Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            ForEach-Object { $_.ServerAddresses } | Where-Object { $_ })
        Write-Host ('  {0}: {1}' -f $nic.Name, $(if ($current.Count) { $current -join ', ' } else { '(chua co DNS IPv4)' }))
    }

    if ($choice -eq '7') {
        $label = 'Automatic DNS (DHCP)'
    } else {
        $profile = $dnsProfiles[$choice]
        $label = $profile.Name
    }
    Write-Host ''
    Write-Host ('  Se ap dung: {0}' -f $label) -ForegroundColor Yellow
    if ($choice -ne '7') {
        Write-Host ('  IPv4 DNS: {0}, {1}' -f $profile.Primary, $profile.Secondary)
        if ($choice -eq '3' -and $nextDnsId) { Write-Host ('  DoH template: https://dns.nextdns.io/{0}' -f $nextDnsId) -ForegroundColor Cyan }
    }
    Write-Warn 'Chi thay DNS IPv4; khong thay IP, Gateway hay DNS IPv6.'
    if (-not (Confirm-YN 'Xac nhan ap dung?')) { return }

    foreach ($nic in $sel) {
        try {
            if ($choice -eq '7') {
                Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ResetServerAddresses -ErrorAction Stop
                Write-Ok ("{0}: da tra DNS ve DHCP." -f $nic.Name)
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses @($profile.Primary, $profile.Secondary) -ErrorAction Stop
                Write-Ok ("{0}: da doi DNS sang {1}." -f $nic.Name, $profile.Name)
            }
        } catch {
            Write-Err ("{0}: {1}" -f $nic.Name, $_.Exception.Message)
        }
    }

    # NextDNS DoH: dang ky template cho ca hai IPv4 resolver tren Windows 11.
    if ($choice -eq '3' -and $nextDnsId) {
        $template = "https://dns.nextdns.io/$nextDnsId"
        foreach ($server in @($profile.Primary, $profile.Secondary)) {
            & netsh.exe dnsclient add encryption "server=$server" "dohtemplate=$template" autoupgrade=yes udpfallback=no | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Da dang ky NextDNS DoH cho $server." }
            else { Write-Warn "Khong dang ky duoc DoH cho $server. Kiem tra Windows/netsh." }
        }
        & netsh.exe dnsclient set global doh=yes | Out-Null
    }

    ipconfig.exe /flushdns | Out-Null
    Write-Host ''
    Write-BoxSep 'DNS sau khi thay doi'
    foreach ($nic in $sel) {
        $after = @(Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            ForEach-Object { $_.ServerAddresses } | Where-Object { $_ })
        Write-Host ('  {0}: {1}' -f $nic.Name, $(if ($after.Count) { $after -join ', ' } else { '(Automatic/DHCP)' })) -ForegroundColor Green
    }
    Write-Ok 'Da flush DNS cache.'
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

# ---------------- NETWORK DIAGNOSTICS & UTILITIES ----------------
function Net-DnsTools {
    while ($true) {
        Draw-Header 'DNS CHECK & BENCHMARK'
        Write-BoxSep 'DNS tools'
        Write-BoxItem '[1] Xem DNS hien tai (IPv4 / IPv6 / DoH)'
        Write-BoxItem '[2] Benchmark DNS (do thoi gian truy van)'
        Write-BoxItem '[0] Quay lai' 'Red'
        Write-BoxSep
        $c = Read-Choice 'Chon'
        if ($c -eq '0') { return }
        if ($c -eq '1') {
            Write-Host ''
            Get-DnsClientServerAddress -ErrorAction SilentlyContinue |
                Where-Object { $_.ServerAddresses.Count -gt 0 } |
                Format-Table InterfaceAlias, AddressFamily, @{N='DNS Servers';E={$_.ServerAddresses -join ', '}} -AutoSize
            Write-Host ''
            Write-Step 'Trang thai DNS-over-HTTPS (Windows/netsh)'
            & netsh.exe dnsclient show global
            Write-Warn 'DNS leak test cong khai can dich vu ben ngoai; muc nay chi hien thi cau hinh DNS tren may.'
            Pause-Back
        }
        elseif ($c -eq '2') {
            $servers = @(
                [pscustomobject]@{Name='Cloudflare'; IP='1.1.1.1'},
                [pscustomobject]@{Name='Google'; IP='8.8.8.8'},
                [pscustomobject]@{Name='NextDNS'; IP='45.90.28.0'},
                [pscustomobject]@{Name='AdGuard'; IP='94.140.14.14'},
                [pscustomobject]@{Name='Quad9'; IP='9.9.9.9'},
                [pscustomobject]@{Name='OpenDNS'; IP='208.67.222.222'}
            )
            $domain = Read-Host '  Domain test (Enter = www.microsoft.com)'
            if ([string]::IsNullOrWhiteSpace($domain)) { $domain = 'www.microsoft.com' }
            Write-Host ''
            Write-Host ('  Dang test {0} lan/server, domain: {1}' -f 3, $domain) -ForegroundColor Cyan
            $results = @()
            foreach ($server in $servers) {
                $times = @()
                for ($i=0; $i -lt 3; $i++) {
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    try {
                        Resolve-DnsName -Name $domain -Server $server.IP -Type A -DnsOnly -ErrorAction Stop | Out-Null
                        $sw.Stop(); $times += [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
                    } catch { $sw.Stop() }
                }
                if ($times.Count -gt 0) {
                    $avg = [math]::Round(($times | Measure-Object -Average).Average, 1)
                    $results += [pscustomobject]@{Provider=$server.Name; DNS=$server.IP; AvgMs=$avg; Success=('{0}/3' -f $times.Count)}
                } else {
                    $results += [pscustomobject]@{Provider=$server.Name; DNS=$server.IP; AvgMs='Failed'; Success='0/3'}
                }
            }
            $results | Sort-Object @{Expression={if ($_.AvgMs -is [double] -or $_.AvgMs -is [int]) {[double]$_.AvgMs} else {[double]::MaxValue}}} | Format-Table -AutoSize
            Write-Warn 'Ket qua phu thuoc mang hien tai, cache, vi tri DNS va thoi diem test; nen chay lai vai lan de so sanh.'
            Pause-Back
        }
        else { Write-Warn 'Lua chon khong hop le.'; Start-Sleep -Seconds 1 }
    }
}

function Net-IpConfiguration {
    Draw-Header 'IP CONFIGURATION'
    Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Select-Object InterfaceAlias, InterfaceIndex,
            @{N='IPv4';E={($_.IPv4Address | ForEach-Object {$_.IPAddress}) -join ', '}},
            @{N='Gateway';E={($_.IPv4DefaultGateway | ForEach-Object {$_.NextHop}) -join ', '}},
            @{N='DNS';E={($_.DNSServer | ForEach-Object {$_.ServerAddresses}) -join ', '}} |
        Format-List
    Write-Host ''
    Write-BoxSep 'DHCP Renew'
    Write-Warn 'Renew co the lam mat ket noi tam thoi. Neu dang remote/RDP, khong nen chay.'
    if ($env:SESSIONNAME -like 'RDP*') { Write-Err 'Phat hien phien RDP. Da chan thao tac Renew de tranh tu ngat ket noi.'; return }
    if (Confirm-YN 'Chay ipconfig /renew cho cac adapter DHCP?') {
        ipconfig.exe /renew
        Start-Sleep -Seconds 2
        Write-Ok 'Da gui lenh renew. Kiem tra lai IP o tren.'
    }
}

function Net-AdapterManagement {
    while ($true) {
        Draw-Header 'NETWORK ADAPTER MANAGEMENT'
        $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)
        if ($nics.Count -eq 0) { Write-Err 'Khong tim thay adapter vat ly.'; return }
        $nics | Format-Table Name, Status, LinkSpeed, InterfaceDescription -AutoSize
        Write-BoxSep 'Thao tac'
        Write-BoxItem '[1] Xem driver / chi tiet adapter'
        Write-BoxItem '[2] Restart adapter'
        Write-BoxItem '[3] Enable adapter'
        Write-BoxItem '[4] Disable adapter'
        Write-BoxItem '[0] Quay lai' 'Red'
        Write-BoxSep
        $c = Read-Choice 'Chon'
        if ($c -eq '0') { return }
        if ($c -notmatch '^[1-4]$') { Write-Warn 'Lua chon khong hop le.'; Pause-Back; continue }
        $idx = Read-Host '  Nhap ten adapter (Enter = chon trong danh sach)'
        if ([string]::IsNullOrWhiteSpace($idx)) {
            for ($i=0; $i -lt $nics.Count; $i++) { Write-Host ('  {0}. {1} [{2}]' -f ($i+1),$nics[$i].Name,$nics[$i].Status) }
            $pick = Read-Host '  Chon so (0 = huy)'
            if ($pick -notmatch '^\d+$' -or [int]$pick -lt 1 -or [int]$pick -gt $nics.Count) { continue }
            $nic = $nics[[int]$pick-1]
        } else {
            $nic = $nics | Where-Object {$_.Name -eq $idx} | Select-Object -First 1
            if (-not $nic) { Write-Err 'Khong tim thay ten adapter.'; Pause-Back; continue }
        }
        if ($c -eq '1') {
            $nic | Format-List *
            Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue |
                Where-Object { $_.NetConnectionID -eq $nic.Name } |
                Select-Object NetConnectionID, Name, DriverVersion, DriverDate, PNPDeviceID | Format-List
        } else {
            if ($env:SESSIONNAME -like 'RDP*' -and $nic.Status -eq 'Up') {
                $rdpIf = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
                if ($rdpIf -and $nic.ifIndex -eq $rdpIf.InterfaceIndex) {
                    Write-Err 'Chan thao tac tren adapter dang mang Default Gateway trong phien RDP.'; Pause-Back; continue
                }
            }
            if (-not (Confirm-YN ("Xac nhan thao tac tren {0}?" -f $nic.Name))) { continue }
            try {
                switch ($c) {
                    '2' { Restart-NetAdapter -Name $nic.Name -Confirm:$false -ErrorAction Stop }
                    '3' { Enable-NetAdapter -Name $nic.Name -Confirm:$false -ErrorAction Stop }
                    '4' { Disable-NetAdapter -Name $nic.Name -Confirm:$false -ErrorAction Stop }
                }
                Write-Ok 'Da gui lenh. Trang thai moi:'
                Start-Sleep -Seconds 2
                Get-NetAdapter -Name $nic.Name | Format-Table Name, Status, LinkSpeed -AutoSize
            } catch { Write-Err $_.Exception.Message }
        }
        Pause-Back
    }
}

function Net-VpnDiagnostics {
    Draw-Header 'VPN TROUBLESHOOTING - READ ONLY'
    Write-Host '  Adapter co tu khoa VPN/Tunnel:' -ForegroundColor Cyan
    $vpn = @(Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name + ' ' + $_.InterfaceDescription) -match '(?i)vpn|tunnel|wireguard|tap|wintun|openvpn|forti|cisco|anyconnect|globalprotect|pulse|checkpoint|l2tp|sstp'
    })
    if ($vpn.Count) { $vpn | Format-Table Name, Status, InterfaceDescription, ifIndex -AutoSize }
    else { Write-Warn 'Khong nhan dien duoc adapter VPN theo ten; VPN co the dung ten khac.' }

    Write-Host ''
    Write-Step 'Default route IPv4'
    Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric | Format-Table InterfaceAlias, ifIndex, NextHop, RouteMetric, State -AutoSize
    Write-Step 'Route LAN / private network (10/8, 172.16/12, 192.168/16)'
    Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {$_.DestinationPrefix -match '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)'} |
        Sort-Object DestinationPrefix | Format-Table DestinationPrefix, InterfaceAlias, NextHop, RouteMetric -AutoSize
    Write-Step 'DNS tren cac interface dang hoat dong'
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {$_.ServerAddresses.Count -gt 0} |
        Format-Table InterfaceAlias, @{N='DNS';E={$_.ServerAddresses -join ', '}} -AutoSize
    Write-Host ''
    $hostOrIp = Read-Host '  Nhap IP/hostname VPN Server de test (Enter = bo qua)'
    if (-not [string]::IsNullOrWhiteSpace($hostOrIp)) {
        $resolved = Resolve-Ipv4 $hostOrIp
        if ($resolved) { Write-Ok "Resolve: $hostOrIp -> $resolved"; Test-NetConnection -ComputerName $resolved -InformationLevel Detailed }
        else { Write-Err "Khong resolve duoc $hostOrIp" }
    }
    Write-Warn 'Module nay chi thu thap thong tin, khong tu sua route hay thay default gateway.'
}

function Net-WifiInfo {
    Draw-Header 'WI-FI INFORMATION'
    Write-Step 'Wi-Fi interface'
    & netsh.exe wlan show interfaces
    Write-Step 'Wi-Fi driver'
    & netsh.exe wlan show drivers
    Write-Step 'Saved Wi-Fi profiles (chi ten profile)'
    & netsh.exe wlan show profiles
    Write-Warn 'Khong hien thi mat khau Wi-Fi da luu.'
}

function Net-ProxyProfile {
    while ($true) {
        Draw-Header 'PROXY & NETWORK PROFILE'
        Write-BoxSep 'Proxy'
        $reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        $settings = Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue
        Write-Host ('  User Proxy : {0}' -f $(if ($settings.ProxyEnable -eq 1) {'ON'} else {'OFF'}))
        if ($settings.ProxyServer) { Write-Host ('  Proxy      : {0}' -f $settings.ProxyServer) }
        if ($settings.AutoConfigURL) { Write-Host ('  PAC URL    : {0}' -f $settings.AutoConfigURL) }
        & netsh.exe winhttp show proxy
        Write-BoxSep 'Network profile'
        Get-NetConnectionProfile -ErrorAction SilentlyContinue | Format-Table Name, InterfaceAlias, NetworkCategory, IPv4Connectivity -AutoSize
        Write-BoxItem '[1] Toggle User Proxy (HKCU)'
        Write-BoxItem '[2] Reset WinHTTP Proxy (may affect services/apps)'
        Write-BoxItem '[3] Set Network Profile Public / Private'
        Write-BoxItem '[0] Quay lai' 'Red'
        Write-BoxSep
        $c = Read-Choice 'Chon'
        if ($c -eq '0') { return }
        if ($c -eq '1') {
            $enable = ($settings.ProxyEnable -ne 1)
            if (Confirm-YN ("{0} User Proxy?" -f $(if ($enable) {'Bat'} else {'Tat'}))) {
                Set-ItemProperty -Path $reg -Name ProxyEnable -Value ([int]$enable)
                Write-Ok 'Da cap nhat User Proxy. Mot so ung dung can mo lai de nhan cau hinh.'
            }
        } elseif ($c -eq '2') {
            if (Confirm-YN 'Reset WinHTTP Proxy ve DIRECT?') { & netsh.exe winhttp reset proxy; Write-Ok 'Da reset WinHTTP proxy.' }
        } elseif ($c -eq '3') {
            $profiles = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
            for ($i=0; $i -lt $profiles.Count; $i++) { Write-Host ('  {0}. {1} [{2}]' -f ($i+1),$profiles[$i].InterfaceAlias,$profiles[$i].NetworkCategory) }
            $pick = Read-Host '  Chon profile'
            if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $profiles.Count) {
                $p = $profiles[[int]$pick-1]
                Write-Host '  [1] Private (tin cay / chia se LAN)  [2] Public (an toan hon)' 
                $kind = Read-Host '  Chon 1/2'
                if ($kind -in @('1','2') -and (Confirm-YN 'Xac nhan thay doi Network Profile?')) {
                    try { Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory $(if ($kind -eq '1') {'Private'} else {'Public'}) -ErrorAction Stop; Write-Ok 'Da cap nhat Network Profile.' }
                    catch { Write-Err $_.Exception.Message }
                }
            }
        } else { Write-Warn 'Lua chon khong hop le.' }
        Pause-Back
    }
}

function Net-ExportReport {
    Draw-Header 'EXPORT NETWORK REPORT'
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not $desktop -or -not (Test-Path $desktop)) { $desktop = $env:TEMP }
    $path = Join-Path $desktop ("Network_Report_{0}_{1}.txt" -f $env:COMPUTERNAME,(Get-Date -Format 'yyyyMMdd_HHmmss'))
    $sections = @()
    $sections += '=== NETWORK REPORT ==='
    $sections += ('Computer: {0} | User: {1} | Date: {2}' -f $env:COMPUTERNAME,$env:USERNAME,(Get-Date))
    $sections += "`r`n=== ADAPTERS ==="
    $sections += (Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | Format-List Name, InterfaceDescription, Status, LinkSpeed, MacAddress, ifIndex | Out-String)
    $sections += "`r`n=== IP CONFIGURATION ==="
    $sections += (Get-NetIPConfiguration -ErrorAction SilentlyContinue | Format-List * | Out-String)
    $sections += "`r`n=== DNS ==="
    $sections += (Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Format-List * | Out-String)
    $sections += "`r`n=== DEFAULT ROUTES ==="
    $sections += (Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Format-Table -AutoSize | Out-String)
    $sections += "`r`n=== PROXY ==="
    $sections += (& netsh.exe winhttp show proxy 2>&1 | Out-String)
    $sections += "`r`n=== WIFI ==="
    $sections += (& netsh.exe wlan show interfaces 2>&1 | Out-String)
    $sections += "`r`n=== TCP CONNECTIONS ==="
    $sections += (Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Select-Object -First 100 | Format-Table -AutoSize | Out-String)
    try {
        $sections | Set-Content -LiteralPath $path -Encoding UTF8
        Write-Ok "Da xuat bao cao: $path"
        if (Confirm-YN 'Mo file report?') { Start-Process notepad.exe -ArgumentList "`"$path`"" }
    } catch { Write-Err $_.Exception.Message }
}

function Net-ConnectivityDiagnostics {
    Draw-Header 'NETWORK DIAGNOSTICS'
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object {$_.IPv4DefaultGateway -and $_.IPv4Address} | Select-Object -First 1
    if (-not $cfg) { Write-Err 'Khong tim thay interface IPv4 co Default Gateway.'; return }
    $ip = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
    $gw = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
    Write-Host ('  Interface: {0} | IP: {1} | Gateway: {2}' -f $cfg.InterfaceAlias,$ip,$gw) -ForegroundColor Cyan

    Write-Step '1. NIC status'
    Get-NetAdapter -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue | Format-Table Name, Status, LinkSpeed -AutoSize
    Write-Step "2. Gateway: $gw"
    $gwOk = Test-Connection -ComputerName $gw -Count 2 -Quiet -ErrorAction SilentlyContinue
    if ($gwOk) { Write-Ok 'Gateway ping OK' } else { Write-Warn 'Gateway khong phan hoi ping (co the firewall chan ICMP).' }

    Write-Step '3. Internet TCP 443: 1.1.1.1'
    $internet = Test-NetConnection -ComputerName '1.1.1.1' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($internet) { Write-Ok 'Ket noi TCP 443 toi Internet OK' } else { Write-Err 'Khong ket noi duoc TCP 443 toi 1.1.1.1' }

    Write-Step '4. Packet loss (ping 1.1.1.1 x 5)'
    $pingResults = @(Test-Connection -ComputerName '1.1.1.1' -Count 5 -ErrorAction SilentlyContinue)
    $lost = 5 - $pingResults.Count
    $lossPct = [math]::Round(($lost / 5) * 100, 0)
    Write-Host ("  Reply: {0}/5 | Packet loss: {1}%" -f $pingResults.Count,$lossPct)
    if ($lossPct -eq 0) { Write-Ok 'Khong ghi nhan packet loss qua ICMP.' }
    elseif ($lossPct -lt 100) { Write-Warn 'Co packet loss ICMP; can test lai de xac nhan.' }
    else { Write-Warn 'Khong co ICMP reply; dich vu/mang co the chan ping.' }

    Write-Step '5. DNS resolve: www.microsoft.com'
    try { Resolve-DnsName -Name 'www.microsoft.com' -Type A -DnsOnly -ErrorAction Stop | Select-Object -First 3 Name, IPAddress | Format-Table -AutoSize; Write-Ok 'DNS resolve OK' }
    catch { Write-Err ('DNS resolve loi: {0}' -f $_.Exception.Message) }

    Write-Step '6. HTTPS test'
    try {
        $resp = Invoke-WebRequest -Uri 'https://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        Write-Ok ("HTTPS OK - HTTP {0}" -f [int]$resp.StatusCode)
    } catch { Write-Warn ('HTTPS test that bai/bi proxy chan: {0}' -f $_.Exception.Message) }

    Write-Host ''
    Write-Host '  Goi y doc ket qua:' -ForegroundColor Cyan
    Write-Host '  - Gateway fail: kiem tra cap/Wi-Fi, VLAN, NIC, IP.'
    Write-Host '  - Gateway OK, TCP fail: kiem tra router, firewall, VPN, default route.'
    Write-Host '  - TCP OK, DNS fail: kiem tra DNS server / DNS policy.'
    Write-Host '  - TCP + DNS OK, HTTPS fail: kiem tra proxy, TLS, captive portal.'
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
        Write-BoxSep 'Fix & configuration'
        Write-BoxItem '[1] Reset IP & Flush DNS (Go nghen mang)'
        Write-BoxItem '[2] Reset Network Card (Disable/Enable)'
        Write-BoxItem '[3] Reconnect Network Drive (quyen User)'
        Write-BoxItem '[4] Fix Route VPN (Dinh tuyen cho VPN)'
        Write-BoxItem '[5] Quick DNS Switch (Cloudflare/Google/NextDNS...)' 'Green'
        Write-BoxItem '[6] IP Configuration / DHCP Renew'
        Write-BoxItem '[7] Adapter Management (Driver/Restart/Enable)'
        Write-BoxSep 'Diagnostics & monitoring'
        Write-BoxItem '[8] Network Diagnostics (NIC > Gateway > DNS > Internet)' 'Yellow'
        Write-BoxItem '[9] DNS Check & Benchmark' 'Yellow'
        Write-BoxItem '[10] VPN Troubleshooting (Route/Adapter/DNS)' 'Yellow'
        Write-BoxItem '[11] Wi-Fi Information' 'Yellow'
        Write-BoxItem '[12] Connectivity / Tracert / Open Ports' 'Yellow'
        Write-BoxItem '[13] Nmap - Quet thiet bi / port trong mang' 'Cyan'
        Write-BoxSep 'System settings & report'
        Write-BoxItem '[14] Proxy / Network Profile'
        Write-BoxItem '[15] Export Network Report (TXT)'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai Menu chinh' 'Red'
        Write-BoxSep

        switch (Read-Choice) {
            '1' { Net-ResetIP; Pause-Back }
            '2' { Net-RefreshNic; Pause-Back }
            '3' { Net-ReconnectDrives; Pause-Back }
            '4' { Net-FixVpnRoute; Pause-Back }
            '5' { Net-ChangeDNS; Pause-Back }
            '6' { Net-IpConfiguration; Pause-Back }
            '7' { Net-AdapterManagement }
            '8' { Net-ConnectivityDiagnostics; Pause-Back }
            '9' { Net-DnsTools }
            '10' { Net-VpnDiagnostics; Pause-Back }
            '11' { Net-WifiInfo; Pause-Back }
            '12' { Net-Diagnostics; Net-PortCheck; Pause-Back }
            '13' { Net-Nmap; Pause-Back }
            '14' { Net-ProxyProfile }
            '15' { Net-ExportReport; Pause-Back }
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
# 5. WINDOWS REPAIR & HEALTH
# ------------------------------------------------------------
function Win-RepairMenu {
    while ($true) {
        Draw-Header 'WINDOWS REPAIR & HEALTH'
        Write-BoxSep 'Kiem tra / sua loi'
        Write-BoxItem '[1] SFC ScanNow - quet va sua system files' 'Yellow'
        Write-BoxItem '[2] DISM CheckHealth - kiem tra component store'
        Write-BoxItem '[3] DISM ScanHealth - quet loi component store'
        Write-BoxItem '[4] DISM RestoreHealth - sua component store' 'Yellow'
        Write-BoxItem '[5] Windows Update - xem trang thai services'
        Write-BoxItem '[6] Reset Windows Update cache' 'Yellow'
        Write-BoxItem '[7] Xem loi Critical/Error trong 24 gio'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai' 'Red'
        Write-BoxSep
        switch (Read-Choice) {
            '1' {
                Draw-Header 'SYSTEM FILE CHECKER'
                Write-Warn 'SFC co the mat vai phut va se tu sua file he thong neu co the.'
                if (Confirm-YN 'Chay sfc /scannow?') { sfc.exe /scannow }
                Pause-Back
            }
            '2' { Draw-Header 'DISM CHECKHEALTH'; dism.exe /Online /Cleanup-Image /CheckHealth; Pause-Back }
            '3' { Draw-Header 'DISM SCANHEALTH'; dism.exe /Online /Cleanup-Image /ScanHealth; Pause-Back }
            '4' {
                Draw-Header 'DISM RESTOREHEALTH'
                Write-Warn 'Can Internet hoac Windows source phu hop. Khong tat may trong luc chay.'
                if (Confirm-YN 'Chay DISM RestoreHealth?') { dism.exe /Online /Cleanup-Image /RestoreHealth }
                Pause-Back
            }
            '5' {
                Draw-Header 'WINDOWS UPDATE SERVICES'
                Get-Service wuauserv, bits, usosvc, cryptsvc -ErrorAction SilentlyContinue |
                    Format-Table Name, DisplayName, Status, StartType -AutoSize
                Pause-Back
            }
            '6' {
                Draw-Header 'RESET WINDOWS UPDATE CACHE'
                Write-Warn 'Tam dung Windows Update va xoa cache Download; khong xoa lich su cap nhat.'
                if (Confirm-YN 'Tiep tuc reset cache?') {
                    $svc = @('bits','wuauserv','cryptsvc')
                    foreach ($n in $svc) { Stop-Service $n -Force -ErrorAction SilentlyContinue }
                    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                    $download = Join-Path $env:SystemRoot 'SoftwareDistribution\Download'
                    if (Test-Path $download) {
                        $backup = "$download.ITToolkit_$stamp.bak"
                        try { Rename-Item $download $backup -ErrorAction Stop; New-Item -ItemType Directory -Path $download -Force | Out-Null; Write-Ok "Cache cu duoc doi ten: $backup" }
                        catch { Write-Warn "Khong doi ten duoc cache: $($_.Exception.Message)" }
                    }
                    foreach ($n in $svc) { Start-Service $n -ErrorAction SilentlyContinue }
                    Write-Ok 'Da hoan tat thao tac reset cache (neu khong co loi phia tren).'
                }
                Pause-Back
            }
            '7' {
                Draw-Header 'RECENT WINDOWS ERRORS'
                $since = (Get-Date).AddHours(-24)
                Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -MaxEvents 40 -ErrorAction SilentlyContinue |
                    Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, @{N='Message';E={($_.Message -replace '\s+',' ').Substring(0,[math]::Min(180,($_.Message -replace '\s+',' ').Length))}} |
                    Format-Table -Wrap -AutoSize
                Pause-Back
            }
            '0' { return }
        }
    }
}

# ------------------------------------------------------------
# 6. SYSTEM MONITORING
# ------------------------------------------------------------
function Sys-MonitorSnapshot {
    Draw-Header 'SYSTEM MONITORING SNAPSHOT'
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object LoadPercentage -Average
    $totalMem = [double]$os.TotalVisibleMemorySize * 1KB
    $freeMem  = [double]$os.FreePhysicalMemory * 1KB
    $usedPct = if ($totalMem -gt 0) { [math]::Round((($totalMem-$freeMem)/$totalMem)*100,1) } else { 0 }
    Write-Host ('  CPU Load       : {0}%' -f [math]::Round($cpu.Average,1)) -ForegroundColor Cyan
    Write-Host ('  RAM Usage      : {0}% ({1:N2}/{2:N2} GB)' -f $usedPct,(($totalMem-$freeMem)/1GB),($totalMem/1GB)) -ForegroundColor Cyan
    Write-Host ('  Uptime         : {0}' -f ((Get-Date)-$os.LastBootUpTime))
    Write-Host "`n  TOP PROCESS - CPU time" -ForegroundColor Yellow
    Get-Process -ErrorAction SilentlyContinue | Sort-Object CPU -Descending | Select-Object -First 10 Name, Id, CPU, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
    Write-Host '  DISK SPACE' -ForegroundColor Yellow
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
        Select-Object DeviceID, VolumeName, @{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}}, @{N='Free_GB';E={[math]::Round($_.FreeSpace/1GB,1)}}, @{N='Free_Pct';E={if($_.Size){[math]::Round($_.FreeSpace/$_.Size*100,1)}else{0}}} |
        Format-Table -AutoSize
    Write-Host '  PHYSICAL DISK HEALTH (neu driver ho tro)' -ForegroundColor Yellow
    try { Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, @{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize }
    catch { Write-Host '  Khong doc duoc Get-PhysicalDisk tren may nay.' -ForegroundColor DarkGray }
    Write-Host '  TOP PROCESS - RAM' -ForegroundColor Yellow
    Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
}

function Sys-ExportReport {
    $dir = Join-Path $env:USERPROFILE 'Desktop'
    $file = Join-Path $dir ("IT_SystemReport_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('IT SYSTEM REPORT - ' + (Get-Date))
    $lines.Add('Computer: ' + $env:COMPUTERNAME)
    $lines.Add('User: ' + $env:USERNAME)
    $lines.Add('')
    $lines.Add('=== OS ===')
    $lines.Add((Get-CimInstance Win32_OperatingSystem | Format-List Caption,Version,BuildNumber,OSArchitecture,LastBootUpTime | Out-String))
    $lines.Add('=== CPU ===')
    $lines.Add((Get-CimInstance Win32_Processor | Format-List Name,NumberOfCores,NumberOfLogicalProcessors,LoadPercentage | Out-String))
    $lines.Add('=== MEMORY ===')
    $lines.Add((Get-CimInstance Win32_OperatingSystem | Select-Object @{N='TotalGB';E={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}},@{N='FreeGB';E={[math]::Round($_.FreePhysicalMemory/1MB,2)}} | Format-List | Out-String))
    $lines.Add('=== DISKS ===')
    $lines.Add((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID,VolumeName,Size,FreeSpace | Format-Table -AutoSize | Out-String))
    $lines.Add('=== TOP PROCESSES ===')
    $lines.Add((Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 20 Name,Id,CPU,@{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize | Out-String))
    $lines.Add('=== PHYSICAL DISKS ===')
    try { $lines.Add((Get-PhysicalDisk | Format-Table FriendlyName,MediaType,HealthStatus,OperationalStatus,Size -AutoSize | Out-String)) } catch { $lines.Add('Get-PhysicalDisk unavailable') }
    $lines | Set-Content -Path $file -Encoding UTF8
    Write-Ok "Da xuat report: $file"
}

function Menu-SystemMonitor {
    while ($true) {
        Draw-Header 'SYSTEM MONITORING'
        Write-BoxSep 'Theo doi tai nguyen'
        Write-BoxItem '[1] Snapshot CPU / RAM / Disk / Process' 'Green'
        Write-BoxItem '[2] Top process su dung RAM'
        Write-BoxItem '[3] Top process CPU time'
        Write-BoxItem '[4] Startup Programs (Current User + Machine)'
        Write-BoxItem '[5] Export System Report TXT'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai' 'Red'
        Write-BoxSep
        switch (Read-Choice) {
            '1' { Sys-MonitorSnapshot; Pause-Back }
            '2' { Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 25 Name,Id,@{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize; Pause-Back }
            '3' { Get-Process | Sort-Object CPU -Descending | Select-Object -First 25 Name,Id,CPU | Format-Table -AutoSize; Pause-Back }
            '4' {
                Draw-Header 'STARTUP PROGRAMS'
                $paths = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')
                foreach ($path in $paths) { if (Test-Path $path) { Write-Host "`n  $path" -ForegroundColor Yellow; Get-ItemProperty $path | Format-List * } }
                Pause-Back
            }
            '5' { Sys-ExportReport; Pause-Back }
            '0' { return }
        }
    }
}

# ---------------- ONEDRIVE RESYNC ----------------
function Get-OneDriveExe {
    @("$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe",
      "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe",
      "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe") |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

function Get-OneDriveAccounts {
    $base = 'HKCU:\Software\Microsoft\OneDrive\Accounts'
    $list = @()
    if (Test-Path $base) {
        foreach ($k in (Get-ChildItem $base -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
            if ($p -and $p.UserFolder -and (Test-Path -LiteralPath $p.UserFolder)) {
                $list += [pscustomobject]@{ Key = $k.PSChildName; Email = [string]$p.UserEmail; Folder = ([string]$p.UserFolder).TrimEnd('\') }
            }
        }
    }
    return $list
}

# Quet tat ca folder OneDrive tren may (registry + bien moi truong + folder trong profile)
function Get-OneDriveFolders {
    $seen = @{}
    $list = @()
    foreach ($a in @(Get-OneDriveAccounts)) {
        $k = $a.Folder.ToLower()
        if (-not $seen.ContainsKey($k)) {
            $seen[$k] = $true
            $list += [pscustomobject]@{ Label = $a.Email; Folder = $a.Folder; Source = 'Tai khoan' }
        }
    }
    $cands = @()
    foreach ($v in @($env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer)) { if ($v) { $cands += $v.TrimEnd('\') } }
    Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter 'OneDrive*' -Force -ErrorAction SilentlyContinue | ForEach-Object { $cands += $_.FullName }
    foreach ($c in $cands) {
        if ($c -match '_old\d*$') { continue }
        if (-not (Test-Path -LiteralPath $c)) { continue }
        $k = $c.ToLower()
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true
        $list += [pscustomobject]@{ Label = '(khong co trong registry)'; Folder = $c; Source = 'Quet folder' }
    }
    return $list
}

# Tat toan bo tien trinh thuoc ho OneDrive (khong chi OneDrive.exe)
function Stop-OneDriveAll([string]$Exe) {
    if ($Exe) { try { & $Exe /shutdown 2>$null } catch {}; Start-Sleep -Seconds 3 }
    $names  = @('OneDrive','OneDriveStandaloneUpdater','FileCoAuth','FileSyncHelper','Microsoft.SharePoint')
    $odDirs = @("$env:LOCALAPPDATA\Microsoft\OneDrive\", "$env:ProgramFiles\Microsoft OneDrive\", "${env:ProgramFiles(x86)}\Microsoft OneDrive\")
    for ($i = 0; $i -lt 3; $i++) {
        $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
            $pth = $null
            try { $pth = $_.Path } catch {}
            ($names -contains $_.Name) -or ($pth -and (@($odDirs | Where-Object { $pth.StartsWith($_, 'OrdinalIgnoreCase') }).Count -gt 0))
        })
        if ($procs.Count -eq 0) { return $true }
        foreach ($pr in $procs) {
            try { Stop-Process -Id $pr.Id -Force -ErrorAction Stop; Write-Host ("    Da tat: {0} (PID {1})" -f $pr.Name, $pr.Id) -ForegroundColor DarkGray }
            catch { Write-Warn ("Khong tat duoc {0} (PID {1})" -f $pr.Name, $pr.Id) }
        }
        Start-Sleep -Seconds 2
    }
    return (-not (Get-Process OneDrive -ErrorAction SilentlyContinue))
}

# Lay handle.exe (Sysinternals) - dung de tim process giu handle tren folder (giong Resource Monitor > Associated Handles)
function Get-HandleExe {
    $name = if ([Environment]::Is64BitOperatingSystem) { 'handle64.exe' } else { 'handle.exe' }
    $dir  = Join-Path $env:ProgramData 'ITTools'
    $exe  = Join-Path $dir $name
    if ((Test-Path -LiteralPath $exe) -and ((Get-Item -LiteralPath $exe).Length -gt 100KB)) { return $exe }
    try {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Write-Host "  Dang tai $name tu live.sysinternals.com ..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri "https://live.sysinternals.com/$name" -OutFile $exe -UseBasicParsing -ErrorAction Stop
        if ((Get-Item -LiteralPath $exe).Length -gt 100KB) { return $exe }
        Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
    } catch {}
    return $null
}

# Liet ke process dang giu handle tren folder (chi tinh handle co duong dan = folder hoac nam trong folder)
function Get-FolderHandleHolders([string]$Folder, [string]$HandleExe) {
    $res = @()
    $out = & $HandleExe -accepteula -nobanner $Folder 2>$null
    foreach ($line in @($out)) {
        if ($line -match '^(.+?)\s+pid:\s+(\d+)\s+type:\s+(\S+)\s+([0-9A-Fa-f]+):\s+(.+)$') {
            $hn = $Matches[5].Trim()
            if ($hn.Equals($Folder, 'OrdinalIgnoreCase') -or $hn.StartsWith($Folder + '\', 'OrdinalIgnoreCase')) {
                $res += [pscustomobject]@{ Name = $Matches[1].Trim(); ProcId = [int]$Matches[2]; Path = $hn }
            }
        }
    }
    return $res
}

# Tat tat ca process dang giu handle tren folder (tru process he thong). Explorer -> khoi dong lai.
function Stop-FolderHandleHolders([string]$Folder, [string]$HandleExe) {
    $protected = @('System','Idle','Registry','smss','csrss','wininit','winlogon','services','lsass','dwm','fontdrvhost','svchost','MemCompression')
    $explorerDone = $false
    for ($round = 1; $round -le 3; $round++) {
        $holders = @(Get-FolderHandleHolders $Folder $HandleExe | Where-Object { $_.ProcId -ne $PID })
        if ($holders.Count -eq 0) { return $true }
        $needExplorer = $false
        foreach ($h in ($holders | Sort-Object ProcId -Unique)) {
            $pn = $h.Name -replace '\.exe$', ''
            if ($protected -contains $pn) { Write-Warn ("Process he thong dang giu handle, khong tat: {0} (PID {1})" -f $h.Name, $h.ProcId); continue }
            if ($pn -ieq 'explorer') { $needExplorer = $true; continue }
            try { Stop-Process -Id $h.ProcId -Force -ErrorAction Stop; Write-Host ("    Da tat: {0} (PID {1}) - giu {2}" -f $h.Name, $h.ProcId, $h.Path) -ForegroundColor DarkGray }
            catch { Write-Warn ("Khong tat duoc {0} (PID {1})" -f $h.Name, $h.ProcId) }
        }
        if ($needExplorer -and -not $explorerDone) {
            Write-Host '    Explorer dang mo folder -> khoi dong lai Explorer...' -ForegroundColor DarkGray
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process "$env:windir\explorer.exe" }
            $explorerDone = $true
        }
        Start-Sleep -Seconds 2
    }
    return (@(Get-FolderHandleHolders $Folder $HandleExe | Where-Object { $_.ProcId -ne $PID }).Count -eq 0)
}

# Dem file local / cloud-only (placeholder) trong folder OneDrive
function Get-FolderSyncStats([string]$Path) {
    $files = 0; $cloud = 0; [int64]$bytes = 0
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $files++
        if ([int]$_.Attributes -band 0x440000) { $cloud++ } else { $bytes += $_.Length }
    }
    return [pscustomobject]@{ Files = $files; CloudOnly = $cloud; LocalGB = [math]::Round($bytes / 1GB, 2) }
}

# Known Folder Move: Desktop/Documents/Pictures dang tro vao folder OneDrive?
function Get-KfmRedirects([string]$Folder) {
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $hits = @()
    if (Test-Path $k) {
        $item = Get-ItemProperty $k
        foreach ($prop in $item.PSObject.Properties) {
            if ($prop.Name -like 'PS*') { continue }
            $v = [string]$prop.Value
            if ($v) { $v = [Environment]::ExpandEnvironmentVariables($v) }
            if ($v -and $v.StartsWith($Folder + '\', 'OrdinalIgnoreCase')) { $hits += ("{0} -> {1}" -f $prop.Name, $v) }
        }
    }
    return $hits
}

# <folder>_old, neu da ton tai -> _old2, _old3 ...
function Get-OldFolderName([string]$Folder) {
    $new = $Folder + '_old'
    $i = 2
    while (Test-Path -LiteralPath $new) { $new = "{0}_old{1}" -f $Folder, $i; $i++ }
    return $new
}

# Bat OneDrive bang quyen user thuong (tool dang chay Admin -> tranh OneDrive bi elevated)
function Start-OneDriveUser([string]$Exe) {
    try { Start-Process -FilePath "$env:windir\explorer.exe" -ArgumentList ('"{0}"' -f $Exe) -ErrorAction Stop }
    catch { Start-Process -FilePath $Exe -ArgumentList '/background' }
}

function OneDrive-Resync {
    Draw-Header 'RESYNC ONEDRIVE'
    $exe = Get-OneDriveExe
    if (-not $exe) { Write-Err 'Khong tim thay OneDrive.exe.'; Pause-Back; return }
    Write-Host "  OneDrive.exe: $exe" -ForegroundColor DarkGray
    Write-Host ''
    Write-BoxSep 'Che do'
    Write-BoxItem '[1] Resync day du: doi ten folder -> _old, tai lai'
    Write-BoxItem '[2] Reset nhe: onedrive.exe /reset (giu nguyen folder)'
    Write-BoxSep
    Write-BoxItem '[0] Quay lai' 'Red'
    Write-BoxSep
    $mode = Read-Choice

    if ($mode -eq '2') {
        if (-not (Confirm-YN 'Reset OneDrive (file giu nguyen, sync lai tu dau)?')) { return }
        Write-Step 'Dang chay OneDrive /reset ...'
        try { Start-Process -FilePath $exe -ArgumentList '/reset' -ErrorAction Stop }
        catch { Write-Err $_.Exception.Message; Pause-Back; return }
        Wait-Countdown 15 'Cho OneDrive reset'
        if (-not (Get-Process OneDrive -ErrorAction SilentlyContinue)) { Write-Step 'Bat lai OneDrive...'; Start-OneDriveUser $exe }
        Write-Ok 'Da reset. OneDrive se mat vai phut de tu khoi dong va do lai danh sach file.'
        Pause-Back
        return
    }
    if ($mode -ne '1') { return }

    # 1) Quet & chon folder
    Write-Step 'Dang quet folder OneDrive tren may...'
    $found = @(Get-OneDriveFolders)
    if ($found.Count -eq 0) { Write-Warn 'Khong tim thay folder OneDrive nao.'; Pause-Back; return }
    Write-Host ''
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $found[$i].Folder) -ForegroundColor Green
        Write-Host ("      {0}  |  nguon: {1}" -f $found[$i].Label, $found[$i].Source) -ForegroundColor DarkGray
    }
    Write-Host ''
    $sel = Read-Host '  Chon so (vd: 1 hoac 1,2), A = tat ca, 0 = huy'
    if ([string]::IsNullOrWhiteSpace($sel) -or $sel.Trim() -eq '0') { return }
    $targets = @()
    if ($sel.Trim() -match '^[aA]$') { $targets = $found }
    else {
        foreach ($tok in ($sel -split '[,\s]+' | Where-Object { $_ })) {
            if ($tok -match '^\d+$' -and [int]$tok -ge 1 -and [int]$tok -le $found.Count) {
                $item = $found[[int]$tok - 1]
                if ($targets -notcontains $item) { $targets += $item }
            } else { Write-Warn "Lua chon khong hop le: $tok"; Pause-Back; return }
        }
    }
    if ($targets.Count -eq 0) { return }

    # Canh bao truoc khi lam
    $plan = @()
    foreach ($t in $targets) {
        Write-Host ''
        Write-Host "  Dang kiem tra: $($t.Folder)" -ForegroundColor Cyan
        $kfm = @(Get-KfmRedirects $t.Folder)
        if ($kfm.Count -gt 0) {
            Write-Warn 'Folder nay dang duoc dung cho Known Folder Move (Desktop/Documents/Pictures...):'
            $kfm | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
            Write-Host '  Doi ten co the lam hong duong dan cac thu muc he thong tren.' -ForegroundColor Yellow
            if (-not (Confirm-YN 'Van tiep tuc voi tai khoan nay (RAT KHONG khuyen nghi)?')) { Write-Host '  Bo qua.' -ForegroundColor DarkGray; continue }
        }
        $st = Get-FolderSyncStats $t.Folder
        Write-Host ("  {0} file | {1} GB local | {2} file cloud-only (se KHONG mo duoc trong folder _old)" -f $st.Files, $st.LocalGB, $st.CloudOnly) -ForegroundColor White
        $plan += [pscustomobject]@{ Email = $t.Label; Folder = $t.Folder; NewFolder = (Get-OldFolderName $t.Folder) }
    }
    if ($plan.Count -eq 0) { Pause-Back; return }

    $busy = @(Get-Process WINWORD,EXCEL,POWERPNT,ONENOTE,OUTLOOK,Acrobat,AcroRd32 -ErrorAction SilentlyContinue)
    if ($busy.Count -gt 0) {
        Write-Warn ("Dang mo: {0} - nen luu & dong truoc de tranh loi doi ten." -f (($busy.Name | Sort-Object -Unique) -join ', '))
    }
    Write-Host ''
    Write-Host '  Se thuc hien:' -ForegroundColor Cyan
    $plan | ForEach-Object { Write-Host ("    {0}`n      -> {1}" -f $_.Folder, $_.NewFolder) -ForegroundColor White }
    Write-Host '  File chua kip upload van nam trong folder _old - hay doi chieu lai sau khi sync xong.' -ForegroundColor DarkGray
    if (-not (Confirm-YN 'Xac nhan resync?')) { return }

    # 2) Tat toan bo tien trinh OneDrive
    Write-Step 'Tat OneDrive va cac tien trinh lien quan...'
    if (-not (Stop-OneDriveAll $exe)) { Write-Err 'Con tien trinh OneDrive chua tat duoc. Dung lai de tranh hong du lieu.'; Pause-Back; return }
    Write-Ok 'Da tat het tien trinh OneDrive.'

    Write-Step 'Quet handle dang mo tren folder (giong Resource Monitor > Associated Handles)...'
    $handleExe = Get-HandleExe
    if (-not $handleExe) { Write-Warn 'Khong tai duoc handle64.exe (can Internet). Bo qua buoc quet handle - co the van bi Access denied.' }

    # 3) Doi ten folder
    Write-Step 'Doi ten folder...'
    foreach ($p in $plan) {
        $done = $false
        for ($try = 1; $try -le 3 -and -not $done; $try++) {
            if ($handleExe) {
                Write-Host "  Quet & tat process giu handle: $($p.Folder)" -ForegroundColor Cyan
                if (-not (Stop-FolderHandleHolders $p.Folder $handleExe)) { Write-Warn 'Van con process giu handle (xem canh bao o tren).' }
            }
            try {
                Rename-Item -LiteralPath $p.Folder -NewName (Split-Path $p.NewFolder -Leaf) -ErrorAction Stop
                Write-Ok ("{0}  ->  {1}" -f $p.Folder, $p.NewFolder)
                $done = $true
            } catch {
                if ($try -lt 3) { Start-Sleep -Seconds 2 }
                else { Write-Err ("Khong doi ten duoc {0}: {1}" -f $p.Folder, $_.Exception.Message); Write-Host '  Con process giu handle: mo Resource Monitor > CPU > Associated Handles de kiem tra.' -ForegroundColor DarkGray }
            }
        }
    }

    # 4) Cho 5s roi bat lai
    Wait-Countdown 5 'Cho truoc khi bat lai OneDrive'
    Write-Step 'Bat lai OneDrive...'
    try { Start-OneDriveUser $exe; Start-Sleep -Seconds 3 } catch { Write-Err $_.Exception.Message }
    if (Get-Process OneDrive -ErrorAction SilentlyContinue) { Write-Ok 'OneDrive dang chay.' } else { Write-Warn 'OneDrive chua len - hay mo thu cong tu Start Menu.' }
    Write-Host ''
    Write-Host '  Luu y: neu OneDrive hoi dang nhap/vi tri folder, chon dung duong dan cu de tai lai du lieu.' -ForegroundColor Yellow
    Pause-Back
}

# ------------------------------------------------------------
# 7. MICROSOFT 365 LOCAL DIAGNOSTICS
# ------------------------------------------------------------
function M365-Diagnostics {
    while ($true) {
        Draw-Header 'MICROSOFT 365 DIAGNOSTICS'
        Write-BoxSep 'Kiem tra tren may tram'
        Write-BoxItem '[1] Outlook / Office process & version'
        Write-BoxItem '[2] Outlook profile names (Registry)'
        Write-BoxItem '[3] OneDrive status & process'
        Write-BoxItem '[4] Resync OneDrive (doi ten folder -> _old)' 'Green'
        Write-BoxItem '[5] Teams status & process'
        Write-BoxItem '[6] M365 DNS / Autodiscover / MX check'
        Write-BoxItem '[7] Microsoft 365 endpoint connectivity'
        Write-BoxItem '[8] Export M365 local diagnostic report'
        Write-BoxSep
        Write-BoxItem '[0] Quay lai' 'Red'
        Write-BoxSep
        switch (Read-Choice) {
            '1' {
                Draw-Header 'OFFICE / OUTLOOK STATUS'
                Get-Process OUTLOOK,WINWORD,EXCEL,POWERPNT,ONENOTE -ErrorAction SilentlyContinue | Select-Object Name,Id,StartTime,Path | Format-Table -AutoSize
                $cv = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
                if (Test-Path $cv) { Get-ItemProperty $cv | Select-Object VersionToReport,ProductReleaseIds,Platform,ClientVersionToReport | Format-List }
                else { Write-Warn 'Khong tim thay Click-to-Run configuration; co the la Office MSI hoac chua cai.' }
                Pause-Back
            }
            '2' {
                Draw-Header 'OUTLOOK PROFILES'
                $base = 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles'
                if (Test-Path $base) { Get-ChildItem $base -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName | ForEach-Object { Write-Host "  $_" } }
                else { Write-Warn 'Khong tim thay Outlook profile registry (Office 16.0).'}
                Pause-Back
            }
            '3' {
                Draw-Header 'ONEDRIVE STATUS'
                Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object Name,Id,StartTime,Path | Format-Table -AutoSize
                $od = @("$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe", "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe", "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe") | Where-Object { $_ -and (Test-Path $_) }
                $od | ForEach-Object { Write-Host "  Installed: $_" -ForegroundColor Green }
                if (-not $od) { Write-Warn 'Khong tim thay OneDrive.exe tai cac vi tri mac dinh.' }
                Pause-Back
            }
            '4' { OneDrive-Resync }
            '5' {
                Draw-Header 'TEAMS STATUS'
                Get-Process Teams,ms-teams -ErrorAction SilentlyContinue | Select-Object Name,Id,StartTime,Path | Format-Table -AutoSize
                foreach ($path in @("$env:LOCALAPPDATA\Microsoft\Teams", "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe")) { if (Test-Path $path) { Write-Host "  Found: $path" } }
                Pause-Back
            }
            '6' {
                Draw-Header 'M365 DNS CHECK'
                $domain = Read-Host 'Nhap domain email (vd: contoso.com)'
                if ($domain -match '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') {
                    foreach ($name in @("autodiscover.$domain", $domain)) {
                        Write-Host "`n  DNS: $name" -ForegroundColor Yellow
                        try { Resolve-DnsName $name -ErrorAction Stop | Select-Object Name,Type,NameHost,IPAddress,Preference | Format-Table -AutoSize }
                        catch { Write-Warn "Khong resolve duoc $name" }
                    }
                    Write-Host "`n  MX: $domain" -ForegroundColor Yellow
                    try { Resolve-DnsName $domain -Type MX -ErrorAction Stop | Select-Object Name,NameExchange,Preference | Format-Table -AutoSize }
                    catch { Write-Warn 'Khong tim thay MX record hoac DNS query that bai.' }
                    Write-Host "`n  Autodiscover SRV: _autodiscover._tcp.$domain" -ForegroundColor Yellow
                    try { Resolve-DnsName "_autodiscover._tcp.$domain" -Type SRV -ErrorAction Stop | Select-Object Name,NameTarget,Port,Priority,Weight | Format-Table -AutoSize }
                    catch { Write-Host '  Khong co SRV record (khong bat buoc neu dung CNAME).' -ForegroundColor DarkGray }
                } else { Write-Warn 'Domain khong hop le.' }
                Pause-Back
            }
            '7' {
                Draw-Header 'M365 ENDPOINT CONNECTIVITY'
                $targets = @('outlook.office365.com','login.microsoftonline.com','teams.microsoft.com','graph.microsoft.com','sharepoint.com')
                foreach ($target in $targets) {
                    $r = Test-NetConnection $target -Port 443 -WarningAction SilentlyContinue
                    $status = if ($r.TcpTestSucceeded) { 'OK' } else { 'FAILED' }
                    $color = if ($r.TcpTestSucceeded) { 'Green' } else { 'Red' }
                    Write-Host ('  {0,-34} TCP/443 {1}' -f $target,$status) -ForegroundColor $color
                }
                Write-Host '  Luu y: day la kiem tra ket noi co ban, khong thay the Microsoft 365 connectivity test chinh thuc.' -ForegroundColor DarkGray
                Pause-Back
            }
            '8' {
                $file = Join-Path $env:USERPROFILE ("Desktop\M365_LocalReport_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
                $out = New-Object System.Collections.Generic.List[string]
                $out.Add('M365 LOCAL REPORT - ' + (Get-Date))
                $out.Add('Computer: ' + $env:COMPUTERNAME)
                $out.Add('=== OFFICE PROCESSES ===')
                $out.Add((Get-Process OUTLOOK,WINWORD,EXCEL,POWERPNT,Teams,ms-teams,OneDrive -ErrorAction SilentlyContinue | Format-List Name,Id,StartTime,Path | Out-String))
                $out.Add('=== OFFICE C2R ===')
                $cv = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
                if (Test-Path $cv) { $out.Add((Get-ItemProperty $cv | Select-Object VersionToReport,ProductReleaseIds,Platform | Format-List | Out-String)) }
                $out | Set-Content -Path $file -Encoding UTF8
                Write-Ok "Da xuat: $file"
                Pause-Back
            }
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
    Write-BoxItem '[5] WINDOWS REPAIR    - SFC, DISM, Update, Event Log'
    Write-BoxItem '[6] SYSTEM MONITOR    - CPU, RAM, Disk, Process, Report'
    Write-BoxItem '[7] MICROSOFT 365     - Outlook, Teams, OneDrive, DNS'
    Write-BoxSep
    Write-BoxItem '[0] THOAT' 'Red'
    Write-BoxSep

    switch (Read-Choice 'Chon danh muc (0-7)') {
        '1' { Menu-Network }
        '2' { Menu-Cleanup }
        '3' { Menu-ITTools }
        '4' { Menu-Sysinternals }
        '5' { Win-RepairMenu }
        '6' { Menu-SystemMonitor }
        '7' { M365-Diagnostics }
        '0' { $quit = $true }
        default { Write-Warn 'Lua chon khong hop le!'; Start-Sleep -Seconds 1 }
    }
}
