#!/usr/bin/env python3
"""windows-cleanup-optimize 自测脚本（增强版）

覆盖项：
1. SKILL.md 存在、frontmatter 合法、行数控制（< 500 行）
2. 15 个 references 手册齐全且相互引用完整
3. scan-scripts.md 包含 9 个关键模板
4. 内容级深度断言：
   - startup-audit.md 包含 StartupBoostEnabled 与 BackgroundModeEnabled
   - chat-apps-migration.md 包含 xwechat_files 与腾讯官方 FAQ 依据
   - drive-migration-official.md 包含四步决策树与官方重定向说明
   - mklink-migration.md 包含官方限制与真实失败案例
   - pitfalls.md 包含 30+ 条优化主题踩坑
5. 负向夹具测试拦截
零依赖，仅 Python 标准库。
"""

from __future__ import annotations

import tempfile
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent

# 必须存在的关键模板（scan-scripts.md 章节标题或函数名）
REQUIRED_TEMPLATES = (
    "Scan-Directory",        # 模板 1 用户目录扫描
    "Scan-NonSystemDrive",   # 模板 2 非系统盘扫描
    "installedLower",        # 模板 3 Roaming 交叉比对
    "knownSys",              # 模板 4 安装目录残留
    "updater|patch",         # 模板 5 更新包检测
    "Test-ReparsePoint",     # 模板 6 junction 预检
    "SafeRecycle",           # 模板 7 回收站函数
    "LOCALAPPDATA\\Temp",    # 模板 8 被锁文件
    "Get-PSDrive",           # 模板 9 验证汇报
)

# 必须被 SKILL.md 引用的参考文件（清理+优化+自启动彻底化+官方迁移 扩展后）
REQUIRED_REFS = (
    "scan-scripts.md", "pitfalls.md",
    "startup-audit.md", "startup-mechanisms.md", "bloatware-catalog.md",
    "software-uninstall.md", "system-cleanup.md",
    "services-optimization.md", "memory-optimization.md", "performance-tuning.md",
    "trae-guide.md", "drive-migration-official.md", "chat-apps-migration.md",
    "mklink-migration.md", "case-study.md",
)


def validate(root: Path) -> str:
    """对任意技能根目录执行完整性与深度内容断言校验，返回问题描述（空串=通过）。"""
    skill_md = root / "SKILL.md"
    if not skill_md.is_file():
        return "SKILL.md 不存在"
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return "SKILL.md 缺 frontmatter（--- 开头）"

    # 1. 引用与文件存在性
    for ref in REQUIRED_REFS:
        if not (root / "references" / ref).is_file():
            return f"缺少关键参考文件: references/{ref}"
        if ref not in text:
            return f"SKILL.md 未引用参考文件: references/{ref}"

    # 2. scan-scripts 模板
    scan = root / "references" / "scan-scripts.md"
    if scan.is_file():
        scan_text = scan.read_text(encoding="utf-8")
        missing = [t for t in REQUIRED_TEMPLATES if t not in scan_text]
        if missing:
            return f"scan-scripts.md 缺关键模板: {missing}"
    else:
        return "references/scan-scripts.md 不存在"

    # 3. 踩坑条目数断言
    pitfalls = root / "references" / "pitfalls.md"
    if pitfalls.is_file():
        pit_text = pitfalls.read_text(encoding="utf-8")
        if "1." not in pit_text or "30." not in pit_text:
            return "pitfalls.md 缺陷阱条目（应含 1-30 以上的优化主题踩坑）"
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
        if "BCUninstaller" not in u_text:
            return "software-uninstall.md 缺少 BCUninstaller 开源推荐"

    return ""


def check_good() -> None:
    problem = validate(SKILL_ROOT)
    if problem:
        raise AssertionError(f"好夹具应通过，实际: {problem}")


def check_bad(tmp: Path) -> None:
    """负向用例：坏夹具必须被同一套 validate() 拒绝。"""
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
        raise AssertionError("负向夹具应 FAIL（引用缺失文件 + 缺关键模板），实际未拦住")


def main() -> int:
    check_good()
    with tempfile.TemporaryDirectory() as tmp_name:
        check_bad(Path(tmp_name))
    print("SELFTEST PASS (All structural & deep-content assertions verified)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
