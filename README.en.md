# 🧹 Windows Cleanup & Optimization Assistant / windows-cleanup-optimize

<div align="center">

**Zero-harm Windows deep cleanup & performance tuning with 15 reference manuals, bloatware eradication, native AI weight migration, and full rollback protection.**

**零伤害 Windows 深度清理与系统优化：15 本参考手册、流氓软件彻底根治、大模型原生换盘、每项操作可回退。**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/windows-cleanup-optimize?sort=semver)](CHANGELOG.md)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011%20%7C%2024H2-blue)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

[English](./README.en.md) | [中文](./README.md)

</div>

---

## 📖 What is this?

Drive C full red alert, slow boot times, persistent popups, background lag — **Windows Cleanup & Optimization Assistant** is a professional-grade Windows maintenance skill designed for AI Agents and system administrators.

It completely abandons dangerous "one-click brute-force deletion" practices, adhering to strict zero-harm principles: **User Profiling First, Recycle Bin Deletion (`SendToRecycleBin`), Official Native Data Migration, and 4-Level Risk Tagging with Rollback Commands**.

---

## ✨ Key Features

| Core Module | Capabilities | Value Delivered |
|---|---|---|
| **🛡️ Zero-Harm Safety Net** | Recycle Bin deletion by default, restore point creation, rollback commands attached | 100% protection against accidental system corruption |
| **🤖 Native AI Weight Migration** | Official environment variables for Ollama (`OLLAMA_MODELS`) and Hugging Face (`HF_HOME`) | Frees dozens to hundreds of GBs from Drive C natively |
| **🔍 Intelligent User Profiling** | Home / Developer / Gamer / Laptop profiles to automatically adapt recommendations | Prevents deleting developer toolchains or gaming services |
| **🧹 Bloatware & Popup Eradication** | 4-layer resurrection chain blocker for persistent background updaters | Targets root cause, completely preventing background respawns |
| **⚡ Win11 24H2 & Performance Tuning** | 24H2 cleanup bug safeguards, BitLocker preflight, 50+ service profiles, TRIM | Millisecond-level speedups in responsiveness and boot time |
| **🔄 Official Data Migration** | Native in-app migration优先, WeChat 4.x / QQ NT / DingTalk migration, mklink fallback | Highly stable and fully compliant with app auto-updates |
| **📋 15 Reference Manuals** | Comprehensive coverage from disk cleanup to software uninstall and service matrices | Deep knowledge base ensuring flawless AI agent decision making |

---

## 📊 6-Stage Complete Architecture

```
[Input: User reports Drive C Full / Slow Boot / Popups / Stutter]
                            │
         [Stage 1: User Profile Identification]
         Home / Developer / Gamer / Laptop Profile
                            │
         [Stage 2: Deep Safe Disk Cleanup]
         Large files / System cache / AI model migration / Recycle bin
                            │
         [Stage 3: Complete Startup Governance]
         20+ startup locations / Edge policy lock / AutoRuns
                            │
         [Stage 4: Software Uninstall & Residue Cleanup]
         4-layer bloatware blocker / Registry & service cleanup
                            │
         [Stage 5: Safe Service Streamlining]
         50+ service tuning with rollback scripts attached
                            │
         [Stage 6: Performance Tuning & Verification]
         Power plans / Working set / SSD TRIM / Restore points
```

---

## 🚀 Quick Start

This is an AI Agent Skill — install it into your AI assistant and you're ready.

### Option A: Paste one sentence into any Agent (recommended, most universal)

Send this to your AI assistant and it will detect the platform and clone to the right skills directory:

> Please install the windows-cleanup-optimize skill: clone `https://github.com/hyt315/windows-cleanup-optimize` into your skills directory (e.g. `~/.claude/skills/windows-cleanup-optimize` or `~/.agents/skills/windows-cleanup-optimize`) and confirm it works. When I report disk full, slow boot, or popups, guide me through the 6-stage workflow with zero-harm rollback safety.

### Option B: GitHub CLI 2.90+ (one command)

```bash
gh skill install hyt315/windows-cleanup-optimize windows-cleanup-optimize --agent claude-code --scope user
```

### Option C: Manual per-platform install

| Platform | Command |
|---|---|
| **Claude Code** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.claude/skills/windows-cleanup-optimize` |
| **Codex** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.agents/skills/windows-cleanup-optimize` |
| **Cursor** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.cursor/skills/windows-cleanup-optimize` |
| **General Agents** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.agents/skills/windows-cleanup-optimize` |

### Option D: Run local regression selftest

```powershell
python scripts/selftest.py
```

---

## 🔒 Zero-Harm Principles

1. **Recoverability Rule**: All file deletions go to Recycle Bin (`SendToRecycleBin`) by default;
2. **Official Migration First**: In-app settings and environment variables (e.g. `HF_HOME`) must be prioritized before `mklink /J`;
3. **Preflight System Protection**: Automatic creation of Windows System Restore Points before registry operations;
4. **Rollback Commands Attached**: Every service disable and registry tweak includes corresponding PowerShell rollback scripts.

---

## 📥 Download

