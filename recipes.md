# LibreAutomate recipes — professional Windows computer use

All recipes verified hands-on on v1.16.1 / Windows 11 unless marked *(docs)*. Script shape: top-level
C# statements, wrap in try/catch, output via `script.writeResult`. Run with `scripts/la-run.ps1`.

## 1. Observe the computer

```csharp
// Screenshot: whole screen (only when input desktop active; black when RDP disconnected)
CaptureScreen.Image(screen.primary.Rect).Save(path, System.Drawing.Imaging.ImageFormat.Png);
// Screenshot: ONE WINDOW — works even when RDP disconnected / desktop inactive
CaptureScreen.Image(w).Save(path, System.Drawing.Imaging.ImageFormat.Png);
// ...BUT window-DC capture is BLANK for GPU-rendered apps (WPF/WinUI/Electron/browsers).
// Then capture the screen region instead — valid only if w is foreground and unoccluded:
if (w.IsActive) CaptureScreen.Image(w.Rect).Save(path, System.Drawing.Imaging.ImageFormat.Png);
// If it's minimized: w.ShowNotMinimized(); 1.s(); first (minimized rect is {-32000,-32000}).
// If you can't bring it forward (user is working): observe via element reads — no visibility needed.
var color = CaptureScreen.Pixel(new POINT(x, y));   // 0xRRGGBB int

// Enumerate windows (read-only, always works)
foreach (var v in wnd.getwnd.allWindows(true))      // true = only visible
	print.it(v.Name, v.ClassName, v.ProgramName, v.ProcessId, v.Rect, v.IsMinimized);
var edges = wnd.findAll("*Edge*", of: "msedge.exe"); // all matching, filter by exe

// Read text from a window without keyboard/clipboard
var e = w.Elm["TEXT"].Find(-3);       // or DOCUMENT, STATICTEXT... role varies by app
string text = e?.Value ?? e?.Name;
// Dump the whole element tree (to learn an unknown app's UI)
foreach (var el in w.Elm.FindAll()) print.it(el.Role, el.Name, el.Rect, el.State);

// OCR (needs active desktop for screen; window OCR needs visible rendering)
var o = ocr.recognize(w);                            // o.Text, o.Words[i].Text/.Rect
var hit = ocr.find(-2, w, "Submit"); hit?.MouseClick();
// Find image/icon on screen: uiimage.find(3, w, "image:BASE64PNG") or pass a Bitmap
```

## 2. Act on applications

