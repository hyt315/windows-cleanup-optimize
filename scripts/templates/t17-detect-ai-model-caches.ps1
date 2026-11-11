# 模板 17：detect-ai-model-caches（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 17 节。
# v2.1.2：体积改用 Measure-WcoDirectory（模型目录常被 mklink 迁到别的盘，旧写法在 5.1 下会重复计数）。
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Find-AiDevCache {
    $aiTargets = @(
        @{ Label = "Ollama 本地大模型"; Path = "$env:USERPROFILE\.ollama\models" },
        @{ Label = "HuggingFace 权重缓存"; Path = "$env:USERPROFILE\.cache\huggingface" },
        @{ Label = "ModelScope 魔搭社区"; Path = "$env:USERPROFILE\.cache\modelscope" },
        @{ Label = "PyTorch 权重缓存"; Path = "$env:USERPROFILE\.cache\torch" },
        @{ Label = "Python uv 依赖缓存"; Path = "$env:LOCALAPPDATA\uv\cache" },
        @{ Label = "Android AVD 虚拟机"; Path = "$env:USERPROFILE\.android\avd" },
        @{ Label = "Cursor 代码索引缓存"; Path = "$env:APPDATA\Cursor\User\workspaceStorage" },
        @{ Label = "Gradle 依赖缓存"; Path = "$env:USERPROFILE\.gradle\caches" }
    )
    foreach ($t in $aiTargets) {
        if (Test-Path -LiteralPath $t.Path) {
            $size = (Measure-WcoDirectory -Path $t.Path).Bytes
            if ($size -gt 100MB) {
                $sizeGB = [math]::Round($size / 1GB, 2)
                Write-Host ("[AI/Dev] {0,-22} 占用: {1,6} GB -> {2}" -f $t.Label, $sizeGB, $t.Path)
            }
        }
    }
}
