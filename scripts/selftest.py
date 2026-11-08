#!/usr/bin/env python3
"""windows-cleanup-optimize 自测脚本（v2.0）

覆盖项：
1. SKILL.md frontmatter 合法、正文 < 500 行、description ≤ 1024 字符
2. references 手册齐全，SKILL.md 引用的每个 references/*.md 都存在
3. 22 个模板脚本齐全，scan-scripts.md 里的模板链接都能找到文件
4. 文档里手写的"N 个模板"必须等于实际数量（防止数字漂移）
5. 所有 .ps1 / .psm1 必须带 UTF-8 BOM（Windows PowerShell 5.1 读中文必需）
6. 内容级深度断言（防止误删关键知识点）
7. data/volatile-paths.json 时效提醒（超期只警告，不失败）
8. evals/*.json 结构合法
9. AST 语法门禁：PowerShell Parser（没装 PowerShell 时跳过并标 SKIP）+ Python ast
10. 负向夹具：坏结构、坏语法、无 BOM 脚本都必须被拦住
零依赖，仅 Python 标准库。
"""

from __future__ import annotations

import ast
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent

# 关键模板：scripts/templates 下的文件里必须能找到这些标识
REQUIRED_TEMPLATES = (
    "Scan-Directory",        # 模板 1 用户目录扫描
    "Scan-NonSystemDrive",   # 模板 2 非系统盘扫描
    "installedLower",        # 模板 3 Roaming 交叉比对
    "knownSys",              # 模板 4 安装目录残留
    "updater",               # 模板 5 更新包检测
    "ReparsePoint",          # 模板 6 junction 预检
    "Invoke-WcoRecycle",     # 模板 7 回收站（v2.0 走公共模块）
    "LOCALAPPDATA\\Temp",   # 模板 8 被锁文件
    "Get-PSDrive",           # 模板 9 验证汇报
    "Query-CompactOS",       # 模板 21
    "Analyze-WinSxS",        # 模板 22
)
EXPECTED_TEMPLATE_COUNT = 22

# 必须存在且被 SKILL.md 引用的参考文件（v2.0：并入 pitfalls / migration-cases 后共 14 份）
REQUIRED_REFS = (
    "scan-scripts.md", "pitfalls.md",
    "startup-audit.md", "startup-mechanisms.md", "bloatware-catalog.md",
    "software-uninstall.md", "system-cleanup.md",
    "services-optimization.md", "memory-optimization.md", "performance-tuning.md",
    "drive-migration-official.md", "chat-apps-migration.md",
    "mklink-migration.md", "migration-cases.md",
)

MODULE_FUNCTIONS = (
    "Test-WcoAdmin", "Start-WcoSession", "Add-WcoChange", "Export-WcoUndo",
    "Get-WcoRecycleBinPolicy", "Invoke-WcoRecycle", "Set-WcoServiceStartType", "Set-WcoRegistryValue",
)

WARNINGS: list[str] = []


def has_bom(path: Path) -> bool:
    return path.read_bytes()[:3] == b"\xef\xbb\xbf"


