# 模板 16：audit-shell-extensions（v2.1：改为调用公共模块 Get-WcoShellExtension，纯只读）
# 用法：
#   .\t16-audit-shell-extensions.ps1                 # 审计右键菜单处理程序与图标覆盖
#   .\t16-audit-shell-extensions.ps1 -ShowMicrosoft  # 连同微软签名的条目一起列出
# v2.1 修正：
#   - 处理程序键名不是 GUID（如 7-Zip、WinRAR）时读它的默认值作为 CLSID，不再丢弃；
#   - CLSID 到 Classes\CLSID\{GUID}\InprocServer32 解析（HKCU、HKLM 原生与 WOW6432Node 两个视图，即 HKCR 合并视图）；
#   - "已知良性"按实现 DLL 的 Microsoft Authenticode 签名判断，不再按名字里有没有 Shell/Windows/Microsoft；
#   - 与 data/bloatware-catalog.json 的关键词比对，命中标为疑似 bloatware（需人工确认，不据此自动处置）。
param(
    [switch]$ShowMicrosoft
)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

# === 1. 从 catalog 取关键词（catalog 缺失或格式不符时退回内置名单）===
$fallbackPatterns = @('360', '2345', 'HaoZip', 'KuaiZip', 'FlashCenter', 'SogouService', 'QQPCMgr', 'LDSMain',
    'BaiduNetdisk', 'MojingWallpaper', 'HaoZhuoDao', 'TodayHot', 'NewsPush', 'Meitu', 'AlibabaProtect', 'KSafe', 'KXETray')

function Get-CatalogPattern {
    param($Node, [string]$Key = '')
    if ($null -eq $Node) { return }
    if ($Node -is [string]) {
        # 只取标识类字段（进程 / 服务 / Shell 扩展 / 关键词 / 签名者），跳过说明、链接、日期
        if ($Key -match '(?i)process|service|shell|keyword|pattern|dll|signer' -and
            $Key -notmatch '(?i)url|source|note|desc|date|confidence') {
            $v = ($Node -replace '(?i)\.(exe|dll)$', '').Trim()
            if ($v.Length -ge 3 -and $v -notmatch '^(?i)(microsoft|windows|shell|explorer)$' -and $v -notmatch '[\\/:*?]') { $v }
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($i in $Node) { Get-CatalogPattern -Node $i -Key $Key }
        return
    }
    foreach ($p in $Node.PSObject.Properties) { Get-CatalogPattern -Node $p.Value -Key $p.Name }
}

$patternSource = 'data/bloatware-catalog.json'
try {
    $catalog = Get-WcoBloatwareCatalog
    $bloatwarePatterns = @(Get-CatalogPattern -Node $catalog | Select-Object -Unique)
    if ($bloatwarePatterns.Count -eq 0) { throw '未读到关键词' }
} catch {
    $bloatwarePatterns = $fallbackPatterns
    $patternSource = "内置名单（catalog 不可用：$($_.Exception.Message)）"
}

# === 2. 枚举 + CLSID 解析 + 签名判定（模块内完成，只读）===
$items = @(Get-WcoShellExtension -BloatPattern $bloatwarePatterns)
$finding = @{
    'Good'      = @($items | Where-Object { $_.Category -eq 'Microsoft' })
    'Bloatware' = @($items | Where-Object { $_.Category -eq 'Bloat' })
    'ThirdParty' = @($items | Where-Object { $_.Category -eq 'ThirdParty' })
    'Unknown'   = @($items | Where-Object { $_.Category -eq 'Unknown' })
}

function Write-ShellItem {
    param($Item)
    $label = if ($Item.Handler -eq $Item.CLSID) { $Item.CLSID } else { "$($Item.Handler) $($Item.CLSID)" }
    Write-Host ("  [{0}] {1,-50} {2}  -> {3}  签名: {4} ({5})" -f $Item.Kind, $label, $Item.Name, $Item.Impl, $Item.Signer, $Item.SignatureStatus)
}

# === 3. 输出 ===
Write-Host "关键词来源：$patternSource（$($bloatwarePatterns.Count) 个）"
Write-Host "共枚举 $($items.Count) 个处理程序 / 图标覆盖"
if ($env:OS -ne 'Windows_NT') { Write-Host '  （非 Windows 环境，未扫描）' }

Write-Host ""
Write-Host "===== 良性 Shell 扩展（实现 DLL 有有效的 Microsoft 签名）：$($finding.Good.Count) 个 ====="
if ($ShowMicrosoft) { $finding.Good | ForEach-Object { Write-ShellItem $_ } } else { Write-Host '  （加 -ShowMicrosoft 列出明细）' }

Write-Host ""
Write-Host "===== 警告 疑似 bloatware（命中 catalog 关键词，需人工确认）====="
if ($finding.Bloatware.Count -eq 0) { Write-Host "  （无）" }
$finding.Bloatware | ForEach-Object { Write-ShellItem $_ }

Write-Host ""
Write-Host "===== 第三方（有效签名，非微软；核对是否为你主动安装的软件）====="
if ($finding.ThirdParty.Count -eq 0) { Write-Host "  （无）" }
$finding.ThirdParty | ForEach-Object { Write-ShellItem $_ }

Write-Host ""
Write-Host "===== 未知 / 待定（无签名、签名无效或找不到实现文件）====="
if ($finding.Unknown.Count -eq 0) { Write-Host "  （无）" }
$finding.Unknown | ForEach-Object { Write-ShellItem $_ }

# === 4. 可选：列出 HKLM Approved 白名单（很少，主要用于诊断）===
$approved = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved" -EA SilentlyContinue
if ($approved) {
    $approved.PSObject.Properties | Where-Object Name -notmatch '^(PS|Provider)' |
        ForEach-Object { Write-Host ("Approved: {0}" -f $_.Name) }
}
