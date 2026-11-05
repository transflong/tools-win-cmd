# ============================================================
#  TOOLS WIN CMD - bo cong cu Windows tu dong
#  Chay:  irm https://tools.transflong.eu.cc | iex
# ============================================================

$ScriptUrl   = 'https://tools.transflong.eu.cc'
$WaitSeconds = 300    # thoi gian cho giua cac buoc (300 = 5 phut)

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# ------------------------------------------------------------
#  Ep quyen Administrator
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
        Write-Host 'Ban da tu choi quyen Administrator. Tool khong the chay.' -ForegroundColor Red
    }
    return
}

$Host.UI.RawUI.WindowTitle = 'Tools Win CMD (Administrator)'

# ------------------------------------------------------------
#  Ham tien ich
# ------------------------------------------------------------
function Write-Title($text) {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ("  {0}" -f $text)                               -ForegroundColor Cyan
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ''
}
function Write-Ok($m)   { Write-Host "[OK]  $m"  -ForegroundColor Green }
function Write-Warn($m) { Write-Host "[!]   $m"  -ForegroundColor Yellow }
function Write-Err($m)  { Write-Host "[LOI] $m"  -ForegroundColor Red }
function Write-Step($m) { Write-Host "`n>> $m"   -ForegroundColor Cyan }
function Pause-Back     { Write-Host ''; Read-Host 'Nhan Enter de quay lai menu' | Out-Null }
function Confirm-YN($q) { return ((Read-Host "$q (Y/N)") -match '^[yY]') }

function Wait-Countdown([int]$Seconds, [string]$Label) {
    Write-Host "$Label - nhan S de bo qua cho" -ForegroundColor DarkGray
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        $left = [int][math]::Ceiling(($end - (Get-Date)).TotalSeconds)
        Write-Host -NoNewline ("`r  Con lai: {0:00}:{1:00}   " -f [math]::Floor($left / 60), ($left % 60))
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

# ============================================================
#  1. NETWORK FIX
# ============================================================
function Select-PhysicalNic {
    $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
    if ($nics.Count -eq 0) { $nics = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue) }
    if ($nics.Count -eq 0) { Write-Err 'Khong tim thay card mang vat ly.'; return @() }
    if ($nics.Count -eq 1) {
        Write-Ok ("Tu dong chon: {0} ({1})" -f $nics[0].Name, $nics[0].InterfaceDescription)
        return $nics
    }
    Write-Host 'Tim thay nhieu card mang:'
    for ($i = 0; $i -lt $nics.Count; $i++) {
        Write-Host (" {0}. {1}  [{2}]  {3}" -f ($i + 1), $nics[$i].Name, $nics[$i].Status, $nics[$i].InterfaceDescription)
    }
    $c = Read-Host 'Chon so (Enter = tat ca, 0 = huy)'
    if ($c -eq '0') { return @() }
    if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $nics.Count) { return @($nics[[int]$c - 1]) }
    return $nics
}