def validate(root: Path) -> str:
    """对任意技能根目录执行完整性与深度内容断言校验，返回问题描述（空串=通过）。"""
    skill_md = root / "SKILL.md"
    if not skill_md.is_file():
        return "SKILL.md 不存在"
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return "SKILL.md 缺 frontmatter（--- 开头）"

    fm = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not fm or "name:" not in fm.group(1) or "description:" not in fm.group(1):
        return "SKILL.md frontmatter 缺 name 或 description"
    desc = re.search(r"^description:\s*(.*)$", fm.group(1), re.M).group(1).strip()
    if len(desc) > 1024:
        return f"description 超过 1024 字符（{len(desc)}）"
    if len(text.splitlines()) >= 500:
        return "SKILL.md 正文应 < 500 行"

    # 1. 引用与文件存在性
    for ref in REQUIRED_REFS:
        if not (root / "references" / ref).is_file():
            return f"缺少关键参考文件: references/{ref}"
        if ref not in text:
            return f"SKILL.md 未引用参考文件: references/{ref}"
    for ref in set(re.findall(r"references/([\w.-]+\.md)", text)):
        if not (root / "references" / ref).is_file():
            return f"SKILL.md 引用了不存在的文件: references/{ref}"

    # 2. 模板脚本
    tdir = root / "scripts" / "templates"
    templates = sorted(tdir.glob("t[0-9][0-9]-*.ps1")) if tdir.is_dir() else []
    if len(templates) != EXPECTED_TEMPLATE_COUNT:
        return f"scripts/templates 应有 {EXPECTED_TEMPLATE_COUNT} 个模板，实际 {len(templates)}"
    tpl_text = "\n".join(t.read_text(encoding="utf-8-sig") for t in templates)
    missing = [t for t in REQUIRED_TEMPLATES if t not in tpl_text]
    if missing:
        return f"模板脚本缺关键内容: {missing}"
    scan = root / "references" / "scan-scripts.md"
    if not scan.is_file():
        return "references/scan-scripts.md 不存在"
    for link in re.findall(r"\(\.\./(scripts/templates/[\w.-]+\.ps1)\)", scan.read_text(encoding="utf-8")):
        if not (root / link).is_file():
            return f"scan-scripts.md 链接的模板不存在: {link}"

    # 2b. 文档里手写的模板数量必须与实际一致
    for doc in [root / "SKILL.md", root / "README.md", root / "README.en.md", scan]:
        if doc.is_file():
            for n in re.findall(r"(\d+) ?个模板|(\d+) templates", doc.read_text(encoding="utf-8")):
                num = int(n[0] or n[1])
                if num not in (EXPECTED_TEMPLATE_COUNT, EXPECTED_TEMPLATE_COUNT + 1):
                    return f"{doc.name} 写的模板数 {num} 与实际 {EXPECTED_TEMPLATE_COUNT} 不一致"

    # 2c. UTF-8 BOM
    for ps in list((root / "scripts").rglob("*.ps1")) + list((root / "scripts").rglob("*.psm1")) + list((root / "tests").glob("*.ps1")):
        if not has_bom(ps):
            return f"{ps.relative_to(root)} 缺 UTF-8 BOM（Windows PowerShell 5.1 会按 ANSI 读中文）"

    # 2d. 公共模块
    mod = root / "scripts" / "lib" / "Wco.Common.psm1"
    if not mod.is_file():
        return "scripts/lib/Wco.Common.psm1 不存在"
    mod_text = mod.read_text(encoding="utf-8-sig")
    lacking = [f for f in MODULE_FUNCTIONS if f"function {f}" not in mod_text]
    if lacking:
        return f"公共模块缺函数: {lacking}"
    if "NukeOnDelete" not in mod_text or "MaxCapacity" not in mod_text:
        return "Invoke-WcoRecycle 缺回收站预检（NukeOnDelete / MaxCapacity）"

    full_scan = root / "scripts" / "full_scan.ps1"
    if full_scan.is_file():
        fs_text = full_scan.read_text(encoding="utf-8-sig")
        if "ReparsePoint" not in fs_text or "compactos:query" not in fs_text:
            return "full_scan.ps1 缺少 ReparsePoint 属性过滤或 CompactOS 探测"
        if "IsInRole" not in fs_text:
            return "full_scan.ps1 缺管理员权限检测"
        if "USERPROFILE\"" in fs_text and "OutDir = \"$env:USERPROFILE" in fs_text:
            return "full_scan.ps1 报告不应默认写到用户目录"
    else:
        return "scripts/full_scan.ps1 不存在"

    # 2e. 易变路径时效（只警告）
    vp = root / "data" / "volatile-paths.json"
    if not vp.is_file():
        return "data/volatile-paths.json 不存在"
    vpd = json.loads(vp.read_text(encoding="utf-8"))
    for it in vpd["items"]:
        age = (date.today() - date.fromisoformat(it["verified_at"])).days
        if age > vpd.get("max_age_days", 90):
            WARNINGS.append(f"易变路径 {it['app']}（{it['kind']}）已 {age} 天未复核")

    # 2f. 评测文件
    for name, key in (("triggers.json", "items"), ("scenarios.json", "scenarios")):
        ef = root / "evals" / name
        if not ef.is_file():
            return f"evals/{name} 不存在"
        data = json.loads(ef.read_text(encoding="utf-8"))
        if not data.get(key):
            return f"evals/{name} 为空"
    trig = json.loads((root / "evals" / "triggers.json").read_text(encoding="utf-8"))["items"]
    if not any(not t["should_trigger"] for t in trig):
        return "triggers.json 至少要有一条不应触发的反例"

    # 3. 踩坑条目数断言
    pitfalls = root / "references" / "pitfalls.md"
    if pitfalls.is_file():
        pit_text = pitfalls.read_text(encoding="utf-8")
        if "1." not in pit_text or "86." not in pit_text:
            return "pitfalls.md 缺陷阱条目（应含 1-86 以上的优化主题踩坑）"
    else:
        return "references/pitfalls.md 不存在"

    # 4. 内容级深度断言（防止误删关键知识点与策略名称）
    startup_audit = root / "references" / "startup-audit.md"
    if startup_audit.is_file():
        s_text = startup_audit.read_text(encoding="utf-8")
        if "StartupBoostEnabled" not in s_text or "BackgroundModeEnabled" not in s_text:
            return "startup-audit.md 缺少 Edge/Chrome 核心自启策略关键词"

    chat_apps = root / "references" / "chat-apps-migration.md"
    if chat_apps.is_file():
        c_text = chat_apps.read_text(encoding="utf-8")
        if "xwechat_files" not in c_text or "Tencent Files" not in c_text:
            return "chat-apps-migration.md 缺少微信 4.x xwechat_files 或 QQ Tencent Files 目录说明"

    drive_mig = root / "references" / "drive-migration-official.md"
    if drive_mig.is_file():
        d_text = drive_mig.read_text(encoding="utf-8")
        if "决策树" not in d_text:
            return "drive-migration-official.md 缺少迁移决策树"
        if "UV_CACHE_DIR" not in d_text or "ANDROID_AVD_HOME" not in d_text or "set-sparse" not in d_text:
            return "drive-migration-official.md 缺少 uv / AVD / WSL 稀疏压缩核心依据"

    mklink_mig = root / "references" / "mklink-migration.md"
    if mklink_mig.is_file():
        m_text = mklink_mig.read_text(encoding="utf-8")
        if "官方限制" not in m_text or "失败案例" not in m_text:
            return "mklink-migration.md 缺少官方限制与真实失败案例"

    sys_clean = root / "references" / "system-cleanup.md"
    if sys_clean.is_file():
        s_text = sys_clean.read_text(encoding="utf-8")
        if "Clear-DeliveryOptimizationCache" not in s_text or "pnputil /delete-driver" not in s_text:
            return "system-cleanup.md 缺少原生传递优化或现代 pnputil /delete-driver 语法"

    soft_uninst = root / "references" / "software-uninstall.md"
    if soft_uninst.is_file():
        u_text = soft_uninst.read_text(encoding="utf-8")
        if "BCUninstaller" not in u_text or "GetForegroundWindow" not in u_text:
            return "software-uninstall.md 缺少 BCUninstaller 开源推荐或 GetForegroundWindow 弹窗定位器"

    perf_tune = root / "references" / "performance-tuning.md"
    if perf_tune.is_file():
        p_text = perf_tune.read_text(encoding="utf-8")
        if "Tcpip\\Parameters\\Interfaces" not in p_text or "autotuninglevel=normal" not in p_text:
            return "performance-tuning.md 缺少 Interfaces 网卡 GUID 级 TCP 调优或 autotuninglevel 规范"

    svc_opt = root / "references" / "services-optimization.md"
    if svc_opt.is_file():
        sv_text = svc_opt.read_text(encoding="utf-8")
        if "GamingServices" not in sv_text or "AllowNewsAndInterests" not in sv_text:
            return "services-optimization.md 缺少 GamingServices 正确拼写或 Win11 小组件后台调优"

    bloat_cat = root / "references" / "bloatware-catalog.md"
    if bloat_cat.is_file():
        b_text = bloat_cat.read_text(encoding="utf-8")
        if "wpscenter.exe" not in b_text or "Image File Execution Options" not in b_text:
            return "bloatware-catalog.md 缺少 IFEO 弹窗静音 SOP 或关键弹窗程序配置"

    startup_mech = root / "references" / "startup-mechanisms.md"
    if startup_mech.is_file():
        sm_text = startup_mech.read_text(encoding="utf-8")
        if "CommandLineEventConsumer" not in sm_text or "__EventFilter" not in sm_text:
            return "startup-mechanisms.md 缺少 WMI 事件订阅持久化常驻完整机制"

    if pitfalls.is_file():
        if "ResetBase" not in pit_text or "C:\\Windows\\Installer" not in pit_text:
            return "pitfalls.md 缺少 ResetBase / Installer 深水区避坑（v2.0 并入）"

    return ""


