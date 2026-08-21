<div align="center">

# 🧹 Windows 清理与优化助手 / Windows Cleanup & Optimization Assistant

**Zero-harm: all cleanup goes to Recycle Bin (reversible), every optimization item has a 4-level risk tag and a restore command.**

**English · [简体中文](./README.md)**

[![License: MIT](https://img.shields.io/github/license/hyt315/windows-cleanup-optimize)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/windows-cleanup-optimize?sort=semver)](https://github.com/hyt315/windows-cleanup-optimize/releases)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![Tests](https://github.com/hyt315/windows-cleanup-optimize/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/windows-cleanup-optimize/actions)
[![Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

</div>

---

## What is this?

C drive full, slow boot, pop-up ads, system lagging — **Windows Cleanup & Optimization Assistant** is an AI Agent Skill that uses a **6-stage workflow** (user profiling → disk cleanup → startup optimization → software management → service optimization → performance tuning) to diagnose and fix your PC. **All cleanup goes to the Recycle Bin (reversible), every optimization item has a 4-level risk tag and a restore command.**

### Core Features

| Feature | Description |
|---------|-------------|
| 🛡️ **Zero-harm guarantee** | Cleanup via `SendToRecycleBin`, system directories untouched, restore points before key operations, every optimization reversible |
| 🔍 **Smart user profiling** | 4 profiles (family / developer / gamer / laptop), asked once, never repeated, recommendations auto-adapt |
| 🧹 **Bloatware identification** | Auto-detect 360 / 2345 / pop-up advertising bundled software, safe uninstall guidance |
| ⚡ **Deep optimization** | Service tuning (telemetry, Xbox, etc.), memory tuning, power plan, SSD TRIM — all reversible |
| 🔄 **Data migration** | Move large C-drive directories to D drive via `mklink /J`, no file copy needed |
| 📋 **14 reference manuals** | Disk cleanup, uninstall, services, pitfalls, case studies, and more |

---

## 🚀 Quick Start

> ✨ **One-liner install into your AI agent**: paste this to your AI assistant and it will install itself:
>
> ```text
> Please install the windows-cleanup-optimize Skill: clone https://github.com/hyt315/windows-cleanup-optimize into your skills directory (Claude Code: ~/.claude/skills/windows-cleanup-optimize/; Cursor: ~/.cursor/skills/; Codex/ChatGPT: .agent/skills/ in your project), and verify that SKILL.md, references/, and scripts/ are all present. Whenever I report "C drive full / slow boot / pop-up ads / system is lagging", follow the SKILL.md workflow and use the 6-stage diagnosis with reversible operations.
> ```

Then pick your platform:

| Platform | Install |
|----------|---------|
| **Claude Code** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.claude/skills/windows-cleanup-optimize` |
| **Cursor** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.cursor/skills/windows-cleanup-optimize` |
| **Codex / ChatGPT** | `.agent/skills/windows-cleanup-optimize/` in your project (with `agents/openai.yaml`) |
| **Generic** | Any agent's skills directory |

---

## 📥 Download / Install

```bash
# HTTPS
git clone https://github.com/hyt315/windows-cleanup-optimize.git

# SSH
git clone git@github.com:hyt315/windows-cleanup-optimize.git

# GitHub CLI
gh repo clone hyt315/windows-cleanup-optimize

# ZIP
# https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.zip

# Single file (SKILL.md only)
curl -O https://raw.githubusercontent.com/hyt315/windows-cleanup-optimize/main/SKILL.md
```

---

## 📁 File Structure

```
windows-cleanup-optimize/
├── SKILL.md                     # entry point (6-stage workflow + zero-harm safety principles)
├── references/                  # 14 reference manuals (disk/services/software/memory/performance/pitfalls)
├── scripts/
│   └── selftest.py              # regression tests
├── LICENSE
├── README.md  /  README.en.md  # bilingual docs (this file is English)
├── CHANGELOG.md
├── .github/                     # Issue/PR templates + CI
└── CONTRIBUTING.md / CODE_OF_CONDUCT.md / SECURITY.md
```

---

## ▶️ Quick Usage

The skill uses a **6-stage workflow**. On first run, it asks for your user profile (family/developer/gamer/laptop), then you can enter any stage as needed:

1. **Stage 0 — User Profile**: asked once, recommendations auto-adapt
2. **Stage 1 — Disk Cleanup**: C-drive space scan, AppData cache cleanup (via Recycle Bin), large directory analysis
3. **Stage 2 — Startup Optimization**: startup/shutdown item audit, disable on demand
4. **Stage 3 — Software Management**: bloatware identification, residue cleanup
5. **Stage 4 — Service Optimization**: safely disable-able Windows services list (4 risk levels)
6. **Stage 5 — Performance Tuning**: power plan, memory, SSD TRIM, visual effects

> All operations create a `Checkpoint-Computer` restore point first; every optimization item has a restore command; any ambiguous judgment is presented to the user for confirmation.

---

## 💬 When to trigger

Say any of these to your AI agent to trigger this skill:

- "C drive is full" / "low disk space" / "clean up my PC"
- "Slow boot" / "too many startup items"
- "Pop-up ads" / "suspected bloatware or bundled software"
- "Suspicious background processes" / "my PC is laggy"
- "Do a system tune-up"

## ⚙️ Prerequisites

- **Windows 10 / 11** (PowerShell 5.1+ built in, nothing extra to install)
- Some operations (service tuning, driver-related, restore points) need **admin rights** (UAC prompt)
- Zero third-party dependencies: cleanup uses the system Recycle Bin API — no cleaner software installed

## 📦 Sample Output

A full run produces:

```text
📋 Space scan report   — C-drive top directories / reclaimable cache per category (read-only scan)
🧹 Cleanup checklist   — every item marked "recoverable via Recycle Bin", before/after space comparison
🚫 Bloatware list      — identification + safe uninstall steps + registry/scheduled-task residue cleanup
⚡ Service tuning table— each item tagged ✅LOW / ⚠️MEDIUM / 🔴HIGH / ❌CRITICAL + its restore command
🔄 Restore point       — Checkpoint-Computer automatically before key operations
```

---

## 🤝 Contribute / Feedback

- Report bugs / suggestions: use the repo's Issue templates
- Contribute: see [CONTRIBUTING.md](CONTRIBUTING.md); run `python scripts/selftest.py` before any PR
- Security: see [SECURITY.md](SECURITY.md) (private vulnerability reporting, not public issues)

---

## 📜 License

[MIT](LICENSE) © 2026 hyt315

> 🌏 **中文版: [README.md](./README.md)**