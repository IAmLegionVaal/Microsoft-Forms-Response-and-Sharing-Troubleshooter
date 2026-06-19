#requires -Version 5.1
<# Created by Dewald Pretorius #>
param([string]$OutputPath)
if(-not $OutputPath){$OutputPath="$([Environment]::GetFolderPath('Desktop'))\Forms_Reports"};New-Item $OutputPath -ItemType Directory -Force|Out-Null
$targets='forms.office.com','login.microsoftonline.com','graph.microsoft.com';$net=foreach($t in $targets){[pscustomobject]@{Target=$t;DNS=[bool](Resolve-DnsName $t -ErrorAction SilentlyContinue);HTTPS443=(Test-NetConnection $t -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)}}
@('MICROSOFT FORMS RESPONSE AND SHARING TROUBLESHOOTER','Created by Dewald Pretorius',"Generated: $(Get-Date)",($net|Format-Table -AutoSize|Out-String -Width 220),'Guidance: verify form ownership, response settings, anonymous versus organization access, branching, collaboration permissions, Excel export, browser storage, and service health.')|Set-Content (Join-Path $OutputPath 'Report.txt') -Encoding UTF8