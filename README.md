# Microsoft Forms Response and Sharing Troubleshooter

Created by **Dewald Pretorius**.

A PowerShell 5.1 toolkit for diagnosing and repairing common local client problems that affect Microsoft Forms access, response pages and sharing links in Microsoft Edge.

## Files

- `Troubleshooter.ps1` — collects Forms, browser and endpoint evidence.
- `Repair.ps1` — performs guarded local browser and connectivity repairs.
- `Launch_Forms_Repair.bat` — interactive repair menu for technicians.

## Repair actions

### `Diagnose`

Collects read-only evidence for:

- Microsoft Edge installation and version
- Selected Edge profile path
- Browser process state
- Existing cache and session stores
- Microsoft Forms, Office and sign-in endpoint connectivity

### `RepairAllSafe`

Runs the standard local repair sequence:

1. Stops Microsoft Edge.
2. Moves recognised Edge cache folders into a timestamped backup.
3. Clears current-user temporary internet files.
4. Flushes the Windows DNS resolver cache.
5. Opens Microsoft Forms again.

### `RestartBrowser`

Closes Microsoft Edge and opens Microsoft Forms in a fresh browser process.

### `ResetBrowserCaches`

Backs up and rebuilds common Edge cache locations, including:

- Browser cache
- Code cache
- GPU cache
- Service Worker cache
- Shader caches

The selected Edge profile is used. The default is `Default`, but another profile can be selected with `-ProfileName`.

### `ResetSignInSession`

Backs up and resets the selected Edge profile's:

- Cookie database
- Browser sessions
- Session storage

This is intended for Microsoft 365 sign-in loops, wrong-account sessions and Forms pages that repeatedly return to authentication.

**This action signs the selected Edge profile out of websites, including Microsoft 365.**

### `ClearWinInetCache`

Clears the current user's temporary Windows internet files without removing saved passwords.

### `FlushDns`

Clears the Windows DNS resolver cache.

### `OpenForms`

Opens Microsoft Forms in Edge, or in the default browser if Edge is unavailable.

## Usage

Read-only diagnosis:

```powershell
.\Repair.ps1 -Action Diagnose
```

Preview the safe repair workflow:

```powershell
.\Repair.ps1 -Action RepairAllSafe -WhatIf
```

Run the standard repairs:

```powershell
.\Repair.ps1 -Action RepairAllSafe
```

Reset a different Edge profile:

```powershell
.\Repair.ps1 -Action ResetBrowserCaches -ProfileName "Profile 1"
```

Repair a sign-in loop:

```powershell
.\Repair.ps1 -Action ResetSignInSession -ProfileName "Default" -Confirm
```

For an interactive menu, double-click:

```text
Launch_Forms_Repair.bat
```

## Logs and backups

Each run writes to:

```text
Desktop\Forms_Client_Repair
```

The output includes:

- Before-repair JSON snapshot
- After-repair JSON snapshot
- Timestamped repair log
- Timestamped browser cache or session backups

## What this tool can and cannot repair

This toolkit performs actual repairs for the Windows client, browser session and connectivity layers.

It can repair:

- Forms pages not loading correctly because of corrupt browser cache
- Repeated Microsoft 365 authentication loops
- Wrong or stale browser sessions
- Broken Service Worker cache
- DNS-related access failures
- Edge processes stuck in a bad state

It does **not** automatically change tenant-side form ownership, response permissions, sharing settings or Microsoft 365 group membership. Those changes require an authorised form owner or Microsoft 365 administrator and must be reviewed individually to prevent unintended data exposure.

## Safety

- All mutating actions use PowerShell `ShouldProcess` and support `-WhatIf`.
- Cache, cookies and session data are moved into timestamped backups rather than deleted.
- The sign-in reset action is separate from the safe repair set because it signs the selected browser profile out of websites.
- The tool does not delete Forms responses or modify Forms ownership and sharing settings.
- The first run against a new Edge profile should use `-WhatIf`.

## Validation status

Tested successfully by the author on his own Windows machines with Microsoft Edge and Microsoft Forms. The documented browser, session, cache and connectivity repairs worked as intended on those systems.

Results may vary with the Windows and Edge version, selected browser profile, Microsoft 365 tenant policy, Forms ownership and sharing configuration, permissions, account state and network environment. Use `-WhatIf` when introducing the toolkit to a new profile, tenant or machine.
