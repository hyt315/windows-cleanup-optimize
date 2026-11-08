# 模板 12：snapshot-services（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 12 节。

# 导出所有服务状态（备份用）
New-Item -ItemType Directory -Path "$env:TEMP\wco" -Force | Out-Null   # v2.0：输出统一放 %TEMP%\wco
$backupFile = "$env:TEMP\wco\services_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
# v2.0：多记一列 ScStart（sc.exe 能直接用的值：auto / delayed-auto / demand / disabled）。
# v1.x 只记 Get-Service 的 StartType（Automatic / Manual），直接喂给 sc.exe 会报参数错误，批量恢复其实是失败的。
Get-CimInstance Win32_Service | ForEach-Object {
    $sc = switch ($_.StartMode) { 'Auto' { if ($_.DelayedAutoStart) { 'delayed-auto' } else { 'auto' } } 'Manual' { 'demand' } 'Disabled' { 'disabled' } default { $_.StartMode.ToLower() } }
    [pscustomobject]@{ Name = $_.Name; DisplayName = $_.DisplayName; StartMode = $_.StartMode; ScStart = $sc; State = $_.State }
} | Export-Csv $backupFile -NoTypeInformation -Encoding UTF8
"已备份: $backupFile"

# 列出可优化的服务（按画像筛选）
$optimizable = @(
    "DiagTrack","dmwappushservice","diagnosticshub.standardcollector.service","DusmSvc",
    "XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","BcastDVRUserService",
    "RemoteRegistry","Fax","WerSvc","lfsvc","MapsBroker",
    "WbioSrvc","SCardSvr","SCPolicySvc","CertPropSvc",
    "AdobeARMservice","AdobeUpdateService","GoogleUpdate*","JavaUpdateSched"
)
Get-Service | Where-Object { $_.Name -in $optimizable -or $_.Name -like "GoogleUpdate*" } |
    Format-Table Name, DisplayName, StartType, Status -AutoSize
