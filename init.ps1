#Requires -Version 5

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[System.String]$Token,
	
	[Parameter(Mandatory)]
	[System.String]$AppName,
	
	# Parallel tasks
	[System.Byte]$Limit = 2,
	
	[Switch]$SaveLog
)

# Import helper functions
. $PSScriptRoot\AppCenter.ps1

# TLS12
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Validate full access token
try {
	$null = Get-AppCenterToken 
} catch {
	throw "$_"	
	break
}

# Start building the app with limitation to parallel runnings
Write-Host "[1] Application Name $AppName" -ForegroundColor Yellow

# App
$Application = Get-AppCenterApp | Where-Object Name -eq $AppName 

if (-Not $Application) {
	$apps = (Get-AppCenterApp).Name -join "`r`n`t"
	throw "Application $AppName not found. Available: `r`n`t$apps"
	break
}

# Application owner
$Owner = $Application.Owner

if (-Not $Owner) {
	throw "Owner not found for the $AppName application"
	break
}

# List of Branches
[System.Object[]]$Branches = Get-AppCenterAppBranch -OwnerName $Owner.Name -AppName $AppName

Write-Host "[2] Number of branches = $($Branches.Count)" -ForegroundColor Yellow
$Branches | Foreach-Object -Begin { $i=1 } -Process {
	Write-Host "`t$i - $($_.branch.name)" -ForegroundColor Green
	$i++
}

Write-Host "[3] Start building..." -ForegroundColor Yellow
$total = @()
$exclude = @()
$err = 0

# err - additional variable to prevent infinity loop
while($total.Count -lt $Branches.Count -and $err -lt ($Branches.Count * 60)) {
	$IsCheck = Check-Limit -AppName $AppName -Limit $Limit
	
	if ($IsCheck) {
		foreach ($branch in $Branches) {
			$Name = $branch.branch.name
			
			if ($exclude -notcontains $name) {
				try {
					$total += New-AppCenterAppBuild -Branch $Name -OwnerName $Owner.Name -AppName $AppName -Limit $Limit
					$exclude += $Name
					Write-Host "`t$Name" -ForegroundColor Green
					Start-Sleep -Seconds 5
				} 
				catch {
				}
			}		
		}
	}
	
	$err++
	Start-Sleep -Seconds 60
}

Write-Host "[4] Wait until all tasks have finished" -ForegroundColor Yellow
Write-Host "`t..." -ForegroundColor Green
if ($total) {
	while(1) {
		$IsTask = $total | Get-AppCenterAppBuild -OwnerName $Owner.Name -AppName $AppName | Where-Object Status -ne "completed"

		if (-Not $IsTask) {
			break
		}
		
		Start-Sleep -Seconds 60
	}

	Write-Host "[5] Show output" -ForegroundColor Yellow
	
	$Builds = $total | Get-AppCenterAppBuild -OwnerName $Owner.Name -AppName $AppName
	$Builds | Sort-Object id | Select-Object -Property @{n = "Branch name"; e = {$_.sourceBranch}},
		@{n = "Build status"; e = {$_.result}},
		@{n = "Duration"; e = {([System.Datetime]$_.finishTime - [System.Datetime]$_.startTime).ToString().Split(".")[0]}},
		@{n = "Link to build logs"; e = { (Get-AppCenterAppBuildLogFile -Build $_.id -OwnerName $Owner.Name -AppName $AppName).Uri }}
	
	if($SaveLog) {
		Write-Host "[6] Saving log files" -ForegroundColor Yellow
		
		foreach($build in $Builds) {
			$Id = $Build.id
			$Result = $Build.result
			
			$Branch = [System.Uri]::EscapeDataString($Build.sourceBranch)
			$LogName = "{0}_{1}_{2}.zip" -f $Id, $Branch, $Result 
			Write-Host "`t$LogName" -ForegroundColor Green
				
			$Log = Get-AppCenterAppBuildLogFile -BuildId $Id -OwnerName $Owner.Name -AppName $AppName
			Invoke-WebRequest -Uri $Log.uri -OutFile $LogName			
		}
	}
}
