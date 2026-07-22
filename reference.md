# LibreAutomate reference (verified on v1.16.1, Windows 11)

LibreAutomate (https://www.libreautomate.com, github.com/qgindi/LibreAutomate) is a C# script
editor + automation library ("Au") for Windows. Scripts are plain C# (top-level statements)
compiled and run by the editor in separate `Au.Task.exe` processes.

## Paths

| What | Where |
|---|---|
| Editor exe | `C:\Program Files\LibreAutomate\Au.Editor.exe` |
| Workspace | `<MyDocuments>\LibreAutomate\Main` (path also in `<MyDocuments>\LibreAutomate\.settings\Settings.json`, key `workspace`) |
| Script files | `<workspace>\files\*.cs` |
| File index | `<workspace>\files.xml` |
| AI-oriented API index | `C:\Program Files\LibreAutomate\toc-ai.yml` — grep it to discover exact member names |
| Offline full docs DB | `C:\Program Files\LibreAutomate\doc-ai.db` — SQLite, table `doc(name, summary, text)`: 3148 markdown docs with code examples for every API member + ~160 cookbook how-tos + editor docs. Query via `scripts/la-doc.ps1`. |

## CLI (all verified)

```
Au.Editor.exe *name.cs arg1 arg2   # run script, WAIT, relay script.writeResult() to stdout, relay exit code
Au.Editor.exe name.cs arg1         # run without waiting (exit code = process id)
Au.Editor.exe /reload              # re-read workspace after files.xml edited externally
Au.Editor.exe /a                   # start editor hidden (tray only) — e.g. first run
```

- The editor auto-starts if not running when you run a script (cold start ~10 s).
- Exit codes: `0` OK · `-1` compile error · `-2` script not found in workspace · `-532462766` (0xE0434352) unhandled exception · script's own value via `return n;` or `Environment.Exit(n)`.
- **Only `script.writeResult("text")` reaches stdout.** `print.it(...)` goes to the editor's output pane only. Compile/runtime error messages also only appear in the editor pane — so ALWAYS wrap script bodies in try/catch and `script.writeResult("ERROR: " + ex)`.
- Script args: `args` (string[]) in top-level-statement scripts.

## Registering scripts (required)

A `.cs` file dropped into `<workspace>\files\` is NOT picked up automatically. It must have an
entry in `files.xml`: `<s n="name.cs" i="UNIQUE_INT" />` appended inside `<files>`, then run
`Au.Editor.exe /reload`. (Use max existing `i` + 1. The editor rewrites this file itself —
it auto-REMOVES entries when files are deleted, but never auto-ADDS.)
Editing the *content* of an already-registered script needs no reload — next run recompiles.

`scripts/la-run.ps1` does all of this (write file → register → reload → run → relay output).

## Core API cheat sheet (verified working)

```csharp
// Windows
var w = wnd.find(3, "*Notepad", "Notepad");   // wait ≤3s, throws NotFoundException if not found
var w2 = wnd.find(-3, "*Chrome");             // negative timeout: returns default(wnd) instead of throwing... check w2.Is0
wnd a = wnd.active;                            // foreground window; a.Name, a.ClassName, a.Rect
w.Activate(); w.Close(); w.Maximize_?
wnd ww = wnd.wait(10, true, "*Notepad");      // wait until window exists (true = must be active)

// Keyboard (to ACTIVE window; Activate() first!)
keys.send("Ctrl+A");                          // modifiers with +, names: Enter Tab Esc Del F5 Win+R, repeat: "Tab*3"
keys.send("Ctrl+A Del");                      // sequence in one string
keys.sendt("literal text");                   // types text (use for arbitrary strings)

// Mouse
mouse.click(x, y);                            // screen coords
mouse.click(w, x, y);                         // window-relative
mouse.rightClick(...); mouse.doubleClick(...); mouse.move(...); mouse.wheel(n);

// UI elements (UI Automation) — prefer over mouse/keyboard: precise + can read text invisibly
var e = w.Elm["BUTTON", "OK"].Find(3);        // role + name; throws if not found in 3s
var e2 = w.Elm["TEXT"].Find(-3);              // -3 → returns null if not found (no throw)
e.Invoke();                                   // default action (click) without moving mouse
e.MouseClick();                               // real mouse click on it
string s = e.Value;  string n = e.Name;       // read text; Notepad's editor: role "TEXT", .Value
// web pages in browsers: w.Elm["web:LINK", "Sign in"].Find(5).WebInvoke();

// Clipboard (destroys user clipboard content — see Safety)
string sel = clipboard.copy();                // sends Ctrl+C, returns copied text (throws if nothing copied)
clipboard.paste("text");                      // pastes text via Ctrl+V
clipboard.text = "x"; var t = clipboard.text; // raw get/set

// Programs & files
run.it(folders.System + @"notepad.exe");      // also URLs, documents; folders.Desktop, folders.Temp, ...
run.console(out var output, "cmd.exe", "/c ver"); // run console app, capture output

// Screenshot (CRITICAL for observe-act loops; Au.More is globally imported)
var img = CaptureScreen.Image(screen.primary.Rect);          // whole screen; note capital .Rect
var img2 = CaptureScreen.Image(w, null, CIFlags.WindowDC);   // one window
img.Save(path, System.Drawing.Imaging.ImageFormat.Png);

// Waiting / timing
300.ms();                                     // sleep 300 ms (int extension)
wait.until(10, () => condition);
w.WaitFor(0, e => e.IsEnabled);               // wait for element state

// OCR / find image on screen (when no UI element exists)
var word = ocr.find(3, w, "Submit"); word.MouseClick();
var im = uiimage.find(3, w, "image:BASE64PNG"); im.MouseClick();

// Output back to caller
script.writeResult("RESULT...");              // the ONLY stdout channel; call as often as needed
```

Gotchas found the hard way:
- `screen.primary.Rect` (capital R) — `rect` doesn't compile.
- Win11 Notepad document element role is `"TEXT"`, not `"DOCUMENT"`.
- `clipboard.copy()` throws if the focused app copied nothing — wrap in try/catch.
- RECT fields: `left top right bottom` lowercase; `Width Height` properties.
- Global usings (Au, Au.Types, Au.More, System, System.IO, Linq, Text, RegularExpressions, …)
  come from `<workspace>\files\Classes\global.cs` — no using directives needed in scripts.
  Exceptions that DO need usings: `using Au.Triggers;` (ActionTriggers), `using System.Windows.Controls;` (wpfBuilder controls).
- Method vs property traps: `process.allProcesses()` (method), `csvTable[row, col]` (2-arg indexer),
  `sqlite.Get(out var v, sql, binds)` (no generic Execute<T>), `osVersion.onaString` (no `.current`).
- Set topmost via `w.ZorderTopmost()` — `IsTopmost` is read-only.
- To wait without throwing: negative timeout (`Find(-3)`, `wnd.find(-3, ...)`) returns null/default instead.
- Before ANY `keys`/`mouse`/`Activate`/`clipboard.copy|paste`: check `miscInfo.isInputDesktop()`.
  False when machine locked / RDP disconnected / UAC prompt visible → those calls throw
  `InputDesktopException`. Everything element-based still works (see recipes.md §7 matrix).
- `wnd.getwnd.allWindows(true)` enumerates; `wnd.findAll(name, of: "exe.exe")` filters by program.
- **Element not found? Retry with `flags: EFFlags.UIA`.** Many modern apps (WPF, WinUI, DirectX,
  Office-style ribbons) expose their UI only through UI Automation, not the legacy accessibility API.
  Pattern: `w.Elm["BUTTON", "Name"].Find(-3) ?? w.Elm["BUTTON", "Name", flags: EFFlags.UIA].Find(-5)`.
- **Screenshot decision chain (any app):** `CaptureScreen.Image(w)` (window DC) returns BLANK for
  GPU/DirectComposition-rendered apps (WPF, WinUI, Electron, browsers). Fallback: capture the screen
  region `CaptureScreen.Image(w.Rect)` — but that grabs whatever is TOPMOST there, so it's only valid
  when the window is foreground and unoccluded (check `w.IsActive`). If you can't bring it forward
  (user is working), observe via element reads instead — they need no visibility at all.
- **Minimized windows** report rect `{L=-32000 T=-32000}`; `ShowNotMinimized()` first, then give the
  app ~1 s to repaint before capturing — freshly restored windows render blank/stale.
- **Modal dialogs/overlays in modern apps are often in-window ELEMENTS, not top-level windows** —
  `wnd.find` for an owned popup won't see them; find their parts (`STATICTEXT`/`BUTTON`) inside the
  main window instead.
- **Wildcard element searches match ambient UI too** (a ribbon button's own label, a toolbar's Cancel).
  Before acting on a match, verify context: `e.Parent?.Name/.Role`, `e.Rect` plausibility.
- **Long-operation pattern:** start it, then `wait.until(-ceiling, () => progressElementsGone())`
  polling for the overlay's texts (`"Loading*"`, `"Evaluating*"`, progress bars) to disappear; conclude
  success only on absence of progress AND absence of error texts. For a UI-independent second signal,
  mine the app's worker processes (recipes.md §6b): one-shot workers → `process.waitForExit`; pooled
  workers → CPU-quiescence of worker PIDs only. Poll elements at 1–2 s intervals — tight cross-process
  UIA polling makes the target app burn CPU servicing you (observer effect).
- The editor auto-REMOVES `files.xml` entries when script files are deleted from disk (file watcher),
  but never auto-ADDS new files — registration is always manual (la-run.ps1 does it).
- A script can `return n;` — becomes the CLI exit code (verified with 7).

## Script meta-comments (optional first line)

`/*/ role exeProgram; outputPath %folders.Workspace%\bin; /*/` — compile to standalone exe.
`/*/ nuget PackageName; /*/` — use a NuGet package. `/*/ ifRunning run; /*/` — allow parallel runs.
Default role miniProgram (runs in Au.Task.exe) is right for computer use.

## Discovering more API

1. **Offline docs (best):** `pwsh -File scripts/la-doc.ps1 -Query "keys.send" -Full` — reads the shipped
   `doc-ai.db` (3148 docs with code). Query API members (`elm.Invoke`) or cookbook (`cookbook] Excel`).
2. `Grep 'keyword' "C:\Program Files\LibreAutomate\toc-ai.yml"` — compact member index for every class.
3. Online: `https://www.libreautomate.com/api/Au.<class>.html`, cookbook at `https://www.libreautomate.com/cookbook/`.
4. To learn an unknown app's UI, dump its element tree in a script:
   `foreach (var e in w.Elm.FindAll()) print.it(e.Role, e.Name, e.Rect);` then `script.writeResult`
   the collected lines. (The editor's interactive Ctrl+Shift+E capture tool is not usable headless.)

## Verified capability inventory (v1.16.1, hands-on)

Windows: enumerate/find/wildcards, move/resize/min/max/topmost/close, wait-for/wait-name, multi-monitor.
Input: keys.send (hotkeys + Alt-select + text), keys.sendt, mouse click/move/drag/wheel, clipboard paste/copy.
UI elements: find by role+name+prop, child/descendant, Invoke/MouseClick/Check/ComboSelect/Expand/Focus/SendKeys,
  read Name/Value/Rect/State/HTML, WaitFor(state), FindAll tree dump; browser "web:" roles.
Vision: CaptureScreen.Image (screen/window), Pixel/Pixels, OCR (recognize/find words), uiimage find image/color.
Data: filesystem (save/load/copy/delete-to-recyclebin/enum), shortcutFile, registry, internet.http (GET/POST/
  download/JSON), csvTable, sqlite, run.console + consoleProcess capture, process list/exists/terminate.
Orchestration: script.run/runWait (parent↔child via writeResult), return exit code, exeProgram compile to
  standalone .exe, ActionTriggers (hotkey/autotext/window), timer, run.thread, startup/scheduled scripts.
UI output: osdText overlay, dialog.show/showInput (+timeout), wpfBuilder windows, trayIcon, popupMenu, toolbar.
Docs referenced but not run here: email (SMTP/IMAP), SFTP/SSH, WMI, services, COM, Playwright/Selenium,
  Excel (ClosedXML/EPPlus), PiP child session, remap keys. All have cookbook entries in doc-ai.db.

## Troubleshooting

- Exit `-1`, empty output → compile error. Simplify the script, bisect the failing line; error text is only in the editor GUI pane.
- Exit `-2` → not registered in files.xml, or name typo (use exact `name.cs` with `*` prefix).
- Exit `-532462766` → runtime exception; wrap body in try/catch + writeResult.
- Hangs → script waits for a window/element that never appears; la-run.ps1 kills it after -TimeoutSec.
- Keyboard input lands in wrong window → always `w.Activate(); 300.ms();` before `keys.*`.
- Wrong window found / clicks land elsewhere → `wnd.find` name-only match hit a lookalike (IDE tab titled like the target). Scope with `of: "process.exe"` + class.
- GDI+ "generic error" on `image.Save` after a sub-RECT capture → capture the full window, crop with `Bitmap.Clone(Rectangle, Format24bppRgb)`, upscale crops ×3 before reading small text. See Learnings log.

## Learnings log

### 2026-07-22 (driving Power BI Desktop headlessly for a report-editing loop, ~10 open/verify/close cycles)

- **`wnd.find` by name wildcard alone grabbed the WRONG window**: an IDE window whose
  session tab was titled after the same project matched `"*<project name>*"` first, and
  two clicks landed in the IDE (harmless, but only by luck). Always scope finds with
  `of: "process.exe"` and the class name when known:
  `wnd.find(120, "*Title*", "WindowsForms10*", of: "PBIDesktop.exe")`.
- **Crop screenshots via `Bitmap.Clone`, not `CaptureScreen.Image(RECT)`**: capturing
  arbitrary sub-RECTs produced GDI+ "generic error" on `Save` (RECT ctor semantics
  ambiguity → invalid image). Reliable pipeline: capture the full window, then
  `bmp.Clone(new Rectangle(x,y,w,h), PixelFormat.Format24bppRgb)` and UPSCALE with
  `new Bitmap(crop, new Size(w*3, h*3))` before reading — sub-6px text is unreadable
  at native resolution in downstream image analysis.
- **Late-painting canvases (report/BI apps) need a content probe, not a fixed sleep**:
  poll a sparse pixel grid over the canvas region until enough non-white pixels appear
  (`GetPixel` every 10px, threshold ~40 dark hits), then add a settle delay, then
  capture. A fixed 15s wait missed; the probe loop never did across ~8 app restarts.
- **Save-prompt-safe close of an app that may hold unsaved user work**:
  `p.CloseMainWindow()` → if the process survives ~8s, the prompt for WinForms apps is
  NOT a `#32770` dialog — find it by class prefix (here
  `WindowsForms10.Window.20008*`) in the same process, enumerate `Elm.FindAll()` for
  BUTTONs ("Save" / "Don't save" / "Cancel"), and `.Invoke()` the right one — works
  without keyboard focus. Decide save-vs-discard from who owns the truth (disk vs
  session) before clicking.
- **Embedded WebView content is a black box to both channels**: `Elm[flags:
  EFFlags.UIA].FindAll()` from the top window returned 13 elements for a WebView2-heavy
  app (tree stops at the web canvas), and synthetic `mouse.click` on a JS custom
  visual's cells never registered a selection in the host's edit mode. Don't fight it:
  drive the state through the app's files/config instead, and observe via screenshots.
