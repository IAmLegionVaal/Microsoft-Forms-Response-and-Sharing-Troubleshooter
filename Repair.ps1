#requires -Version 5.1
<#
.SYNOPSIS
    Microsoft Forms browser repair toolkit.
.DESCRIPTION
    Performs guarded local repairs for Microsoft Forms access, response and sharing
    pages in Microsoft Edge. Repairs include browser cache rebuild, authentication
    session reset, browser restart, WinINet cleanup and DNS repair.
.NOTES
    Created by Dewald Pretorius - L2 IT Support Engineer.
    This tool repairs the local client. Tenant-side ownership and sharing changes
    must still be performed by an authorised Microsoft 365 owner or administrator.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet(
        'Diagnose',
        'RepairAllSafe',
        'RestartBrowser',
        'ResetBrowserCaches',
        'ResetSignInSession',
        'ClearWinInetCache',
        'FlushDns',
        'OpenForms'
    )]
    [string]$Action = 'Diagnose',

    [string]$ProfileName = 'Default',

    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Forms_Client_Repair')
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '2.0.0'
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$EdgeUserData = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
$BackupRoot = Join-Path $OutputPath "Backup_$Stamp"
$LogPath = Join-Path $OutputPath "Repair_$Stamp.log"

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')][string]$Level = 'INFO'
    )

    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8

    switch ($Level) {
        'WARN'    { Write-Host $Message -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Message -ForegroundColor Red }
        'SUCCESS' { Write-Host $Message -ForegroundColor Green }
        default   { Write-Host $Message }
    }
}

function Get-EdgeProfilePath {
    $requested = Join-Path $EdgeUserData $ProfileName
    if (Test-Path -LiteralPath $requested) { return $requested }

    $fallback = Get-ChildItem -LiteralPath $EdgeUserData -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($fallback) {
        Write-Log "Requested Edge profile '$ProfileName' was not found. Using '$($fallback.Name)'." 'WARN'
        return $fallback.FullName
    }

    return $requested
}

function Get-EdgeExecutable {
    $paths = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    )

    foreach ($path in $paths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    $command = Get-Command msedge.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Get-CacheItems {
    param([Parameter(Mandatory)][string]$ProfilePath)

    $candidates = [ordered]@{
        'Cache'               = (Join-Path $ProfilePath 'Cache')
        'CodeCache'           = (Join-Path $ProfilePath 'Code Cache')
        'GpuCache'            = (Join-Path $ProfilePath 'GPUCache')
        'ServiceWorkerCache'  = (Join-Path $ProfilePath 'Service Worker\CacheStorage')
        'ServiceWorkerScript' = (Join-Path $ProfilePath 'Service Worker\ScriptCache')
        'DawnCache'           = (Join-Path $ProfilePath 'DawnCache')
        'GrShaderCache'       = (Join-Path $ProfilePath 'GrShaderCache')
    }

    $items = @()
    foreach ($entry in $candidates.GetEnumerator()) {
        if (Test-Path -LiteralPath $entry.Value) {
            $items += [pscustomobject]@{ Label = $entry.Key; Path = $entry.Value }
        }
    }

    return $items
}

function Get-SessionItems {
    param([Parameter(Mandatory)][string]$ProfilePath)

    $candidates = [ordered]@{
        'NetworkCookies' = (Join-Path $ProfilePath 'Network\Cookies')
        'LegacyCookies'  = (Join-Path $ProfilePath 'Cookies')
        'Sessions'       = (Join-Path $ProfilePath 'Sessions')
        'SessionStorage' = (Join-Path $ProfilePath 'Session Storage')
    }

    $items = @()
    foreach ($entry in $candidates.GetEnumerator()) {
        if (Test-Path -LiteralPath $entry.Value) {
            $items += [pscustomobject]@{ Label = $entry.Key; Path = $entry.Value }
        }
    }

    return $items
}

function Stop-EdgeProcesses {
    $processes = @(Get-Process -Name msedge -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        if ($PSCmdlet.ShouldProcess("Microsoft Edge process $($process.Id)", 'Stop process')) {
            try { [void]$process.CloseMainWindow() } catch {}
        }
    }

    if ($processes.Count -gt 0) {
        Start-Sleep -Seconds 3
        foreach ($process in @(Get-Process -Name msedge -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess("Microsoft Edge process $($process.Id)", 'Force stop process')) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                Write-Log "Stopped Microsoft Edge process ID $($process.Id)." 'SUCCESS'
            }
        }
    }
}

