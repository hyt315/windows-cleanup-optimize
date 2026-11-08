# 模板 17：detect-ai-model-caches（从 references/scan-scripts.md 抽出，v2.0）
# 用法见 references/scan-scripts.md 第 17 节。

function Scan-AiAndDevCaches {
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
        if (Test-Path $t.Path) {
            $size = (Get-ChildItem $t.Path -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum -EA SilentlyContinue).Sum
            if ($size -gt 100MB) {
                $sizeGB = [math]::Round($size / 1GB, 2)
                Write-Host ("[AI/Dev] {0,-22} 占用: {1,6} GB -> {2}" -f $t.Label, $sizeGB, $t.Path)
            }
        }
    }
}
