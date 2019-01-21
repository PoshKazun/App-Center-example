#Requires -Version 5

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[System.String]$Token,
	
	[Parameter(Mandatory)]
	[System.String]$AppName,
	
	# Parallel tasks
	[System.Byte]$Limit = 2
)

# Clears the display in the host program.
Clear-Host

# Import helper functions
. $PSScriptRoot\AppCenter.ps1

# TLS12
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Validate full access token
try {
	Get-AppCenterToken 
} catch {
	throw "$_"
	
	break
}

# Start building the app with limitation to parallel runnings
Write-Host "[1] Application Name $AppName" -ForegroundColor Yellow

# User App Center
$Owner = Get-AppCenterUser
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
		$IsTask = $total | Get-AppCenterAppBuild -OwnerName $Owner.Name -AppName $AppName | Where-Object {$_.status -ne "completed"}

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
}
