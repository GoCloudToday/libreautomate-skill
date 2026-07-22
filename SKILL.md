---
name: libreautomate
description: Programmatic Windows computer use via LibreAutomate (C# automation). Use when asked to automate the desktop UI — control windows, send keyboard/mouse input, click/read UI elements, drive web browsers, take screenshots, OCR the screen, run apps that have no API/CLI, or orchestrate multi-app workflows — and to install LibreAutomate itself. Works headless from the terminal; no visible editor needed.
---

# LibreAutomate — professional Windows computer use

Drive real desktop UI from Claude Code by writing a small C# automation script and running it via the
`Au.Editor.exe` CLI. Full observe–act loop: **act** with window/keyboard/mouse/UI-element/browser calls,
**observe** with screenshots (Read the PNG), UI-element text reads, and OCR.

Everything here was verified hands-on on v1.16.1 / Windows 11. Deep material:
- [recipes.md](recipes.md) — copy-paste patterns for every capability area (observe, act, windows, browser, data, orchestration, headless, GUIs).
- [reference.md](reference.md) — CLI contract, exact paths, API cheat sheet, gotchas, verified capability inventory.

## 1. Ensure installed

Check `C:\Program Files\LibreAutomate\Au.Editor.exe`. If missing:

```powershell
pwsh -File "<skill dir>\scripts\install.ps1"
```

Silent install of the latest release (one UAC prompt unless already elevated; also pulls .NET 10 runtime
if absent), then initializes the workspace at `<MyDocuments>\LibreAutomate\Main`.

## 2. Run automation

```powershell
pwsh -File "<skill dir>\scripts\la-run.ps1" -Name my-task -File task.cs -Arguments "a","b" -TimeoutSec 60
# or inline:  -Code 'script.writeResult("hi");'   |  re-run existing:  just -Name my-task
```

`la-run.ps1` writes the code into the workspace, registers it in `files.xml`, reloads the editor, runs it,
and prints the script's `script.writeResult()` text plus `EXITCODE: n`
(0 OK · -1 compile error · -2 not registered · -532462766 runtime exception · -999 timeout).

**Always use this script shape** — only `script.writeResult` reaches stdout; errors are otherwise invisible:

```csharp
try {
	// ... automation ...
	script.writeResult("OK: ...");
} catch (Exception ex) {
	script.writeResult("ERROR: " + ex);
}
```

## 3. The core loop

**Observe** — three channels, in order of preference:
```csharp
// 1. Screenshots (then Read the PNG):
CaptureScreen.Image(w).Save(args[0], System.Drawing.Imaging.ImageFormat.Png);
// blank image? GPU-rendered app → capture screen region CaptureScreen.Image(w.Rect) with w foreground;
// can't bring it forward? use channel 2 — elements need no visibility at all:
// 2. UI elements:
foreach (var e in w.Elm.FindAll()) print.it(e.Role, e.Name, e.Rect);            // learn an app's UI
string val = w.Elm["TEXT"].Find(3).Value;                                       // read a field
// 3. Process signals (no UI needed): worker spawns/exits, CPU quiescence — recipes.md §6b.
```
**Act** (prefer UI elements — precise, and they work even when the machine is locked):
```csharp
var w = wnd.find(3, "*Notepad", "Notepad", of: "notepad.exe");  // ALWAYS scope with of: — a name
// wildcard alone can match a lookalike (an IDE tab titled after your target got clicked once)
var b = w.Elm["BUTTON", "Save"].Find(-3)
     ?? w.Elm["BUTTON", "Save", flags: EFFlags.UIA].Find(5);  // modern apps often need UIA
b.Invoke();                                      // click without mouse
w.Activate(); 300.ms(); keys.send("Ctrl+S");     // keyboard needs active desktop + activate first
```

## 4. Know the environment first

Before keyboard/mouse/activation, check `miscInfo.isInputDesktop()`. When it's false (machine locked,
RDP disconnected, UAC prompt showing), `keys.*`/`mouse.*`/`Activate`/`clipboard.copy|paste` throw —
but window management, all `elm` reads and `Invoke`/`Check`/`ComboSelect`, window screenshots, raw
clipboard, and browser element automation still work. Full matrix + the PiP-session workaround: recipes.md §7.

## 5. Discover any API on demand (offline, no network)

```powershell
pwsh -File "<skill dir>\scripts\la-doc.ps1" -Query "elm.Invoke" -Full     # exact API doc + examples
pwsh -File "<skill dir>\scripts\la-doc.ps1" -Query "cookbook] Excel"      # find how-to guides
```
Reads the 3148-doc `doc-ai.db` shipped with LibreAutomate. Covers far more than tested here: Excel,
email, SFTP/SSH, WMI, COM, Playwright/Selenium, triggers, remap keys, toolbars, scheduled scripts.

## Safety rules (learned from a real incident)

- Scripts type into and click REAL user apps. Apps may restore prior sessions with unsaved user data
  (Win11 Notepad does). **Never send destructive input (`Ctrl+A`+overwrite/Del, closing) to a window you
  didn't open, and verify a freshly opened app is empty before typing** (e.g. read `Elm["TEXT"].Value` first).
- Prefer non-destructive observation (element `.Value`, window screenshots) over select-all+copy.
- `clipboard.copy()/paste()` and `clipboardData` overwrite the user's clipboard — save `clipboard.text`
  first and restore it, or say so.
- Keyboard/mouse/focus are shared with the live user. Warn before long interactive sequences, keep them
  short, and restore foreground state when done. For true background work, use element actions (no focus
  needed) or a PiP session.
- Create your own windows/browser instances for testing where possible, and close what you open.

## Self-iteration protocol (this skill must grow)

After ANY session using this skill where something surprised you — a new trap, a wrong or
incomplete rule, a better procedure:

1. Append a dated entry to the **Learnings log** in [reference.md](reference.md): what
   happened, the evidence (verbatim errors / measured behavior), and the rule derived.
2. If it changes a rule in this file or a recipe, edit that in place — corrections beat
   additions; keep SKILL.md tight, depth goes to reference.md/recipes.md.
3. Never record a rule without evidence; "I think" entries are forbidden.
4. **This skill is PUBLIC — sanitize at write time**: no client/person names, no tenant
   URLs, no business data. Keep what teaches: error strings verbatim, timings, public
   product names, generic role descriptions ("a report window", "an IDE tab").
5. Pull the repo before invoking the skill; after edits, commit, push, and tag
   (`vX.Y+1.0` for new learnings/rule changes, patch for fixes). An unpushed learning
   batch is unfinished work.
