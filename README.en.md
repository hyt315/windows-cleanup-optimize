# 🐧 Windows Cleanup & Optimization Agent Skill

> 🌏 **中文版: [README.md](./README.md)**

<div align="center">

**Zero-harm Windows cleanup & optimization Agent Skill: disk, services, bloatware, mklink migration, shell audit**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.1.0-green.svg)](CHANGELOG.md)
[![Agent Skill](https://img.shields.io/badge/Agent%20Skill-SKILL.md-green)](SKILL.md)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue)](SKILL.md)
[![GitHub Stars](https://img.shields.io/github/stars/hyt315/windows-cleanup-optimize?style=social)](https://github.com/hyt315/windows-cleanup-optimize/stargazers)

</div>

---

## 📖 What is this?

A Windows cleanup & optimization **Agent Skill** for AI assistants (Claude Code / Codex / Cursor). Built around a **zero-harm guarantee**: every cleanup goes through the Recycle Bin (reversible), every optimization is risk-tiered (LOW/MEDIUM/HIGH/CRITICAL) with a full rollback command. Targets the most common China-market Windows issues: full C:\ drive, WPS auto-update loops, slow boot, bloatware residue (360/2345/DingTalk…), and bloaty AI-client caches.

It does **not** push "PC optimizer" tools — it uses official commands plus reversible scripts to genuinely fix a slow, full, or bloated PC.

## ✨ Core Features

| Feature | Description |
|---------|-------------|
| 🧹 **Disk Cleanup** | Temp, electron-updater residue, npm/uv caches, AppData leftovers — all via Recycle Bin |
| ⚡ **Services/Tasks** | 50+ Windows services risk-tiered (telemetry/Xbox/3rd-party updaters), admin-elevation flow |
| 🔧 **Residue Detection** | WPS/QQ/2345/DingTalk/360 uninstall leftovers; **multi-path detection** handles non-standard install paths |
| 📁 **mklink Migration** | Move big C:\ dirs (Trae/VS Code) to D:\ via `mklink /J`, logical path unchanged |
| 🐕 **WPS Update Killer** | Config(UpdateMode)+task+service 3-layer defense against `ksolaunch` re-registering tasks |
| 🔍 **Shell Audit** | Right-click menu tamper detection + bloatware whitelist matching (new 2026-08) |

## 🚀 Quick Start

1. Install the skill into your agent's skills directory (table below)
2. Say: **"My C: drive is full, clean it up"** or **"WPS keeps self-updating, how do I stop it"**
3. The skill will: read-only diagnose → risk-tier into 4 levels → confirm with you → execute step by step → verify & give rollback commands

## 📥 Installation

| Platform | Command |
|----------|---------|
| **Claude Code** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.claude/skills/windows-cleanup-optimize` |
| **Codex** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.codex/skills/windows-cleanup-optimize` |
| **Cursor** | `git clone https://github.com/hyt315/windows-cleanup-optimize.git ~/.cursor/skills/windows-cleanup-optimize` |

**Download**

| Method | Command / Link |
|--------|----------------|
| HTTPS | `git clone https://github.com/hyt315/windows-cleanup-optimize.git` |
| SSH | `git clone git@github.com:hyt315/windows-cleanup-optimize.git` |
| GitHub CLI | `gh repo clone hyt315/windows-cleanup-optimize` |
| ZIP | https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.zip |
| Tarball | https://github.com/hyt315/windows-cleanup-optimize/archive/refs/heads/main.tar.gz |
| Releases | https://github.com/hyt315/windows-cleanup-optimize/releases |

## 📁 File Structure

```
windows-cleanup-optimize/
├── SKILL.md                     # Entry: 6-phase workflow + zero-harm + 4-tier risk
├── references/                  # 12 topic docs
│   ├── scan-scripts.md          # 16 PowerShell templates (incl. shell-audit template 16)
│   ├── pitfalls.md              # 66 lessons-learned
│   ├── bloatware-catalog.md     # bloatware list + multi-path detection method
│   ├── software-uninstall.md    # uninstall & residue flows (WPS/DingTalk/360)
│   ├── services-optimization.md # Windows service tiering
│   ├── mklink-migration.md      # symlink migration guide
│   └── ...                      # 6 more topics
├── scripts/selftest.py          # Self-test (zero deps)
└── .github/                     # Issue/PR templates
```

## 🛡️ Core Philosophy

- All cleanup via Recycle Bin (reversible) — never `Remove-Item`
- Never touch system dirs (`C:\Windows`, `C:\Program Files`, `C:\ProgramData`) by default
- Restore points before critical ops (`Checkpoint-Computer`)
- Every optimization is risk-tiered with a full rollback command
- When unsure, ask the user — never batch-execute silently

## 📚 Examples

> "My WPS keeps auto-updating and pops up ads — how do I turn it off completely?"

The skill follows the WPS section of `software-uninstall.md`:
1. **Config layer (root fix)**: registry `HKCU\Software\Kingsoft\Office\6.0\Common\updateinfo\UpdateMode` `auto` → `manual`
2. **Task layer**: disable `WpsUpdateTask_*` / `WpsUpdateLogonTask_*` / `WpsWakeWnsLogonTask`
3. **Service layer**: disable `wpscloudsvr`
4. Verify the 3 tasks stay `Disabled`, hand back a rollback `.reg`

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). When adding: append pitfall #+1 in `pitfalls.md`, template #+1 in `scan-scripts.md`, and run `python scripts/selftest.py`.

## 📄 License

[MIT](LICENSE) © 2026 MiniMax
