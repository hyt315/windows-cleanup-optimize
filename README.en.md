<p align="center">
  <img src="assets/banner.svg" alt="Windows Cleanup & Optimize Banner" width="100%" />
</p>

# 🧹 Windows Cleanup & Optimization Assistant

<div align="center">

**A Windows cleanup skill that runs a read-only diagnosis first, then proposes a tiered plan. It ships 14 reference manuals and 22 script templates. Every change is previewed first, applied only after you confirm, logged, and reversible through a generated undo script.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/hyt315/windows-cleanup-optimize?sort=semver)](CHANGELOG.md)
[![CI](https://github.com/hyt315/windows-cleanup-optimize/actions/workflows/ci.yml/badge.svg)](https://github.com/hyt315/windows-cleanup-optimize/actions/workflows/ci.yml)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-1f6feb)](SKILL.md)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

[English](./README.en.md) | [中文](./README.md)

</div>

---

## 📖 What is this?

C drive in the red, slow boot, pop-ups that keep coming back, background lag: **Windows Cleanup & Optimization Assistant** is a Windows 10 / 11 maintenance skill for AI agents. You can also run its scripts yourself.

It avoids "one-click cleanup" and follows these principles:

- **Scan read-only first** and decide based on measured numbers.
- **Delete only to the Recycle Bin**, and only after checking that the bin can actually hold the item.
- **Use official migration paths first.**
- **Give every change a risk tier.** Preview it first, apply it only after you confirm, and keep an undo script.

---

## ✨ Key Features

| Core Module | Capabilities | Value Delivered |
|---|---|---|
| **🛡️ Reversible by design** | Write operations dry-run by default and apply only with `-Apply`. Changes are logged to `changes.json`, and an `undo.ps1` is generated. Services are restored to their original start type | Every step is visible and can be undone |
| **🗑️ Truly recoverable deletes** | Deletes go to the Recycle Bin only. Deletion is refused on volumes without a bin (USB, network), when the bin is set to delete immediately, or when the item exceeds the bin's size limit | Nothing is "sent to the bin" and silently gone for good |
| **🔍 One scan entry point** | `full_scan.ps1` runs every read-only template in one pass. It infers the user profile automatically (home / developer / AI / gamer / laptop), checks admin rights, and measures boot time | No questionnaire first; the health card comes straight from the scan |
| **🧹 Bloatware & pop-up eradication** | winget inventory and uninstall, IFEO pop-up silencing, a 3-second pop-up locator, and a WMI persistence / shortcut-hijack audit. 360 / 2345 / WPS playbooks use the official uninstaller first | Fixes the cause, not just the symptom |
| **🤖 Dev & AI environment migration** | Dev Drive for package caches (npm / pip / NuGet / Cargo / Gradle). Environment variables for Ollama, Hugging Face, ModelScope, uv and Android AVD. WSL2 sparse-disk shrink | Tens of GB freed without turning off Defender |
| **⚡ Win11 modern tuning** | 50+ services tuned by profile, Widgets and WebView2 suppression, Copilot / Recall switches, per-adapter TCP tuning, SSD TRIM | Only tweaks with a measurable payoff are recommended |
| **🔄 Official data migration** | Windows Cleanup recommendations and Storage Sense first. WeChat 4.x / WeCom / QQ NT / DingTalk move through in-app settings. `mklink` is a last resort | App updates keep working |
| **📋 14 reference manuals** | Disk cleanup, Windows.old, uninstalling, services, startup mechanisms, chat-app migration, 86 field pitfalls, plus deep-water baselines | The agent reads only the manual the problem needs |

---

## 📊 6-Stage Workflow

```
[Input: Drive C full / slow boot / stutter / pop-ups]
                            │
         [Stage 1: Read-only diagnosis]
         full_scan.ps1 / auto profile / admin check / measured boot time
                            │
         [Stage 2: Health card & tiers]
         Disk · Boot · Software · Background / 🟢🟡🟠🔴 plan
                            │
         [Stage 3: Pick a preset]
         Caches only / Standard / Deep, or pick items yourself
                            │
         [Stage 4: Dry run, then apply on confirmation]
         Recycle-bin checks / original values recorded / restore point first
                            │
         [Stage 5: Verify & roll back]
         Before/after space and boot time / undo.ps1
                            │
         [Stage 6: One-page report]
         What was freed, what changed, where the undo script is
```

---

## 🚀 Quick Start

This is an AI Agent Skill. Install it into your AI assistant and it is ready to use.

### Option A: Paste one sentence into any Agent (recommended, most universal)

Send this to your AI assistant. It will detect the platform and clone the skill into the right directory:

> Please install the windows-cleanup-optimize skill: clone `https://github.com/hyt315/windows-cleanup-optimize` into your skills directory (e.g. `~/.claude/skills/windows-cleanup-optimize` or `~/.agents/skills/windows-cleanup-optimize`) and confirm it works. When I report disk full, slow boot, pop-ups or lag, follow the 6-stage workflow in SKILL.md: diagnose read-only first, preview every change, and apply it only after I confirm.

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

### Option D: Run the scan and tests yourself

```powershell
# Elevated PowerShell, from the repo folder; the scan is read-only and its report opens with a pre-flight check
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\full_scan.ps1   # read-only, report in %TEMP%\wco
python scripts/selftest.py                                                    # structure / counts / BOM / syntax
Invoke-Pester ./tests                                                         # module unit tests (Pester 5+)
```

---

## 🔒 Safety Principles

1. **Read-only diagnosis.** Scans change no settings and delete nothing. To prove it, CI runs the scan on Windows and compares services, Run keys and the power plan before and after.
2. **Preview, confirm, then apply.** Each tier needs a different level of confirmation:
   - 🟢 One confirmation covers the whole list.
   - 🟡 Confirm per group.
   - 🟠 Confirm per item, with the trade-off stated.
   - 🔴 Not done by default.
3. **Recoverable deletes.** Items go to the Recycle Bin only. The three cases where that would silently become permanent are refused.
4. **Reversible changes.** Service, registry and IFEO changes record the original value and generate `undo.ps1`. A restore point is created before touching drivers or system components.
5. **Official paths first.**
   - For cleanup, start with Windows Cleanup recommendations.
   - For migration, use in-app settings, environment variables or Dev Drive.
   - `mklink /J` is a last resort.
6. **Hard limits.** Never disable Defender or Windows Update, never run `/ResetBase`, never empty `C:\Windows\Installer`.

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

## 📖 14 Reference Manuals

| Reference Guide | Core Focus | When to Read | Estimated Time |
|---|---|---|---|
| 📑 [**Scan Scripts Index (`scan-scripts.md`)**](references/scan-scripts.md) | What each of the 22 templates does and when to use it; code lives in `scripts/templates/` | When running scans & cleanup | 2 mins |
| 🛡️ [**Pitfalls (`pitfalls.md`)**](references/pitfalls.md) | 86 field pitfalls plus deep-water baselines (DISM, Installer, VSS, cloud files) | Before making a plan | 5 mins |
| 🚀 [**Startup Audit (`startup-audit.md`)**](references/startup-audit.md) | Startup audit; policy-level shutdown of Edge / Chrome startup boost and background mode | Slow boot | 3 mins |
| 🧩 [**Startup Mechanisms (`startup-mechanisms.md`)**](references/startup-mechanisms.md) | How 20+ startup points work, WMI persistence, AutoRuns | Stubborn autostarts | 3 mins |
| 🧹 [**Bloatware Catalog (`bloatware-catalog.md`)**](references/bloatware-catalog.md) | Process signatures for 360 / 2345 / Sogou / Baidu suites, IFEO pop-up silencing | Pop-up adware | 3 mins |
| 🗑️ [**Software Uninstall (`software-uninstall.md`)**](references/software-uninstall.md) | winget inventory, deep leftovers, WPS / 360 / DingTalk playbooks (official uninstaller first) | Removing stubborn apps | 4 mins |
| 💾 [**System Cleanup (`system-cleanup.md`)**](references/system-cleanup.md) | Windows Cleanup recommendations first, Windows.old, cleanmgr, DISM, driver store, hibernation | Reclaiming C drive | 4 mins |
| ⚙️ [**Services (`services-optimization.md`)**](references/services-optimization.md) | 50+ services by profile, Copilot / Recall switches, rollback to original values | Reducing background load | 4 mins |
| 🧠 [**Memory (`memory-optimization.md`)**](references/memory-optimization.md) | Real leak detection, memory compression, working-set analysis | High RAM usage | 3 mins |
| ⚡ [**Performance (`performance-tuning.md`)**](references/performance-tuning.md) | Power plans, visual effects, TRIM; Dev Drive before any Defender exclusion | Responsiveness | 3 mins |
| 📂 [**Official Migration (`drive-migration-official.md`)**](references/drive-migration-official.md) | Migration decision tree, Dev Drive package caches, AI model env vars | Moving dev & model folders | 4 mins |
| 💬 [**Chat Apps (`chat-apps-migration.md`)**](references/chat-apps-migration.md) | Official migration and cache cleanup for WeChat 4.x / WeCom / QQ NT / DingTalk | Huge chat-app folders | 3 mins |
| 🔗 [**Junction Fallback (`mklink-migration.md`)**](references/mklink-migration.md) | `mklink /J` limits, preflight checks, failure cases | When only a junction will do | 3 mins |
| 📚 [**Migration Cases (`migration-cases.md`)**](references/migration-cases.md) | End-to-end real cases, including TRAE / VS Code AI IDEs | Reviewing whole workflows | 4 mins |

---

## 📁 File Structure

```
windows-cleanup-optimize/
├── SKILL.md                          # Safety rules, 6-stage workflow, symptom-to-manual routing
├── README.md                         # Chinese documentation
├── README.en.md                      # English documentation
├── CHANGELOG.md                      # Version history
├── LICENSE                           # MIT License
├── CONTRIBUTING.md                   # Contribution guide
├── CODE_OF_CONDUCT.md                # Code of conduct
├── SECURITY.md                       # Security policy
├── manifest.json                     # Skill manifest
├── .github/workflows/ci.yml          # Ubuntu + Windows CI
├── scripts/
│   ├── full_scan.ps1                 # One-shot read-only scan
│   ├── templates/                    # 22 templates (tNN-*.ps1)
│   ├── lib/Wco.Common.psm1           # Recycle-bin checks, change log, undo
│   └── selftest.py                   # Automated regression test runner
├── data/volatile-paths.json          # Fast-changing app paths with review dates
├── evals/                            # Trigger and behavior evals
├── tests/                            # Pester unit tests
└── references/                       # 14 reference manuals
```

---

## ❓ FAQ

- **Q: Can cleaning delete my files by mistake?**
  A: Deletes go to the Recycle Bin. The three cases where that would become permanent (no bin on the volume, bin set to delete immediately, item over the bin's limit) are refused. Still, take a look before emptying the bin.
- **Q: Why won't it disable Defender or Windows Update?**
  A: The gain is near zero and the risk is large. Developers get speed from Dev Drive, where Defender switches to performance mode automatically.
- **Q: How are WeChat 4.x and QQ NT data moved safely?**
  A: With each app's own storage-location setting, never with mklink. After the move, check that drive C stops growing.
- **Q: What if a change goes wrong?**
  A: Every run generates `undo.ps1`. It restores services to their original start type and restores the registry from the backup exported before the change.
- **Q: Windows 10?**
  A: Supported. But Windows 10 reached end of regular support on 2025-10-14, which is one more reason not to turn off updates or security software.

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). If this skill helped you, please give it a [Star ⭐](https://github.com/hyt315/windows-cleanup-optimize/stargazers)!

---

## 📄 License

Licensed under the [MIT License](LICENSE).

---

> 🌏 **中文版: [README.md](./README.md)**