```csharp
// Launch / open anything
run.it(folders.System + @"notepad.exe");             // program
run.it(@"C:\report.xlsx");                           // document (default app)
run.it("https://example.com");                       // URL (default browser)
run.it("notepad.exe", flags: RFlags.Admin);          // run elevated (docs; UAC prompt)
var w = wnd.findOrRun("*Notepad", run: () => run.it(folders.System + @"notepad.exe")); // activate-or-launch

// Type into a window (requires ACTIVE INPUT DESKTOP — user present, not locked/disconnected)
w.Activate(); 300.ms();
keys.send("Ctrl+A");                    // hotkeys: "Ctrl+Shift+Esc", "Alt+F4", "Win+R", "F5", "Tab*3"
keys.send("Alt+_f_s");                  // _x = Alt-select by char, layout-independent
keys.sendt("literal text\r\n");         // types text; for big text prefer clipboard.paste
clipboard.paste("big text");            // Ctrl+V with temp clipboard (auto-restores by default)
string sel = clipboard.copy();          // Ctrl+C and return selection

// Click/fill UI elements — PREFERRED: precise, and Invoke/Check/ComboSelect work even
// without active input desktop (verified: full form filled headless over disconnected RDP)
w.Elm["BUTTON", "OK"].Find(3).Invoke();              // click without mouse
w.Elm["CHECKBOX", "Enable*"].Find(3).Check(true);
w.Elm["COMBOBOX"].Find(3).ComboSelect("Banana");
w.Elm["TEXT"].Find(3).SendKeys("Ctrl+A", "!new value");  // needs input desktop (focuses first)
var v = w.Elm["STATICTEXT", "Total*"].Find(3).Name;      // read back / verify
// Roles seen in practice: BUTTON CHECKBOX COMBOBOX TEXT STATICTEXT LIST LISTITEM TREEITEM
//   MENUITEM PAGETAB SPLITBUTTON WINDOW TITLEBAR; browsers prefix "web:"; e.MouseClick() when Invoke fails.
// NOT FOUND? Modern apps (WPF/WinUI/ribbons) often expose UI only via UI Automation — retry with UIA:
var b2 = w.Elm["BUTTON", "Refresh"].Find(-3) ?? w.Elm["BUTTON", "Refresh", flags: EFFlags.UIA].Find(-5);
// Verify a wildcard match is the real control, not ambient UI (labels, toolbars): check e.Parent?.Name, e.Rect.

// In-app modal overlays (progress/confirm dialogs drawn INSIDE the window, not separate HWNDs):
// detect and track them by their elements, then wait for the long operation to end:
bool busy() => w.Elm["STATICTEXT", "Loading*", flags: EFFlags.UIA].Find(-1) != null
            || w.Elm["STATICTEXT", "Evaluating*", flags: EFFlags.UIA].Find(-1) != null;
bool done = wait.until(-240, () => !busy());        // negative = return false on timeout, don't throw
var err = w.Elm["STATICTEXT", "*error*", flags: EFFlags.UIA].Find(-1);  // success = no progress AND no error

// Menus (docs): open menu, popup menus have class #32768
w.Elm["MENUITEM", "Edit"].Find(1).Invoke();
var wMenu = wnd.find(1, "", "#32768", w);
wMenu.Elm["MENUITEM", "Paste*"].Find(1).Invoke();

// Drag & drop (docs): mouse.drag(w, x1, y1, dx, dy); mouse.drag(elm1, elm2, mod: KMod.Ctrl);
// Slow down flaky apps: opt.mouse.ClickSpeed = 100; opt.key.KeySpeed = 50; (per-script ambient options)
```

## 3. Window management

```csharp
var w = wnd.find(3, "*- Notepad", "Notepad");   // throws if not found in 3 s
var w2 = wnd.find(-3, "*Chrome*");              // negative: returns default, test w2.Is0
w.Move(50, 50); w.Resize(500, 320); w.Move(100, 100, 800, 600, workArea: true);
w.ShowMaximized(); w.ShowMinimized(); w.ShowNotMinimized(); w.MoveToScreenCenter();
w.ZorderTopmost(); w.ZorderNoTopmost();         // always-on-top on/off (w.IsTopmost to check)
w.Close();                                       // polite close; wnd.WaitForClosed to be sure
wnd.wait(10, true, "*Report*");                  // wait until window exists (true = and active)
w.WaitForName(10, "Done*");                      // wait until title changes
// Multi-monitor: screen.all, screen.primary.Rect, screen.primary.Info.workArea, screen.ofMouse
```

## 4. Browser automation (verified on Edge; same for Chrome — cn "Chrome_WidgetWin_1")

```csharp
run.it(@"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
	"--no-first-run --new-window https://example.com/");
var w = wnd.wait(20, false, "Example Domain*", "Chrome_WidgetWin_1");
var doc = w.Elm["web:DOCUMENT"].Find(15);        // "web:" auto-enables Chromium accessibility
print.it(doc.Name, doc.Value);                   // page title, page URL
var link = w.Elm["web:LINK", "Learn more"].Find(5);
print.it(link.Html(true));                       // outer HTML of element
link.Invoke();                                   // click headless; or link.WebInvoke() to also wait
wait.until(15, () => w.Elm["web:DOCUMENT"].Find(-1) is { } d && d.Value?.Contains("iana") == true);
w.Close();
// Always use generous Find timeouts with browsers (a11y tree builds lazily).
// Text fields: w.Elm["web:TEXT", prop: "@name=q"].Find(5).SendKeys("!query") (needs input desktop).
// For serious scraping/headless browsing use Playwright/Selenium via NuGet meta: /*/ nuget Microsoft.Playwright; /*/ (docs)
```