function Move-PathToBackup {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $safeLabel = $Label -replace '[^a-zA-Z0-9._-]', '_'
    $destination = Join-Path $BackupRoot $safeLabel

    if ($PSCmdlet.ShouldProcess($Path, "Move to backup: $destination")) {
        if (Test-Path -LiteralPath $destination) {
            $destination = "$destination-$Stamp"
        }
        Move-Item -LiteralPath $Path -Destination $destination -Force
        Write-Log "Backed up $Path to $destination." 'SUCCESS'
    }
}

function Save-FormsSnapshot {
    param([Parameter(Mandatory)][string]$Stage)

    $profilePath = Get-EdgeProfilePath
    $edgeExe = Get-EdgeExecutable
    $edgeVersion = $null
    if ($edgeExe) {
        try { $edgeVersion = (Get-Item -LiteralPath $edgeExe).VersionInfo.FileVersion } catch {}
    }

    $endpoints = foreach ($target in @(
        'forms.office.com',
        'forms.cloud.microsoft',
        'login.microsoftonline.com',
        'www.office.com'
    )) {
        $dns = $false
        $https = $false
        try { [void][System.Net.Dns]::GetHostAddresses($target); $dns = $true } catch {}
        try { $https = Test-NetConnection -ComputerName $target -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue } catch {}
        [pscustomobject]@{ Target = $target; DNS = $dns; HTTPS443 = $https }
    }

    $snapshot = [ordered]@{
        Stage = $Stage
        Generated = (Get-Date).ToString('o')
        ScriptVersion = $ScriptVersion
        Action = $Action
        Computer = $env:COMPUTERNAME
        User = "$env:USERDOMAIN\$env:USERNAME"
        EdgeExecutable = $edgeExe
        EdgeVersion = $edgeVersion
        RequestedProfile = $ProfileName
        ResolvedProfilePath = $profilePath
        ProfileExists = (Test-Path -LiteralPath $profilePath)
        EdgeProcesses = @(
            Get-Process -Name msedge -ErrorAction SilentlyContinue |
                Select-Object Id, ProcessName, Path, StartTime
        )
        CacheItems = @(
            Get-CacheItems -ProfilePath $profilePath
        )
        SessionItems = @(
            Get-SessionItems -ProfilePath $profilePath
        )
        Endpoints = $endpoints
    }

    $snapshotPath = Join-Path $OutputPath "Forms_${Stage}_$Stamp.json"
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
    Write-Log "Saved $Stage snapshot: $snapshotPath" 'SUCCESS'
}

function Invoke-RestartBrowser {
    Stop-EdgeProcesses
    Invoke-OpenForms
}

function Invoke-ResetBrowserCaches {
    $profilePath = Get-EdgeProfilePath
    if (-not (Test-Path -LiteralPath $profilePath)) {
        throw "Microsoft Edge profile not found: $profilePath"
    }

    $items = @(Get-CacheItems -ProfilePath $profilePath)
    if ($items.Count -eq 0) {
        Write-Log 'No recognised Microsoft Edge cache folders were found.' 'WARN'
        return
    }

    Stop-EdgeProcesses
    foreach ($item in $items) {
        Move-PathToBackup -Path $item.Path -Label $item.Label
    }

    Write-Log 'Microsoft Edge browser caches were reset. Edge will recreate them.' 'SUCCESS'
}

