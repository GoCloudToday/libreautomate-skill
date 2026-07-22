# Offline LibreAutomate documentation lookup (API members + cookbook how-tos).
# Queries the doc-ai.db SQLite shipped with LibreAutomate (3148 docs with code examples).
# Usage:
#   pwsh -File la-doc.ps1 -Query "keys.send"            # summaries of matching docs
#   pwsh -File la-doc.ps1 -Query "cookbook] Take screen" -Full   # full article text
#   pwsh -File la-doc.ps1 -Query "elm.Invoke" -Full
param(
    [Parameter(Mandatory)][string]$Query,
    [int]$Limit = 5,
    [switch]$Full
)
$code = @'
try {
	using var db = new sqlite(@"C:\Program Files\LibreAutomate\doc-ai.db", SLFlags.SQLITE_OPEN_READONLY);
	string q = "%" + args[0] + "%"; int limit = args[1].ToInt(); bool full = args[2] == "1";
	var sb = new StringBuilder();
	using var st = db.Statement("SELECT name, summary, text FROM doc WHERE name LIKE ? ORDER BY length(name) LIMIT ?")
		.Bind(1, q).Bind(2, limit);
	while (st.Step()) {
		sb.AppendLine("### " + st.GetText(0));
		string summary = st.GetText(1), text = st.GetText(2);
		sb.AppendLine(full ? text : (!summary.NE() ? summary : text.Limit(500)));
		sb.AppendLine();
	}
	script.writeResult(sb.Length > 0 ? sb.ToString() : "No matches for: " + args[0]);
} catch (Exception ex) { script.writeResult("ERROR: " + ex.Message); }
'@
& (Join-Path $PSScriptRoot 'la-run.ps1') -Name la-doc-helper -Code $code -Arguments $Query, "$Limit", $(if ($Full) { '1' } else { '0' }) -TimeoutSec 30