## 5. Data, files, system (all verified)

```csharp
// Clipboard, all formats, without fake keypresses (works headless):
string t = clipboard.text; clipboard.text = "x";                       // get/set raw
new clipboardData().AddText("plain").AddHtml("<b>b</b>").SetClipboard(); // multi-format
new clipboardData().AddImage(bitmap).SetClipboard();
var files = clipboardData.getFiles(); var img = clipboardData.getImage();
// ETIQUETTE: save clipboard.text at start, restore at end — it's the user's clipboard.

filesystem.saveText(path, "x"); filesystem.loadText(path);
filesystem.copy(a, b, FIfExists.Delete); filesystem.delete(p, FDFlags.RecycleBin);
filesystem.enumFiles(dir, "*.txt", FEFlags.AllDescendants);
using (var sc = shortcutFile.create(lnk)) { sc.TargetPath = exe; sc.Save(); }
Microsoft.Win32.Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\...", "Name", null);

var j = internet.http.Get(url).Json();  print.it(j["key"]);            // HTTP + JSON
internet.http.Get(url).Download(file);                                 // download
// POST: internet.http.Post(url, internet.jsonContent(new {a=1})).Json() (docs)

var csv = csvTable.parse(text); csv[row, col]; csv.AddRow("a", "b");   // CSV
using var db = new sqlite(file); db.Execute("INSERT...VALUES(?)", v); db.Get(out string s, "SELECT..."); // SQLite

int ec = run.console(out string cout, folders.System + @"cmd.exe", "/c dir");  // console capture
using var cp = new consoleProcess("app.exe", "args"); cp.ReadAllText();        // interactive console
process.allProcesses(); process.exists("excel.exe"); process.terminate(pid);   // processes (docs: terminate)
// Excel files: NuGet ClosedXML / EPPlus / ExcelDataReader via /*/ nuget X; /*/ (docs)
```

## 6. Orchestration & deployment (verified)

```csharp
// Script calls script (child registered in same workspace):
int ec = script.runWait(out string results, "child.cs", "arg1");  // results = child's writeResult text
int pid = script.run("bg-task.cs");                               // fire-and-forget
return 7;                                                          // script exit code → CLI exit code

// Compile to standalone exe (runs without LibreAutomate — deployable):
/*/ role exeProgram; outputPath %folders.Workspace%\bin; /*/       // first line of script
// After first run: <workspace>\bin\name.exe + Au.dll etc. Verified standalone run.

// Background triggers script (hotkeys work only on active input desktop):
using Au.Triggers;                                                 // (using needed)
var Triggers = new ActionTriggers();
Triggers.Hotkey["Ctrl+Shift+F11"] = o => { /* action */ };
Triggers.Autotext["btw"] = o => o.Replace("by the way");           // (docs)
Triggers.Window[TWEvent.ActiveNew, "Popup*"] = o => o.Window.Close(); // auto-close popups (docs)
Triggers.Run();                                                    // blocks; Triggers.Stop() to end
// Make persistent: put in workspace, add to Options > Workspace > Startup scripts (docs).

// Schedule: run any script via Windows Task Scheduler with command line:
//   "C:\Program Files\LibreAutomate\Au.Editor.exe" script.cs   (docs)
```

## 6b. Process mining — track any app's long operation at the OS level (verified on a real refresh)

Apps do heavy work in child/worker processes (installers → msiexec, IDE builds → compilers,
browsers → renderers, BI tools → query engines). Mining the process tree gives observation signals
that need no UI at all.