# 1.1 Reset IP
function Net-ResetIP {
    Write-Title 'Reset IP'
    Write-Host 'Thu tu: release -> cho -> flushdns -> cho -> registerdns -> cho -> renew'
    Write-Host ("Moi lan cho: {0} giay. Mang se MAT trong luc chay." -f $WaitSeconds) -ForegroundColor Yellow
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

# 1.2 Refresh Network Interface
function Net-RefreshNic {
    Write-Title 'Refresh Network Interface'
    $sel = @(Select-PhysicalNic)
    if ($sel.Count -eq 0) { return }
    $names = @($sel | ForEach-Object { $_.Name })

    Write-Host ("Se tat NIC, cho {0} giay roi bat lai." -f $WaitSeconds) -ForegroundColor Yellow
    if (-not (Confirm-YN 'Tiep tuc?')) { return }

    try {
        foreach ($n in $names) {
            Write-Step "Tat NIC: $n"
            cmd /c "netsh interface set interface name=`"$n`" admin=disabled" | Out-Null
        }
        Wait-Countdown $WaitSeconds 'Cho truoc khi bat lai NIC'
    }
    finally {
        # luon bat lai NIC, ke ca khi bam Ctrl+C
        foreach ($n in $names) {
            Write-Step "Bat NIC: $n"
            cmd /c "netsh interface set interface name=`"$n`" admin=enabled" | Out-Null
        }
    }
    Start-Sleep -Seconds 5
    Write-Host ''
    Get-NetAdapter -Name $names -ErrorAction SilentlyContinue | Format-Table Name, Status, LinkSpeed -AutoSize
}

# 1.3 Reconnect Network Drive
function Net-ReconnectDrives {
    Write-Title 'Reconnect Network Drive'
    Write-Host 'O mang map trong phien Admin KHAC phien nguoi dung thuong (UAC),' -ForegroundColor DarkGray
    Write-Host 'nen tool se chay phan nay duoi quyen nguoi dung thuong de Explorer thay duoc.' -ForegroundColor DarkGray
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

# 1.4 Fix route VPN
function Resolve-Ipv4($hostOrIp) {
    if ($hostOrIp -match '^\d{1,3}(\.\d{1,3}){3}$') { return $hostOrIp }
    try {
        $a = [System.Net.Dns]::GetHostAddresses($hostOrIp) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        if ($a) { return $a.IPAddressToString }
    } catch {}
    return $null
}

function Net-FixVpnRoute {
    Write-Title 'Fix route VPN'

    # --- 1. Tim VPN dang ket noi ---
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

    # --- 2. Thong tin card VPN ---
    $vpnCfg = Get-NetIPConfiguration -InterfaceAlias $vpnAlias -ErrorAction SilentlyContinue
    if (-not $vpnCfg -or -not $vpnCfg.IPv4Address) {
        Write-Err "Khong lay duoc IP cua card VPN '$vpnAlias' (VPN chua nhan IP?)."
        return
    }
    $vpnIp  = ($vpnCfg.IPv4Address | Select-Object -First 1).IPAddress
    $vpnIdx = $vpnCfg.InterfaceIndex

    # --- 3. IP may chu VPN ---
    $serverIp = $null
    if ($vpnServer) { $serverIp = Resolve-Ipv4 $vpnServer }
    if (-not $serverIp) {
        $inp = Read-Host 'Nhap IP hoac hostname may chu VPN'
        if ($inp) { $serverIp = Resolve-Ipv4 $inp.Trim() }
    }
    if (-not $serverIp) { Write-Err 'Khong xac dinh duoc IP may chu VPN.'; return }

    # --- 4. Card LAN vat ly + gateway ---
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

    # --- 5. Them route toi may chu VPN qua Gateway LAN ---
    Write-Step ("Them route {0}/32 -> Gateway {1} (qua {2})" -f $serverIp, $lanGw, $lan.InterfaceAlias)
    try {
        Get-NetRoute -DestinationPrefix "$serverIp/32" -ErrorAction SilentlyContinue |
            Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
        New-NetRoute -DestinationPrefix "$serverIp/32" -InterfaceIndex $lanIdx -NextHop $lanGw `
            -RouteMetric 1 -PolicyStore ActiveStore -ErrorAction Stop | Out-Null
        Write-Ok 'Da them route.'
        Get-NetRoute -DestinationPrefix "$serverIp/32" -ErrorAction SilentlyContinue |
            Format-Table ifIndex, DestinationPrefix, NextHop, RouteMetric -AutoSize
        Write-Host 'Luu y: route nay mat sau khi khoi dong lai may.' -ForegroundColor DarkGray
    } catch {
        Write-Err ("Khong them duoc route: {0}" -f $_.Exception.Message)
    }
}

function Menu-Network {
    while ($true) {
        Write-Title 'NETWORK FIX'
        Write-Host ' 1. Reset IP'
        Write-Host ' 2. Refresh Network Interface'
        Write-Host ' 3. Reconnect Network Drive'
        Write-Host ' 4. Fix route VPN'
        Write-Host ' 0. Quay lai'
        Write-Host ''
        switch (Read-Host 'Chon') {
            '1' { Net-ResetIP;          Pause-Back }
            '2' { Net-RefreshNic;       Pause-Back }
            '3' { Net-ReconnectDrives;  Pause-Back }
            '4' { Net-FixVpnRoute;      Pause-Back }
            '0' { return }
        }
    }
}

# ============================================================
#  2. CLEANUP
# ============================================================
function Clean-Quick {
    Write-Title 'Clean up - Don nhanh'
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
    Write-Title 'Clean up - Don sau'
    Write-Host 'Gom: file tam moi user, crash dump, shader cache, Delivery Optimization,'
    Write-Host 'va DISM StartComponentCleanup (co the mat vai phut).' -ForegroundColor Yellow
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
    Write-Title 'Clean up - Cache trinh duyet va ung dung'
    Write-Host 'Chi xoa cache. KHONG xoa cookie, mat khau, lich su, dang nhap.' -ForegroundColor Green
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

    Write-Step 'Office file cache va Teams (ban cu)'
    Clear-Folder "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
    foreach ($s in 'Cache', 'Code Cache', 'GPUCache', 'blob_storage', 'tmp', 'Service Worker\CacheStorage') {
        Clear-Folder (Join-Path "$env:APPDATA\Microsoft\Teams" $s)
    }

    Show-Freed $before
}

function Clean-Repair {
    Write-Title 'Clean up - Kiem tra va sua file he thong'
    Write-Host 'Chay DISM RestoreHealth roi sfc /scannow. Co the mat 10-30 phut.' -ForegroundColor Yellow
    if (-not (Confirm-YN 'Tiep tuc?')) { return }
    Write-Step 'DISM /Online /Cleanup-Image /RestoreHealth'
    dism.exe /Online /Cleanup-Image /RestoreHealth
    Write-Step 'sfc /scannow'
    sfc.exe /scannow
}

function Show-DiskUsage {
    Write-Title 'Clean up - Thu muc chiem nhieu dung luong'
    Write-Host 'Dang quet, co the mat 1-3 phut...' -ForegroundColor DarkGray
    function Top-Folders($root) {
        Write-Host "`nTop thu muc trong $root" -ForegroundColor Cyan
        Get-ChildItem $root -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
            ForEach-Object {
                Write-Host -NoNewline ("`r  Dang quet: {0}                    " -f $_.Name)
                $sum = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                [pscustomobject]@{ Folder = $_.FullName; GB = [math]::Round($sum / 1GB, 2) }
            } | Sort-Object GB -Descending | Select-Object -First 12 | Format-Table -AutoSize
    }
    Top-Folders "$env:SystemDrive\"
    Top-Folders $env:USERPROFILE
}

function Menu-Cleanup {
    while ($true) {
        Write-Title 'CLEANUP'
        Write-Host ' 1. Don nhanh      (temp, prefetch, update cache, thumbnail, DNS, thung rac)'
        Write-Host ' 2. Don sau        (+ temp moi user, crash dump, shader cache, WinSxS)'
        Write-Host ' 3. Cache trinh duyet va ung dung (Chrome, Edge, Firefox, Office, Teams)'
        Write-Host ' 4. Kiem tra va sua file he thong (DISM + SFC)'
        Write-Host ' 5. Xem thu muc chiem nhieu dung luong'
        Write-Host ' 0. Quay lai'
        Write-Host ''
        switch (Read-Host 'Chon') {
            '1' { Clean-Quick;      Pause-Back }
            '2' { Clean-Deep;       Pause-Back }
            '3' { Clean-BrowserApp; Pause-Back }
            '4' { Clean-Repair;     Pause-Back }
            '5' { Show-DiskUsage;   Pause-Back }
            '0' { return }
        }
    }
}

# ============================================================
#  3. OFFICE CHECK  (kiem tra + go key trong 1 buoc)
# ============================================================
function Office-Check {
    Write-Title 'Office check'

    $roots = @("$env:ProgramFiles\Microsoft Office", "${env:ProgramFiles(x86)}\Microsoft Office") | Where-Object { $_ -and (Test-Path $_) }
    $files = @()
    foreach ($r in $roots) {
        $files += Get-ChildItem $r -Recurse -Filter ospp.vbs -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
    }
    $files = @($files | Select-Object -Unique)
    if ($files.Count -eq 0) { Write-Err 'Khong tim thay ospp.vbs (Office chua cai hoac khong phai ban desktop).'; return }

    $found = @()
    foreach ($f in $files) {
        Write-Host ("== {0}" -f $f) -ForegroundColor Cyan
        $lines = @(& cscript.exe //nologo $f /dstatus 2>&1 | ForEach-Object { "$_" })
        $lines | ForEach-Object { Write-Host $_ }

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
        Write-Host 'Key dang cai:' -ForegroundColor Cyan
        for ($i = 0; $i -lt $found.Count; $i++) {
            Write-Host (" {0}. {1}   {2}   {3}" -f ($i + 1), $found[$i].Key, $found[$i].Status, $found[$i].Name)
        }
    } else {
        Write-Warn 'Khong tu doc duoc danh sach key (co the do Office khac ngon ngu). Van co the nhap tay.'
    }

    Write-Host ''
    $in = Read-Host 'Go key: nhap so thu tu / A = tat ca / 5 ky tu cuoi cua key (cach nhau bang dau cach). Enter = bo qua'
    if ([string]::IsNullOrWhiteSpace($in)) { return }

    $jobs = @()   # moi phan tu: @{Key; File}
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
    Write-Host ('Se go key: ' + (($jobs | ForEach-Object { $_.Key }) -join ', ')) -ForegroundColor Yellow
    if (-not (Confirm-YN 'Xac nhan go (khong hoan tac duoc)?')) { return }

    foreach ($j in $jobs) {
        Write-Step ("unpkey: {0}" -f $j.Key)
        & cscript.exe //nologo $j.File "/unpkey:$($j.Key)" 2>&1 | ForEach-Object { Write-Host $_ }
    }
}

# ============================================================
#  MENU CHINH
# ============================================================
$quit = $false
while (-not $quit) {
    Write-Title 'TOOLS WIN CMD'
    Write-Host ' 1. Network Fix'
    Write-Host ' 2. Cleanup'
    Write-Host ' 3. Office check'
    Write-Host ' 0. Thoat'
    Write-Host ''
    switch (Read-Host 'Chon') {
        '1' { Menu-Network }
        '2' { Menu-Cleanup }
        '3' { Office-Check; Pause-Back }
        '0' { $quit = $true }
    }
}
