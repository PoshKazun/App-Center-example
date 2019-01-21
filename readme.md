### Prerequisites:
	PowerShell 5+
	Registered account - https://appcenter.ms
	Token - https://appcenter.ms/settings/apitokens , with full access
	Registered application - https://github.com/PoshKazun/appcenter-sampleapp-android in App Center. 
	The application is forked from https://github.com/Microsoft/appcenter-sampleapp-android

### Files:
	init.ps1 - The script demonstrates how to start build all app branches
	AppCenter.ps1 - Helper functions to call APIs App Center
	
### Helper functions:
	Invoke-WebAppCenterAPI          - Wrapper for the Invoke-RestMethod cmdlet
	Get-AppCenterUser               - Returns the user profile data
	Get-AppCenterToken              - Returns api tokens for the authenticated user 
	New-AppCenterToken              - Creates a new API token
	Remove-AppCenterToken           - Delete the api_token object with the specific id
	Get-AppCenterApp                - Returns a list of apps
	Get-AppCenterAppBranch          - Returns the list of Git branches for this application
	Get-AppCenterAppBranchBuild     - Returns the list of builds for the branch
	Get-AppCenterAppBuildLog        - Get the build log
	Get-AppCenterAppBuildLogFile    - Gets the download URI
	Check-Limit                     - Validate if count inProgress&notStarted processes not more than Limit
	New-AppCenterAppBuild           - Create a build
	Get-AppCenterAppLastBuildStatus - Show last status builds

### Init parameters:
	[Token]   - API token with full access
	[AppName] - Application name (Get-AppCenterApp)
	[Limit    - Maximum parallel tasks (default = 2) per Application] !!!*
	[SaveLog  - Save all log files in the current directory.Output format - {Id}_{Branch}_{Result}.zip]
	
	!!!* - A parallel task it is not the same as concurrent build. The parallel task means that an object exists in one of the status : inProgress(Building) or notStarted(Queued). In contrast to the parallel task,however, the concurrent build means that an object exists in the inProgress(Building) status.
	
### Examples:
	# Example 1
	C:\Scripts\init.ps1 -token 0a36a3b9f2c0570adb76 -AppName Android
	
	# Example 2
	C:\Scripts\init.ps1 -token 0a36a3b9f2c0570adb76 -AppName Android -Limit 1
	
	# Example 3
	C:\Scripts\init.ps1 -token 0a36a3b9f2c0570adb76 -AppName Android -SaveLog
	
### Sample output:
	PS > C:\Scripts\init.ps1 -token 0a36a3b9f2c0570adb76a -AppName Android
	
	[1] Application Name Android
	[2] Number of branches = 5
			1 - appcenter
			2 - develop
			3 - feature
			4 - master
			5 - t-sajia/fixingInstrumentation
	[3] Start building...
			appcenter
			develop
			feature
			master
			t-sajia/fixingInstrumentation
	[4] Wait until all tasks have finished
			...
	[5] Show output

	Branch name Build status Duration         Link to build logs
	----------- ------------ --------         ------------------
	appcenter   succeeded    00:01:04         https://build.appcenter.ms/v0.1/public/apps/baef20a7-56fa-4544-bffa-a67241...
	develop     succeeded    00:01:04	  https://build.appcenter.ms/v0.1/public/apps/baef20a7-56fa-4544-bffa-a67241...
	feature     succeeded    00:01:28   	  https://build.appcenter.ms/v0.1/public/apps/baef20a7-56fa-4544-bffa-a67241...
	master      succeeded    00:01:34	  https://build.appcenter.ms/v0.1/public/apps/baef20a7-56fa-4544-bffa-a67241...
	t-sajia/... succeeded    00:01:22         https://build.appcenter.ms/v0.1/public/apps/baef20a7-56fa-4544-bffa-a67241..
	
