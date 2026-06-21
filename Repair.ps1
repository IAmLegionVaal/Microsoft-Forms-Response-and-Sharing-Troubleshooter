#requires -Version 5.1
<# Created by Dewald Pretorius. #>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Diagnose','ResetBrowserCache')][string]$Action='Diagnose',
    [string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Forms_Client_Repair')
)
$ErrorActionPreference='Stop'
$CachePath="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$Stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$LogPath=Join-Path $OutputPath "Repair_$Stamp.log"
function Log([string]$Message){$Line='{0:u} {1}' -f (Get-Date),$Message;Write-Host $Line;Add-Content -LiteralPath $LogPath -Value $Line}
[ordered]@{Action=$Action;EdgeRunning=[bool](Get-Process msedge -ErrorAction SilentlyContinue);CacheExists=(Test-Path -LiteralPath $CachePath)}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $OutputPath "PreRepair_$Stamp.json") -Encoding UTF8
if($Action -eq 'Diagnose'){Log '[COMPLETE] Read-only snapshot saved.';exit 0}
try{
    if($PSCmdlet.ShouldProcess($CachePath,'Preserve and reset browser cache')){
        if(Get-Process msedge -ErrorAction SilentlyContinue){throw 'Close Microsoft Edge before resetting the browser cache.'}
        if(Test-Path -LiteralPath $CachePath){
            $Backup="$CachePath.backup-$Stamp"
            Move-Item -LiteralPath $CachePath -Destination $Backup -Force
            New-Item -ItemType Directory -Path $CachePath -Force|Out-Null
            Log "[BACKUP] $Backup"
        }
    }
}catch{Log "[FAILED] $($_.Exception.Message)";exit 5}
Log '[COMPLETE] Repair completed.'
exit 0