function Invoke-ResetSignInSession {
    $profilePath = Get-EdgeProfilePath
    if (-not (Test-Path -LiteralPath $profilePath)) {
        throw "Microsoft Edge profile not found: $profilePath"
    }

    $items = @(Get-SessionItems -ProfilePath $profilePath)
    if ($items.Count -eq 0) {
        Write-Log 'No Edge cookie or session stores were found.' 'WARN'
        return
    }

    Write-Log 'This repair signs the selected Edge profile out of websites, including Microsoft 365.' 'WARN'
    Stop-EdgeProcesses

    foreach ($item in $items) {
        Move-PathToBackup -Path $item.Path -Label $item.Label
    }

    Write-Log 'Edge cookies and session data were backed up and reset.' 'SUCCESS'
}

function Invoke-ClearWinInetCache {
    if ($PSCmdlet.ShouldProcess('Current user temporary internet files', 'Clear WinINet cache')) {
        Start-Process -FilePath rundll32.exe -ArgumentList 'InetCpl.cpl,ClearMyTracksByProcess 8' -Wait
        Write-Log 'Current-user temporary internet files were cleared.' 'SUCCESS'
    }
}

function Invoke-FlushDns {
    if ($PSCmdlet.ShouldProcess('Windows DNS client cache', 'Clear')) {
        if (Get-Command Clear-DnsClientCache -ErrorAction SilentlyContinue) {
            Clear-DnsClientCache
        } else {
            & ipconfig.exe /flushdns | Out-Null
        }
        Write-Log 'DNS resolver cache cleared.' 'SUCCESS'
    }
}

function Invoke-OpenForms {
    $edgeExe = Get-EdgeExecutable
    $formsUrl = 'https://forms.office.com'

    if ($edgeExe) {
        if ($PSCmdlet.ShouldProcess($formsUrl, 'Open Microsoft Forms in Edge')) {
            Start-Process -FilePath $edgeExe -ArgumentList $formsUrl
            Write-Log 'Opened Microsoft Forms in Microsoft Edge.' 'SUCCESS'
        }
    } elseif ($PSCmdlet.ShouldProcess($formsUrl, 'Open Microsoft Forms in the default browser')) {
        Start-Process $formsUrl
        Write-Log 'Microsoft Edge was not found; opened Forms in the default browser.' 'WARN'
    }
}

function Invoke-SafeRepairSet {
    Invoke-ResetBrowserCaches
    Invoke-ClearWinInetCache
    Invoke-FlushDns
    Invoke-OpenForms
}

Write-Log "Microsoft Forms Repair Toolkit $ScriptVersion started. Action=$Action; Profile=$ProfileName"
Save-FormsSnapshot -Stage 'Before'

$exitCode = 0
try {
    switch ($Action) {
        'Diagnose'           { Write-Log 'Read-only diagnosis completed.' 'SUCCESS' }
        'RepairAllSafe'      { Invoke-SafeRepairSet }
        'RestartBrowser'     { Invoke-RestartBrowser }
        'ResetBrowserCaches' { Invoke-ResetBrowserCaches }
        'ResetSignInSession' { Invoke-ResetSignInSession }
        'ClearWinInetCache'  { Invoke-ClearWinInetCache }
        'FlushDns'           { Invoke-FlushDns }
        'OpenForms'          { Invoke-OpenForms }
    }
} catch {
    $exitCode = 5
    Write-Log $_.Exception.Message 'ERROR'
} finally {
    try {
        Save-FormsSnapshot -Stage 'After'
    } catch {
        Write-Log "Final snapshot failed: $($_.Exception.Message)" 'WARN'
    }

    if ($exitCode -eq 0) {
        Write-Log "Completed. Logs and backups: $OutputPath" 'SUCCESS'
    } else {
        Write-Log "Completed with errors. Logs and backups: $OutputPath" 'ERROR'
    }
}

exit $exitCode
