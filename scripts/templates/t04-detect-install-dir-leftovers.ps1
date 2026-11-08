# 模板 4：detect-install-dir-leftovers（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 4 节。

# 步骤 1：收集已安装应用匹配词（注册表 DisplayName + 开始菜单，同模板 3 的 Step 2）
# 步骤 2：扫描安装目录一级 vs 匹配词，无匹配即"疑似残留"
$progBases = @("C:\Program Files", "C:\Program Files (x86)",
               "D:\Program Files", "D:\Program Files (x86)", "$env:LOCALAPPDATA\Programs")
$knownSys = @('common files','windows nt','internet explorer','windows defender',
              'microsoft shared','windows media player','reference assemblies',
              'msbuild','dotnet','windows kits','windowsapps','modifiablewindowsapps',
              'windows powershell')  # 系统/共享目录，跳过
foreach ($pb in $progBases) {
    if (-not (Test-Path $pb)) { continue }
    Get-ChildItem $pb -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $dirLower = $_.Name.ToLower()
        if ($knownSys -contains $dirLower) { return }
        $match = $installedLower | Where-Object {
            $_ -match [regex]::Escape($dirLower) -or $dirLower -match [regex]::Escape($_)
        } | Select-Object -First 1
        if (-not $match) {
            # 输出: 大小 | 目录名 | 路径 | 最后写入时间
        }
    }
}
