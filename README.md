# Microsoft Forms Response and Sharing Troubleshooter

Created by **Dewald Pretorius**.

The repository includes the original Microsoft Forms diagnostics and a guarded `Repair.ps1` helper.

Supported repair actions:

- `Diagnose` — records current Edge and cache state without changes.
- `ResetBrowserCache` — with Edge closed, preserves the browser cache in a timestamped backup and creates a clean cache folder.

```powershell
.\Repair.ps1 -Action Diagnose
.\Repair.ps1 -Action ResetBrowserCache -WhatIf
.\Repair.ps1 -Action ResetBrowserCache -Confirm
```

The helper saves pre-change evidence and a timestamped log. It does not alter form ownership, responses, permissions, branching, or tenant settings. Source-reviewed for Windows PowerShell 5.1; not runtime-tested against every Forms environment.
