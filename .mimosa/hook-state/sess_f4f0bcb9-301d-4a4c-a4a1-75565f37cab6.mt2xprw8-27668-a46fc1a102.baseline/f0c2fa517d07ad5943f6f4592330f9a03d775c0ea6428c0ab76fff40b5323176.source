#!/usr/bin/env python3
"""windows-cleanup-optimize 自测：验证技能文档结构完整、引用齐全、关键模板存在。

好夹具（本技能自身）：SKILL.md 存在、frontmatter 合法、所有引用的 references 文件在盘、
scan-scripts.md 含 9 个关键模板函数/章节、pitfalls.md 含 30+ 条陷阱。
负向用例（临时构造）：缺引用文件 + 缺关键模板的技能，应被同一套校验逻辑拒绝。
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

# 必须被 SKILL.md 引用的参考文件（清理+优化双线扩展后）
REQUIRED_REFS = (
    "scan-scripts.md", "pitfalls.md",
    "startup-audit.md", "bloatware-catalog.md", "software-uninstall.md",
    "system-cleanup.md",
    "services-optimization.md", "memory-optimization.md", "performance-tuning.md",
    "trae-guide.md", "mklink-migration.md", "case-study.md",
)


def validate(root: Path) -> str:
    """对任意技能根目录执行完整性校验，返回问题描述（空串=通过）。"""
    skill_md = root / "SKILL.md"
    if not skill_md.is_file():
        return "SKILL.md 不存在"
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return "SKILL.md 缺 frontmatter（--- 开头）"
    for ref in REQUIRED_REFS:
        if ref in text and not (root / "references" / ref).is_file():
            return f"SKILL.md 引用了不存在的文件 references/{ref}"
    scan = root / "references" / "scan-scripts.md"
    if scan.is_file():
        scan_text = scan.read_text(encoding="utf-8")
        missing = [t for t in REQUIRED_TEMPLATES if t not in scan_text]
        if missing:
            return f"scan-scripts.md 缺关键模板: {missing}"
    else:
        return "references/scan-scripts.md 不存在"
    pitfalls = root / "references" / "pitfalls.md"
    if pitfalls.is_file():
        pit_text = pitfalls.read_text(encoding="utf-8")
        # 优化主题扩展后，pitfalls 应含 ≥ 30 条（原 29 + 新增优化踩坑）
        if "1." not in pit_text or "30." not in pit_text:
            return "pitfalls.md 缺陷阱条目（应含 1-30 以上的优化主题踩坑）"
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
    print("SELFTEST PASS (2 checks)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