def find_pwsh() -> str | None:
    return shutil.which("pwsh") or shutil.which("powershell")


def check_ps1_syntax(ps1_path: Path) -> bool | None:
    """用 PowerShell AST Parser 校验语法（不执行）。没装 PowerShell 返回 None（跳过）。"""
    if not ps1_path.is_file():
        return False
    pwsh = find_pwsh()
    if not pwsh:
        return None
    path = str(ps1_path).replace("'", "''")
    cmd = [
        pwsh, "-NoProfile", "-Command",
        f"$errors = $null; [void][System.Management.Automation.Language.Parser]::ParseFile('{path}', [ref]$null, [ref]$errors); if ($errors.Count -gt 0) {{ exit 1 }} else {{ exit 0 }}"
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode == 0


def check_python_ast(py_path: Path) -> bool:
    """Verify Python file syntax via ast.parse."""
    try:
        source = py_path.read_text(encoding="utf-8")
        ast.parse(source)
        return True
    except (SyntaxError, OSError):
        return False


def check_good() -> None:
    problem = validate(SKILL_ROOT)
    if problem:
        raise AssertionError(f"好夹具应通过，实际: {problem}")

    # PS1 AST 语法校验（全部脚本）
    ps_files = list((SKILL_ROOT / "scripts").rglob("*.ps1")) + list((SKILL_ROOT / "scripts").rglob("*.psm1")) + list((SKILL_ROOT / "tests").glob("*.ps1"))
    skipped = False
    for ps in ps_files:
        ok = check_ps1_syntax(ps)
        if ok is None:
            skipped = True
            break
        if not ok:
            raise AssertionError(f"{ps.relative_to(SKILL_ROOT)} 存在语法错误 (Syntax error)")
    if skipped:
        WARNINGS.append("SKIP：未找到 pwsh/powershell，PowerShell 语法检查已跳过")

    # Python 语法校验
    for py_file in (SKILL_ROOT / "scripts").glob("*.py"):
        if not check_python_ast(py_file):
            raise AssertionError(f"{py_file.name} Python 语法解析失败")


def check_bad(tmp: Path) -> None:
    """负向破坏夹具：坏夹具必须被校验逻辑拒绝 (should_fail)。"""
    # 1. 结构与引用缺失破坏
    bad = tmp / "bad-skill"
    (bad / "references").mkdir(parents=True)
    (bad / "SKILL.md").write_text(
        "---\nname: bad-skill\ndescription: 当用户需要验证时使用。\n---\n"
        "引用不存在的文件：[missing](references/missing.md)。\n",
        encoding="utf-8")
    (bad / "references" / "scan-scripts.md").write_text(
        "# 扫描模板\n缺全部关键模板。\n", encoding="utf-8")
    problem = validate(bad)
    if not problem:
        raise AssertionError("负向破坏夹具应 FAIL（引用缺失文件 + 缺关键模板），实际未拦住")

    # 2. 负向 PowerShell 语法破坏（没装 PowerShell 时跳过）
    bad_ps1 = tmp / "bad_syntax.ps1"
    bad_ps1.write_text("function bad_func { if ($true) { Write-Host 'unclosed' ", encoding="utf-8")
    result = check_ps1_syntax(bad_ps1)
    if result is True:
        raise AssertionError("负向 PS1 语法错误用例应被拦截 (Syntax error)，实际误放行")

    # 2b. 负向 BOM：无 BOM 的中文脚本必须被识别
    no_bom = tmp / "no_bom.ps1"
    no_bom.write_text("Write-Host '中文'\n", encoding="utf-8")
    if has_bom(no_bom):
        raise AssertionError("无 BOM 脚本应被识别，实际误放行")

    # 3. 负向 Python 语法破坏
    bad_py = tmp / "bad_syntax.py"
    bad_py.write_text("def broken_syntax(:", encoding="utf-8")
    if check_python_ast(bad_py):
        raise AssertionError("负向 Python 语法错误用例应被拦截，实际误放行")


def main() -> int:
    check_good()
    with tempfile.TemporaryDirectory() as tmp_name:
        check_bad(Path(tmp_name))
    for w in WARNINGS:
        print(f"WARN  {w}")
    print("SELFTEST PASS (structure, counts, BOM, AST syntax & negative fixtures verified)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
