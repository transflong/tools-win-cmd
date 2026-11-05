# ============================================================
#  Don dep PC - chay bang:  irm https://tools.transflong.eu.cc | iex
# ============================================================

$ScriptUrl = 'https://tools.transflong.eu.cc'

# ----- Tu nang quyen Administrator -----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host 'Dang yeu cau quyen Administrator...' -ForegroundColor Yellow
    $cmd = "irm $ScriptUrl | iex"
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
    return
}

$Host.UI.RawUI.WindowTitle = 'Don dep PC'

function Get-FreeSpace { (Get-PSDrive C).Free }
function Clear-Folder($path) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host '=========================================' -ForegroundColor Cyan
Write-Host '          DON DEP PC TU DONG'              -ForegroundColor Cyan
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Script se xoa: file tam, Prefetch, cache Windows Update,'
Write-Host 'thumbnail/icon cache, DNS cache, log cu va thung rac.'
Write-Host 'Khong dong vao du lieu ca nhan.' -ForegroundColor Green
Write-Host ''
$confirm = Read-Host 'Nhan Enter de bat dau (hoac go N de huy)'
if ($confirm -match '^[nN]') { return }

$before = Get-FreeSpace

Write-Host '[1/8] Xoa file tam cua nguoi dung...'
Clear-Folder $env:TEMP

Write-Host '[2/8] Xoa file tam cua Windows...'
Clear-Folder "$env:SystemRoot\Temp"

Write-Host '[3/8] Xoa Prefetch...'
Clear-Folder "$env:SystemRoot\Prefetch"

Write-Host '[4/8] Xoa cache Windows Update...'
Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue
Clear-Folder "$env:SystemRoot\SoftwareDistribution\Download"
Start-Service bits, wuauserv -ErrorAction SilentlyContinue

Write-Host '[5/8] Xoa cache thumbnail va icon...'
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue

Write-Host '[6/8] Xoa cache DNS...'
ipconfig /flushdns | Out-Null

Write-Host '[7/8] Xoa Windows Error Reporting va log cu...'
Clear-Folder "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
Clear-Folder "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
Remove-Item "$env:SystemRoot\Logs\CBS\*.log" -Force -ErrorAction SilentlyContinue

Write-Host '[8/8] Don thung rac...'
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

$after  = Get-FreeSpace
$freed  = [math]::Round(($after - $before) / 1MB, 2)

Write-Host ''
Write-Host '=========================================' -ForegroundColor Green
Write-Host '              HOAN TAT!'                   -ForegroundColor Green
Write-Host '=========================================' -ForegroundColor Green
Write-Host ("Trong o C truoc : {0} GB" -f [math]::Round($before / 1GB, 2))
Write-Host ("Trong o C sau   : {0} GB" -f [math]::Round($after  / 1GB, 2))
Write-Host ("Giai phong      : {0} MB" -f $freed)
Write-Host ''
Read-Host 'Nhan Enter de thoat'