# 模板 17：detect-ai-model-caches（从 references/scan-scripts.md 抽出，v2.2）
# 用法见 references/scan-scripts.md 第 17 节。
# v2.2：扩充 2025-2026 主流 AI IDE 与 Agent（Cursor/Windsurf/Antigravity/WorkBuddy/DoubaoWork/CatPaw/CodeArts/Claude/Codex/LM Studio 等），体积统一走 Measure-WcoDirectory。
Import-Module (Join-Path $PSScriptRoot '..\lib\Wco.Common.psm1') -Force

function Find-AiDevCache {
    $aiTargets = @(
        @{ Label = "Ollama 本地大模型"; Path = "$env:USERPROFILE\.ollama\models" },
        @{ Label = "LM Studio 本地模型"; Path = "$env:USERPROFILE\.lmstudio\models" },
        @{ Label = "HuggingFace 权重缓存"; Path = "$env:USERPROFILE\.cache\huggingface" },
        @{ Label = "ModelScope 魔搭社区"; Path = "$env:USERPROFILE\.cache\modelscope" },
        @{ Label = "PyTorch 权重缓存"; Path = "$env:USERPROFILE\.cache\torch" },
        @{ Label = "Python uv 依赖缓存"; Path = "$env:LOCALAPPDATA\uv\cache" },
        @{ Label = "Android AVD 虚拟机"; Path = "$env:USERPROFILE\.android\avd" },
        @{ Label = "Gradle 依赖缓存"; Path = "$env:USERPROFILE\.gradle\caches" },
        @{ Label = "Cursor 代码索引缓存"; Path = "$env:APPDATA\Cursor\User\workspaceStorage" },
        @{ Label = "Windsurf 代码索引缓存"; Path = "$env:APPDATA\Windsurf\User\workspaceStorage" },
        @{ Label = "Antigravity CLI/Agent"; Path = "$env:USERPROFILE\.gemini" },
        @{ Label = "Claude Code 数据"; Path = "$env:USERPROFILE\.claude" },
        @{ Label = "Codex CLI 数据"; Path = "$env:USERPROFILE\.codex" },
        @{ Label = "OpenCode 客户端"; Path = "$env:LOCALAPPDATA\Programs\OpenCode" },
        @{ Label = "ZCode AI 工作区"; Path = "$env:USERPROFILE\.zcode" },
        @{ Label = "WorkBuddy 主目录"; Path = "$env:USERPROFILE\.workbuddy" },
        @{ Label = "WorkBuddy AI 缓存"; Path = "$env:USERPROFILE\.workbuddy-ai" },
        @{ Label = "CatPaw 助手缓存"; Path = "$env:USERPROFILE\.meituan-catpaw" },
        @{ Label = "DoubaoWork 数据"; Path = "$env:LOCALAPPDATA\DoubaoWork" },
        @{ Label = "DeepSeek Harness (.dsh)"; Path = "$env:USERPROFILE\.dsh" },
        @{ Label = "MiniMax 数据"; Path = "$env:USERPROFILE\.minimax" },
        @{ Label = "Mavis AI 数据"; Path = "$env:USERPROFILE\.mavis" },
        @{ Label = "CodeArts 主目录"; Path = "$env:USERPROFILE\.codearts" },
        @{ Label = "CodeArts Doer"; Path = "$env:USERPROFILE\.codeartsdoer" },
        @{ Label = "TRAE SOLO CN"; Path = "$env:APPDATA\TRAE SOLO CN" },
        @{ Label = "TRAE CN 隐藏目录"; Path = "$env:USERPROFILE\.trae-cn" },
        @{ Label = "CherryStudio"; Path = "$env:USERPROFILE\.cherrystudio" }
    )
    foreach ($t in $aiTargets) {
        if ($t.Path -and (Test-Path -LiteralPath $t.Path)) {
            $size = (Measure-WcoDirectory -Path $t.Path).Bytes
            if ($size -ge 50MB) {
                $sizeGB = [math]::Round($size / 1GB, 2)
                Write-Host ("[AI/Dev] {0,-24} 占用: {1,6} GB -> {2}" -f $t.Label, $sizeGB, $t.Path)
            }
        }
    }
}

Find-AiDevCache
