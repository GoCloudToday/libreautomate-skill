# libreautomate-skill

A [Claude Code](https://claude.com/claude-code) skill for **professional Windows computer use** via
[LibreAutomate](https://www.libreautomate.com/) (C# desktop automation): control windows, drive UI
elements, send keyboard/mouse input, take and analyze screenshots, OCR, automate browsers, and
orchestrate multi-app workflows — all headless from the terminal, no visible editor needed.

Everything in here was verified hands-on (LibreAutomate v1.16.1, Windows 11), including the
observe–act loop, the headless CLI runner contract, and a growing learnings log of real traps
and their fixes.

## Install

Clone into your Claude Code skills directory:

```powershell
git clone https://github.com/GoCloudToday/libreautomate-skill.git "$env:USERPROFILE\.claude\skills\libreautomate"
```

Claude Code picks it up as the `libreautomate` skill. The skill can install LibreAutomate itself
(`scripts/install.ps1`) if it's not present.

## Contents

| File | Purpose |
|---|---|
| `SKILL.md` | The skill entry point: run contract, observe–act loop, environment matrix, safety rules |
| `recipes.md` | Copy-paste patterns per capability area (observe, act, windows, browser, data, orchestration, headless, GUIs) |
| `reference.md` | CLI contract, API cheat sheet, gotchas, verified capability inventory, **learnings log** |
| `scripts/install.ps1` | Silent install of LibreAutomate + workspace init |
| `scripts/la-run.ps1` | Write, register, and run a C# automation script; relays output + exit code |
| `scripts/la-doc.ps1` | Query LibreAutomate's offline 3148-article documentation database |

## Versioning

Tags follow the skill's self-iteration protocol: minor bumps for new learnings or rule changes,
patches for fixes. Every learning entry cites measured evidence — no speculation.