| Method | Command / Link |
|---|---|
| **HTTPS** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git` |
| **SSH** | `git clone git@github.com:hyt315/windows-cleanup-optimize.git` |
| **GitHub CLI** | `gh repo clone hyt315/windows-cleanup-optimize` |
| **ZIP** | [Download ZIP](https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.zip) |
| **Tarball** | [Download Tar](https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.tar.gz) |
| **Single file (SKILL.md)** | `curl -O https://raw.githubusercontent.com/hyt315/windows-cleanup-optimize/main/SKILL.md` |

---

## 📖 15 In-Depth Reference Manuals

| Reference Guide | Core Focus | When to Read | Estimated Time |
|---|---|---|---|
| 📑 [**Scan Scripts Library (`scan-scripts.md`)**](references/scan-scripts.md) | 15 standard PowerShell execution scripts | When executing scans & cleanup | 4 mins |
| 🛡️ [**Pitfalls & Edge Cases (`pitfalls.md`)**](references/pitfalls.md) | 30+ edge cases and false-positive prevention | Before formulating cleanup plan | 4 mins |
| 🚀 [**Startup Audit (`startup-audit.md`)**](references/startup-audit.md) | Complete startup audit & Edge/Chrome policy lock | When diagnosing slow boot times | 3 mins |
| 🧩 [**Startup Mechanisms (`startup-mechanisms.md`)**](references/startup-mechanisms.md) | 20+ Windows startup locations & AutoRuns guide | When investigating stubborn updaters | 3 mins |
| 🧹 [**Bloatware Catalog (`bloatware-catalog.md`)**](references/bloatware-catalog.md) | Process signatures for intrusive popup suites | When eradicating popup adware | 3 mins |
| 🗑️ [**Software Uninstall (`software-uninstall.md`)**](references/software-uninstall.md) | Clean software uninstallation & deep registry sweeps | When removing stubborn apps | 3 mins |
| 💾 [**System Deep Cleanup (`system-cleanup.md`)**](references/system-cleanup.md) | Deep system cleanup (updates, driver store, hibernation) | When reclaiming C drive space | 4 mins |
| ⚙️ [**Services Streamlining (`services-optimization.md`)**](references/services-optimization.md) | 50+ Windows services tuning across 4 user profiles | When reducing CPU/RAM footprint | 4 mins |
| 🧠 [**Memory Optimization (`memory-optimization.md`)**](references/memory-optimization.md) | Working set optimization & memory leak diagnostics | When troubleshooting high RAM usage | 3 mins |
| ⚡ [**Performance Tuning (`performance-tuning.md`)**](references/performance-tuning.md) | Power plans, visual effects, SSD TRIM, IRQ tuning | When boosting frame rates/responsiveness | 3 mins |
| 🤖 [**AI IDE Cleanup (`trae-guide.md`)**](references/trae-guide.md) | Trae / VS Code AI IDE cache cleanup & migration | When developer IDE caches bloat | 3 mins |
| 📂 [**Official Directory Migration (`drive-migration-official.md`)**](references/drive-migration-official.md) | Large directory migration tree & AI weights | When moving large directories | 4 mins |
| 💬 [**Chat Apps Migration (`chat-apps-migration.md`)**](references/chat-apps-migration.md) | WeChat 4.x / QQ NT / DingTalk official migration | When moving chat history databases | 3 mins |
| 🔗 [**Directory Junction Fallback (`mklink-migration.md`)**](references/mklink-migration.md) | `mklink /J` junction migration safeguards | When hard junctions are necessary | 3 mins |
| 📚 [**Real-World Case Studies (`case-study.md`)**](references/case-study.md) | End-to-end case studies from red alert to healthy | When reviewing complete workflows | 3 mins |

---

## 📁 File Structure

```
windows-cleanup-optimize/
├── SKILL.md                          # Core skill definition and 6-stage workflow
├── README.md                         # Chinese documentation
├── README.en.md                      # English documentation
├── CHANGELOG.md                      # Version history
├── LICENSE                           # MIT License
├── .gitignore                        # Git ignore rules
├── CONTRIBUTING.md                   # Contribution guide
├── CODE_OF_CONDUCT.md                # Code of conduct
├── SECURITY.md                       # Security policy
├── SUPPORT.md                        # Support channels
├── manifest.json                     # Skill manifest
├── agents/                           # Multi-agent metadata
├── scripts/
│   ├── validate_repo.py              # Validator
│   └── selftest.py                   # Automated regression test runner
└── references/                       # 15 Reference Manuals
```

---

## ❓ FAQ

- **Q: Will cleaning delete my personal files or break Windows?**  
  A: Never. All file removals go to the Recycle Bin (`SendToRecycleBin`), restore points are created beforehand, and 30+ pitfalls are actively checked.
- **Q: How are WeChat 4.x and QQ NT databases safely moved?**  
  A: Using official in-app storage path settings and native configuration keys, ensuring 100% database integrity.
- **Q: Why use official environment variables for Ollama/HuggingFace models?**  
  A: Native environment variables (`OLLAMA_MODELS`, `HF_HOME`) are natively supported by the AI engines, avoiding file-lock and permission bugs common with symlinks.

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). If this skill helped you, please give it a [Star ⭐](https://github.com/hyt315/windows-cleanup-optimize/stargazers)!

---

## 📄 License

Licensed under the [MIT License](LICENSE).

---

> 🌏 **中文版: [README.md](./README.md)**
