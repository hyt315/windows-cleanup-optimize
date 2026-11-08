# 模板 8：clean-temp-locked（v2.0：逐项走 Invoke-WcoRecycle，被占用的跳过；默认只演练）
param([switch]$Apply)
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force
$tempPath = "$env:LOCALAPPDATA\Temp"
$stat = @{}
Get-ChildItem $tempPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $r = Invoke-WcoRecycle -Path $_.FullName -Label $_.Name -Apply:$Apply
    $stat[$r.Status] = 1 + [int]$stat[$r.Status]
}
$stat.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host ("{0,-9} {1} 项" -f $_.Name, $_.Value) }
Write-Host '被占用（Locked）是正常的：重启电脑后再清即可。'
if ($Apply) { [void](Export-WcoUndo) }
