#!/usr/bin/env python3
"""windows-cleanup-optimize 自测脚本（v2.2.1）

覆盖项：
1. SKILL.md frontmatter 合法、正文 < 500 行、description ≤ 1024 字符
2. references 手册齐全，SKILL.md / README*.md 引用的本地相对路径都存在
3. 模板脚本齐全且编号连续，scan-scripts.md 里的模板链接都能找到文件
4. 计数单一来源：模板、手册、避坑、特征库家族的数量从文件本身数出，README（中英）/SKILL/scan-scripts 里写的数字必须一致
4b. 文档与脚本引用的 Verb-Wco* 函数都在公共模块里定义（脚本调用的还必须已导出），T 编号都有对应模板
5. 所有 .ps1 / .psm1 必须带 UTF-8 BOM（Windows PowerShell 5.1 读中文必需）
6. 内容级深度断言（防止误删关键知识点，校验 pitfalls 1..N 连续编号）
7. data/volatile-paths.json 时效提醒（超期只警告，不失败）
8. evals/*.json 结构合法
9. AST 语法门禁：PowerShell Parser（没装 PowerShell 时跳过并标 SKIP）+ Python ast
10. 负向夹具：坏结构、坏语法、无 BOM 脚本、数字漂移、引用不存在的函数/模板都必须被拦住
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
    "Measure-Directory",        # 模板 1 用户目录扫描
    "Measure-NonSystemDrive",   # 模板 2 非系统盘扫描
    "installedLower",        # 模板 3 Roaming 交叉比对
    "knownSys",              # 模板 4 安装目录残留
    "updater",               # 模板 5 更新包检测
    "ReparsePoint",          # 模板 6 junction 预检
    "Invoke-WcoRecycle",     # 模板 7 回收站（v2.0 走公共模块）
    "LOCALAPPDATA\\Temp",   # 模板 8 被锁文件
    "Get-PSDrive",           # 模板 9 验证汇报
    "Get-CompactOSState",       # 模板 21
    "Measure-WinSxS",        # 模板 22
    "NativeMessagingHosts",  # 模板 23 浏览器劫持
    "SilentProcessExit",     # 模板 24 扩展自启动
    "Get-WcoInstalledProgram",  # 模板 25 程序盘点
)
# 下限：防止模板被误删。实际数量以 scripts/templates 下的文件为准，文档里的数字由 check_counts 对齐。
MIN_TEMPLATE_COUNT = 25

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
    "Get-WcoStartupApprovedGhost",
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
    if len(templates) < MIN_TEMPLATE_COUNT:
        return f"scripts/templates 至少应有 {MIN_TEMPLATE_COUNT} 个模板，实际 {len(templates)}"
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

    # 2b. README 本地链接真实存在性与文档内手写模板数量校验
    for rdoc_name in ("README.md", "README.en.md"):
        rdoc = root / rdoc_name
        if rdoc.is_file():
            for raw_link in re.findall(r"\[[^\]]+\]\(([^)]+)\)", rdoc.read_text(encoding="utf-8")):
                link = raw_link.strip()
                if not link or link.startswith(("http://", "https://", "mailto:", "#")):
                    continue
                rel = link.split("#", 1)[0].split("?", 1)[0]
                if rel and not (root / rel).exists():
                    return f"{rdoc_name} 引用了不存在的本地路径: {raw_link}"
    # 2a. 版本号单一来源：manifest.json；README 徽章与 full_scan 头注释必须一致
    ver = json.loads((root / "manifest.json").read_text(encoding="utf-8")).get("version", "") if (root / "manifest.json").is_file() else ""
    if ver:
        fs_head = (root / "scripts" / "full_scan.ps1").read_text(encoding="utf-8-sig")[:2000]
        m = re.search(r"版本：v([\d.]+)", fs_head)
        if m and m.group(1) != ver:
            return f"full_scan.ps1 头注释版本 v{m.group(1)} 与 manifest.json 的 {ver} 不一致"
        for rd in ("README.md", "README.en.md"):
            if (root / rd).is_file():
                b = re.search(r"Version-v([\d.]+)-", (root / rd).read_text(encoding="utf-8"))
                if b and b.group(1) != ver:
                    return f"{rd} 版本徽章 v{b.group(1)} 与 manifest.json 的 {ver} 不一致"
        if f"## [{ver}]" not in (root / "CHANGELOG.md").read_text(encoding="utf-8"):
            return f"CHANGELOG.md 缺 [{ver}] 条目"

    # 2b'. 计数单一来源：模板数、手册数、避坑条数、特征库家族数都从文件本身数出来，
    #      README（中英）、SKILL.md、scan-scripts.md 里手写的数字必须与之一致（v2.2.1）。
    err = check_counts(root, len(templates))
    if err:
        return err
    # 2b''. 文档和脚本引用的公共模块函数、模板编号都真实存在（v2.2.1）
    err = check_references(root, len(templates))
    if err:
        return err

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
        if ("ReparsePoint" not in fs_text and "Measure-WcoDirectory" not in fs_text) or "compactos:query" not in fs_text:
            return "full_scan.ps1 缺少不跟随 junction 的测量（ReparsePoint 过滤或 Measure-WcoDirectory）或 CompactOS 探测"
        if "IsInRole" not in fs_text and "Test-WcoAdmin" not in fs_text:
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

    # 3. 踩坑条目数与连续编号断言
    pitfalls = root / "references" / "pitfalls.md"
    if pitfalls.is_file():
        pit_text = pitfalls.read_text(encoding="utf-8")
        nums = [int(n) for n in re.findall(r"(?m)^(\d+)\. \*\*", pit_text)]
        if not nums or max(nums) < 80:
            return "pitfalls.md 踩坑条目不足（v2.2 应至少 80 条）"
        if nums != list(range(1, len(nums) + 1)):
            return f"pitfalls.md 踩坑编号不连续或存在重号：{nums}"
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
        if "UV_CACHE_DIR" not in d_text or "ANDROID_AVD_HOME" not in d_text or "--compact" not in d_text:
            return "drive-migration-official.md 缺少 uv / AVD / WSL --compact 压缩依据"

    mklink_mig = root / "references" / "mklink-migration.md"
    if mklink_mig.is_file():
        m_text = mklink_mig.read_text(encoding="utf-8")
        if "官方限制" not in m_text or "失败案例" not in m_text:
            return "mklink-migration.md 缺少官方限制与真实失败案例"

    sys_clean = root / "references" / "system-cleanup.md"
    if sys_clean.is_file():
        s_text = sys_clean.read_text(encoding="utf-8")
        if "Delete-DeliveryOptimizationCache" not in s_text or "pnputil /delete-driver" not in s_text:
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

    # 5. 流氓软件特征库（v2.1）
    cat = root / "data" / "bloatware-catalog.json"
    if not cat.is_file():
        return "data/bloatware-catalog.json 不存在"
    try:
        catd = json.loads(cat.read_text(encoding="utf-8"))
    except ValueError as e:
        return f"bloatware-catalog.json 不是合法 JSON：{e}"
    if catd.get("schema") != 1 or not catd.get("families"):
        return "bloatware-catalog.json 缺 schema=1 或 families"
    ids = set()
    for fam in catd["families"]:
        for k in ("id", "name", "confidence", "sources"):
            if k not in fam:
                return f"bloatware-catalog.json 家族 {fam.get('id', '?')} 缺字段 {k}"
        if fam["confidence"] not in ("high", "medium", "low"):
            return f"bloatware-catalog.json 家族 {fam['id']} confidence 非法"
        if fam["id"] in ids:
            return f"bloatware-catalog.json 家族 id 重复：{fam['id']}"
        ids.add(fam["id"])

    return ""


COUNT_PATTERNS = {
    "templates": (r"(\d+) ?个(?:脚本)?模板", r"(\d+) (?:script )?templates"),
    "references": (r"(\d+) ?份参考手册", r"(\d+) reference manuals"),
    "pitfalls": (r"(\d+) ?条(?:实战|按主题归类的)?(?:避坑|踩坑)", r"(\d+) (?:real-world )?pitfalls"),
    "families": (r"(\d+) ?个家族", r"(\d+) families"),
}


def actual_counts(root: Path, template_count: int) -> dict:
    pit = (root / "references" / "pitfalls.md").read_text(encoding="utf-8")
    nums = [int(n) for n in re.findall(r"(?m)^(\d+)\. \*\*", pit)]
    cat = json.loads((root / "data" / "bloatware-catalog.json").read_text(encoding="utf-8"))
    return {
        "templates": template_count,
        "references": len(list((root / "references").glob("*.md"))),
        "pitfalls": max(nums) if nums else 0,
        "families": len(cat.get("families", [])),
    }


def check_counts(root: Path, template_count: int) -> str:
    try:
        real = actual_counts(root, template_count)
    except (OSError, ValueError) as e:
        return f"计数校验读不到源文件：{e}"
    docs = [root / "SKILL.md", root / "README.md", root / "README.en.md", root / "references" / "scan-scripts.md"]
    for doc in docs:
        if not doc.is_file():
            continue
        text = doc.read_text(encoding="utf-8")
        for key, pats in COUNT_PATTERNS.items():
            for pat in pats:
                for m in re.finditer(pat, text):
                    n = int(m.group(1))
                    if n != real[key]:
                        line = text.count("\n", 0, m.start()) + 1
                        return f"{doc.name}:{line} 写的 {key} 数为 {n}，实际为 {real[key]}（计数以文件本身为准）"
    tnums = sorted(int(p.name[1:3]) for p in (root / "scripts" / "templates").glob("t[0-9][0-9]-*.ps1"))
    if tnums != list(range(1, len(tnums) + 1)):
        return f"模板编号不连续：{tnums}"
    return ""


def check_references(root: Path, template_count: int) -> str:
    mod = (root / "scripts" / "lib" / "Wco.Common.psm1").read_text(encoding="utf-8-sig")
    defined = set(re.findall(r"(?m)^function ([A-Z][a-z]+-Wco[A-Za-z]+)", mod))
    exp = re.search(r"Export-ModuleMember -Function (.*)", mod, re.S)
    exported = set(re.findall(r"[A-Z][a-z]+-Wco[A-Za-z]+", exp.group(1))) if exp else set()
    sources = [root / "SKILL.md", root / "README.md", root / "README.en.md", root / "scripts" / "full_scan.ps1"]
    sources += sorted((root / "references").glob("*.md")) + sorted((root / "scripts" / "templates").glob("*.ps1"))
    for src in sources:
        text = src.read_text(encoding="utf-8-sig")
        for fn in sorted(set(re.findall(r"\b([A-Z][a-z]+-Wco[A-Za-z]+)\b", text))):
            if fn not in defined:
                return f"{src.relative_to(root)} 引用了公共模块里不存在的函数 {fn}"
            if src.suffix == ".ps1" and fn not in exported:
                return f"{src.relative_to(root)} 调用了公共模块未导出的函数 {fn}"
    # T 编号：T0 是 full_scan 的开机耗时段；T1..Tn 对应模板文件；T5C 这类后缀是 full_scan 的分段
    for src in [root / "SKILL.md"] + sorted((root / "references").glob("*.md")):
        text = src.read_text(encoding="utf-8")
        for m in re.finditer(r"(?<![A-Za-z0-9_])T(\d{1,2})(?![0-9])", text):
            n = int(m.group(1))
            if n > template_count:
                return f"{src.relative_to(root)} 引用了不存在的模板 T{n}（共 {template_count} 个）"
        for link in re.findall(r"scripts/templates/(t\d\d-[\w.-]+\.ps1)", text):
            if not (root / "scripts" / "templates" / link).is_file():
                return f"{src.relative_to(root)} 引用了不存在的模板文件 {link}"
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

    # 1b. 计数与引用破坏：拷一份真实技能，只改一处，必须被拦住（v2.2.1）
    import shutil as _sh
    for name, mutate in (
        ("count-readme", lambda r: (r / "README.md").write_text(
            (r / "README.md").read_text(encoding="utf-8") + "\n共 999 条实战避坑。\n", encoding="utf-8")),
        ("count-en", lambda r: (r / "README.en.md").write_text(
            (r / "README.en.md").read_text(encoding="utf-8") + "\n999 families\n", encoding="utf-8")),
        ("ghost-function", lambda r: (r / "references" / "pitfalls.md").write_text(
            (r / "references" / "pitfalls.md").read_text(encoding="utf-8") + "\n用 `Remove-WcoEverything` 清理。\n", encoding="utf-8")),
        ("ghost-template", lambda r: (r / "SKILL.md").write_text(
            (r / "SKILL.md").read_text(encoding="utf-8") + "\n再跑 T99。\n", encoding="utf-8")),
    ):
        copy = tmp / f"mut-{name}"
        _sh.copytree(SKILL_ROOT, copy, ignore=_sh.ignore_patterns(".git", "dist", "__pycache__"))
        mutate(copy)
        if not validate(copy):
            raise AssertionError(f"负向夹具 {name} 应 FAIL，实际未拦住")

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