```csharp
// 1) DISCOVER the workers: snapshot-diff around the action (first/cold run spawns them)
var baseline = process.allProcesses().Select(p => p.Id).ToHashSet();
// ... trigger the operation ...
var spawned = process.allProcesses().Where(p => !baseline.Contains(p.Id)).ToArray(); // + getCommandLine(pid)
// Parent-child attribution (who spawned what): WMI via PowerShell —
// run.console(out var s, "powershell.exe", "-c Get-CimInstance Win32_Process | select ProcessId,ParentProcessId,Name | ConvertTo-Csv");

// 2) LISTEN for completion — choose by worker lifecycle:
process.waitForExit(0, pid);       // ONE-SHOT workers (installers, compilers): exit = done. Perfect signal.
// POOLED workers (kept alive for reuse — e.g. query engines): they DON'T exit, and a warm rerun
// spawns NOTHING. Use CPU quiescence of the WORKER pids only:
double cpu(int[] pids) { double s = 0; foreach (var p in pids) { try { s += Process.GetProcessById(p).TotalProcessorTime.TotalMilliseconds; } catch { } } return s; }
// done when: UI progress overlay gone AND worker-cpu delta ~0 over a few seconds.
```

Measured caveats (from a live 38 s Power BI refresh):
- Worker pools are warm after the first run — spawn-diffing only works cold; don't rely on it for reruns.
- NEVER include the app's UI process in the CPU measurement — UI processes rarely go quiet.
- Observer effect: cross-process element polling (`Elm...Find` in a tight loop) makes the target app
  burn CPU servicing you — poll at 1–2 s intervals, especially while measuring CPU.
- Strongest signal is the AND of both channels: UI overlay gone + workers quiet.

## 7. Unattended / headless playbook (verified over disconnected RDP)

Check first: `miscInfo.isInputDesktop()` — false when workstation locked, RDP disconnected, or UAC prompt up.

| Works headless | Blocked headless |
|---|---|
| wnd find/enum/Move/Resize/Zorder/Min/Close | `wnd.Activate` |
| ALL `elm` reads + `Invoke`/`Check`/`ComboSelect` | `elm.SendKeys`, `elm.Focus` |
| `CaptureScreen.Image(w)` (window) | screen capture (black), screen OCR |
| `clipboard.text` get/set, `clipboardData` | `clipboard.copy()`/`paste()` (send Ctrl+C/V) |
| files/HTTP/SQLite/processes/console, browser elm automation | `keys.send`, all `mouse.*` |

Text input into foreign apps headless: no keys available — use `elm` actions, `w.SetText` (WM_SETTEXT,
classic Edit controls), app CLIs, or file/clipboard handoffs. Or LibreAutomate **PiP session** *(docs)*:
a child session where scripts get their own desktop while the user works — `Au.Editor.exe /pip`,
`script.runInPip`, `miscInfo.isChildSession`. First use asks for Windows credentials; not on Home editions.

## 8. Building GUIs & notifications (verified)

```csharp
osdText.showText("Working...", 3);                                  // on-screen overlay, auto-hides
int r = dialog.show("Title", "Text", "1 OK|2 Cancel", secondsTimeout: 30);  // timeout → result -2147483648
if (!dialog.showInput(out string s, "Enter name")) return;          // input box (docs)
// Full windows: wpfBuilder — rows of controls, ShowDialog(); see cookbook "Dialog - add elements"
var b = new wpfBuilder("My tool").WinSize(400);
b.R.Add("Name", out TextBox t1); b.R.AddOkCancel(); b.End();
if (b.ShowDialog()) print.it(t1.Text);
// trayIcon, toolbar, popupMenu classes for persistent UI (docs)
```

## Learning more — offline docs (3148 articles with examples)

```powershell
pwsh -File scripts/la-doc.ps1 -Query "elm.Invoke" -Full          # exact API doc
pwsh -File scripts/la-doc.ps1 -Query "cookbook] Excel"           # find how-to guides
```
Or grep `C:\Program Files\LibreAutomate\toc-ai.yml` for member names.
Cookbook covers: Excel, email (SMTP/IMAP), SFTP/SSH, WMI, services, COM, Playwright/Selenium,
autotext, remap keys, toolbars, encryption, compression, HTML parsing, scheduled/startup scripts, PiP.
