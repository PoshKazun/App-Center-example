# Wrapper for the Invoke-RestMethod cmdlet

Function Invoke-WebAppCenterAPI {
	param(
		[System.Uri]$Uri,			
		[System.Object]$Body,
		[System.String]$ContentType = "application/json",		
		[System.String]$Method = "Get",				
		[System.String]$ApiToken = $token
	)
	
	$RestParams = @{
		"Uri" = $Uri
		"ContentType" = $ContentType
		"Method" = $Method
		"Headers" = @{"X-API-Token" = $ApiToken}
	}
	
	if($PSBoundParameters["Body"]) {
		$RestParams["Body"] = $Body
	}
	
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
	
	Invoke-RestMethod @RestParams | Foreach-Object -Process {$_}
}

# Returns the user profile data - https://appcenter.ms/settings/profile

Function Get-AppCenterUser {
	[CmdletBinding()]
	param(
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/user"
	)
	
	Invoke-WebAppCenterAPI -Uri $Uri
}

# Returns api tokens for the authenticated user

Function Get-AppCenterToken {
	[CmdletBinding()]
	param(
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/api_tokens"
	)
	
	Invoke-WebAppCenterAPI -Uri $Uri
}

# Creates a new API token

Function New-AppCenterToken {
	[CmdletBinding()]
	param(		
		[Parameter(Mandatory)]
		[System.String]$Description,
		
		[ValidateSet("all", "viewer")]
		[System.String]$Scope = "viewer",
		
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/api_tokens"
	)
	
	$JsonBody = '{{"description": "{0}","scope":["{1}"]}}' -f $Description, $Scope
	
	Invoke-WebAppCenterAPI -Uri $Uri -Body $JsonBody -Method Post
}

# Delete the api_token object with the specific id

Function Remove-AppCenterToken {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName,Position=0)]
		[ValidateScript({$_ -as [System.Guid]})]
		[Alias("id")]
		[System.String[]]$ApiTokenId,
		
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/api_tokens"
	)

	Process {
		foreach($id in $ApiTokenId) {
			Invoke-WebAppCenterAPI -Uri "${Uri}/${ApiTokenId}" -Method Delete
		}
	}
}

# Returns a list of apps

Function Get-AppCenterApp {
	[CmdletBinding()]
	param(
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/apps"
	)
	
	Invoke-WebAppCenterAPI -Uri $Uri
}

# Returns the list of Git branches for this application

Function Get-AppCenterAppBranch {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.String]$OwnerName,
		
		[Parameter(Mandatory)]
		[System.String]$AppName,
		
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/apps"
	)
	
	Invoke-WebAppCenterAPI -Uri "${Uri}/${OwnerName}/${AppName}/branches"
}

# Returns the list of builds for the branch

Function Get-AppCenterAppBranchBuild {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.String]$Branch,
		
		[Parameter(Mandatory)]
		[System.String]$OwnerName,
		
		[Parameter(Mandatory)]
		[System.String]$AppName,
		
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/apps"
	)
	
	# Escape branch string name
	$Branch = [System.Uri]::EscapeDataString($Branch)
	
	Invoke-WebAppCenterAPI -Uri "${Uri}/${OwnerName}/${AppName}/branches/${Branch}/builds"
}

# Returns the build detail for the given build ID
Function Get-AppCenterAppBuild {
	param(
		[Parameter(Mandatory, ValueFromPipelineByPropertyName,Position=0)]
		[Alias("id")]
		[System.String[]]$BuildId,
		
		[Parameter(Mandatory)]
		[System.String]$OwnerName,
			
		[Parameter(Mandatory)]
		[System.String]$AppName,
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/apps"
	)
	
	Process {
		foreach ($id in $BuildId) {
			Invoke-WebAppCenterAPI -Uri "${Uri}/${OwnerName}/${AppName}/builds/${Id}"
		}
	}
}

# Get the build log
Function Get-AppCenterAppBuildLog {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.String]$BuildId,
		
		[Parameter(Mandatory)]
		[System.String]$OwnerName,
		
		[Parameter(Mandatory)]
		[System.String]$AppName,
		
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/apps"
	)
	
	Invoke-WebAppCenterAPI -Uri "${Uri}/${OwnerName}/${AppName}/builds/${BuildId}/logs"
}

# Gets the download URI

Function Get-AppCenterAppBuildLogFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.String]$BuildId,
		
		[ValidateSet("logs", "build", "symbols")]
		[System.String]$DownloadType = "logs",
		
		[Parameter(Mandatory)]
		[System.String]$OwnerName,
		
		[Parameter(Mandatory)]
		[System.String]$AppName,
		
		[System.Uri]$Uri = "https://api.appcenter.ms/v0.1/apps"
	)
	
	Invoke-WebAppCenterAPI -Uri "${Uri}/${OwnerName}/${AppName}/builds/${BuildId}/downloads/${DownloadType}"
}


# Validate if count inProgress processes not more than Limit
Function Check-Limit {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.String]$AppName,
		
		[System.Byte]$Limit = 2,		
		[Switch]$PassThru
	)
	
	$AllowStartNewBuild = $true
	
	$BuildsInTime = Get-AppCenterApp | Where-Object Name -eq $AppName | Foreach-Object {
		$app = $_
		$branches = Get-AppCenterAppBranch -OwnerName $app.owner.Name -AppName $app.Name | Where-Object configured
		foreach($branch in $branches) {
			Get-AppCenterAppBranchBuild -Branch $branch.branch.name -OwnerName $app.owner.Name -AppName $app.Name
		}
	}
	
	Write-Verbose ($BuildsInTime | Out-String)
	
	if ($BuildsInTime) {
		[System.Object[]]$InProgress = $BuildsInTime | Where-Object {@("inProgress","notStarted") -contains $_.status}

		if ($InProgress.Count -ge $Limit) {
			$AllowStartNewBuild = $false
		}
	}
	
	if ($PSBoundParameters["PassThru"]) {
		$InProgress
	} else {
		$AllowStartNewBuild
	}
}

# Create a build
Function New-AppCenterAppBuild {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.String]$Branch,
		
		[Boolean]$DebugBuild = $True,
		
		[Parameter(Mandatory)]
		[System.String]$OwnerName,
		
		[Parameter(Mandatory)]
		[System.String]$AppName,
		
		[Switch]$UseLimit = $True,
		
		[System.Byte]$Limit = 2,
		
		[System.URI]$Uri = "https://api.appcenter.ms/v0.1/apps"
	)
	
	if ($UseLimit) {
		$IsAllowToStartNewBuild = Check-Limit -AppName $AppName -Limit $Limit
		
		if (-Not $IsAllowToStartNewBuild) {
			throw "Maximum parallel tasks are more than $Limit !!!"
			break
		}
	}
	
	$sourceVersion = Get-AppCenterAppBranch -OwnerName $OwnerName -AppName $AppName | Foreach-Object -Process {
		$_.branch | Where-Object Name -eq $Branch | Foreach-Object -Process {$_.Commit.Sha}
	}
	
	$JsonBody = '{{"sourceVersion": "{0}","debug":{1}}}' -f $sourceVersion, $DebugBuild.ToString().ToLower()
	
	# Escape branch string name
	$Branch = [System.Uri]::EscapeDataString($Branch)
			
	Invoke-WebAppCenterAPI -Uri "${Uri}/${OwnerName}/${AppName}/branches/${Branch}/builds" -Body $JsonBody -Method Post
}

# Show last status builds
Function Get-AppCenterAppLastBuildStatus {
	param(
		[System.String]$AppName,
		[Switch]$ShowApp
	)

	Get-AppCenterApp | Where-Object Name -eq $AppName | Foreach-Object -Process {
		$app = $_
		$LastBuildStatus = Get-AppCenterAppBranch -OwnerName $app.owner.Name -AppName $app.Name | Where-Object configured
		
		foreach ($status in $LastBuildStatus) {
			$duration = $null
			$name = $status.branch.name
			$result = $null
			$duration = $null
			$logfile = $null
			
			if($status.lastBuild) {
				$lb = $status.lastBuild
				$result = $lb.result
				
				if ($lb.status -eq "completed") {
					$duration = ([System.Datetime]$lb.finishTime - [System.Datetime]$lb.startTime).ToString()
					$duration = $duration.Split(".")[0]
				}
				
				if (-Not $result) {
					$result = $lb.status
				}
				
				$logfile = Get-AppCenterAppBuildLogFile -Build $lb.id -OwnerName $app.owner.Name -AppName $app.Name
				$logfile = $logfile.uri
			}

			$Value = [Ordered] @{
				"Branch name" = $name
				"Build status" = $result
				"Duration" = $duration
				"Link to build logs" = $logfile
			}
			
			if($ShowApp) {
				$value["AppName"] = $app.Name
			}
			
			[PSCustomObject]$Value
		}
	}
	
}
