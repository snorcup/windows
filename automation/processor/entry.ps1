Param (
	[string]$automationRoot,
	[string]$BUILDNUMBER,
	[string]$branch,
	[string]$action
)

Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management
Import-Module Microsoft.PowerShell.Security

cmd /c "exit 0"
$scriptName = 'entry.ps1'

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeExpression ($expression) {
    $error.clear()
    Write-Host "$expression"
    try {
        Invoke-Expression $expression
        if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
    } catch { Write-Output $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

# Capture and return expression output
function executeReturn ($expression) {
    $error.clear()
    Write-Host "$expression"
    try {
        $result = Invoke-Expression $expression
        if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
    } catch { Write-Output $_.Exception|format-list -force; exit 2 }
    if ( $error ) { Write-Host "[$scriptName] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
    return $result
}

# Common expression logging and error handling function, copied, not referenced to ensure atomic process
function executeSuppress ($expression) {
    Write-Host "$expression"
    try {
        Invoke-Expression $expression
        if(!$?) { Write-Host "[$scriptName] `$? = $?"; exit 1 }
    } catch { Write-Host $_.Exception|format-list -force; exit 2 }
    $error.clear()
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName] Suppress `$LASTEXITCODE ($LASTEXITCODE)"; cmd /c "exit 0" } # reset LASTEXITCODE
}

Write-Host "`n[$scriptName] ---------- start ----------"
if ($automationRoot) {
    Write-Host "[$scriptName]   automationRoot : $automationRoot"
} else {
	$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
	$automationRoot = split-path -parent $scriptPath
    Write-Host "[$scriptName]   automationRoot : $automationRoot (not supplied, derived from invocation)"
}
$env:CDAF_AUTOMATION_ROOT = $automationRoot

if ($BUILDNUMBER) {
    Write-Host "[$scriptName]   BUILDNUMBER    : $BUILDNUMBER"
} else {

	$counterFile = "$env:USERPROFILE\buildnumber.counter"
	# Use a simple text file ($counterFile) for incrimental build number, using the same logic as cdEmulate.ps1
	if ( Test-Path "$counterFile" ) {
		$buildNumber = Get-Content "$counterFile"
	} else {
		$buildNumber = 0
	}
	[int]$buildnumber = [convert]::ToInt32($buildNumber)
	if ( $action -ne "cdonly" ) { # Do not incriment when just deploying
		$buildNumber += 1
	}
	Set-Content "$counterFile" "$BUILDNUMBER"
    Write-Host "[$scriptName]   BUILDNUMBER    : $BUILDNUMBER (not supplied, generated from local counter file)"
}

if ($branch) {
    Write-Host "[$scriptName]   branch         : $branch"
} else {
	if ( $env:CDAF_BRANCH_NAME ) {
		$branch = $env:CDAF_BRANCH_NAME
	    Write-Host "[$scriptName]   branch         : $branch (not supplied, derived from `$env:CDAF_BRANCH_NAME)"
	} else {
		$branch = 'feature'
	    Write-Host "[$scriptName]   branch         : $branch (not supplied, set to default)"
	}
}

if ($action) {
    Write-Host "[$scriptName]   action         : $action"
} else {
    Write-Host "[$scriptName]   action         : (not set, set to remoteURL@ to trigger clean)"
}

# check for DOS variable and load as PowerShell environment variable
if ($CDAF_DELIVERY) { $environment = "$CDAF_DELIVERY" }
if ($Env:CDAF_DELIVERY) { $environment = "$Env:CDAF_DELIVERY" }
if ($environment) {
    Write-Host "[$scriptName]   environment    : $environment (from CDAF_DELIVERY environment variable)"
} else {
	$environment = 'DOCKER'
    Write-Host "[$scriptName]   environment    : (not set, default applied)"
}

# Check for user defined solution folder, i.e. outside of automation root, if found override solution root
Write-Host "[$scriptName]   solutionRoot   : " -NoNewline
foreach ($item in (Get-ChildItem -Path ".")) {
	if (Test-Path $item -PathType "Container") {
		if (Test-Path "$item\CDAF.solution") {
			$solutionRoot=$item
		}
	}
}

if ($solutionRoot) {
	write-host "$solutionRoot (override $solutionRoot\CDAF.solution found)"
} else {
	$solutionRoot="$automationRoot\solution"
	write-host "$solutionRoot (default, project directory containing CDAF.solution not found)"
}

$automationHelper = "$automationRoot\remote"
& $automationHelper\Transform.ps1 "$SOLUTIONROOT\CDAF.solution" | ForEach-Object { invoke-expression $_ }

if ( $artifactPrefix ) {
	$entryArtPrefix = $artifactPrefix
	Write-Host "`n[$scriptName]   artifactPrefix = $artifactPrefix (will deploy using $solutionName.ps1)"
} else {
	Write-Host "`n[$scriptName]   artifactPrefix = (not set, will deploy using .\TasksLocal\delivery.ps1)"
}

$workspace = $(Get-Location)
Write-Host "[$scriptName]   pwd            = $workspace"
Write-Host "[$scriptName]   hostname       = $(hostname)" 
Write-Host "[$scriptName]   whoami         = $(whoami)`n"

if ( $branch -eq 'master' ) {
	executeExpression "$automationRoot\processor\buildPackage.ps1 $BUILDNUMBER $branch $action"
} else {
	Write-Host "[$scriptName] Do not pass ACTION when executing feature branch (non-master)"
	executeExpression "$automationRoot\processor\buildPackage.ps1 $BUILDNUMBER $branch"
}

if (( $branch -eq 'master' ) -or ( $branch -eq 'refs/heads/master' )) {
	Write-Host "[$scriptName] Only perform container test in CI for branches, Master execution in CD pipeline"
} else {
	Write-Host "[$scriptName] Only perform container test in CI for feature branches, CD for branch $branch"
	if ( $entryArtPrefix ) {
		executeExpression ".\$solutionName.ps1 $environment"
	} else {
		executeExpression ".\TasksLocal\delivery.ps1 $environment"
	}
}

$prefix,$remoteURL = $action.Split('@')
 
if ( $prefix -eq 'remoteURL' ) {

	Write-Host "[$scriptName] ACTION ($action) prefix is remoteURL@, attempt remote branch synchronisation"
	
	if (!( ${solutionName} )) {
		Write-Host "`n[$scriptName]   solutionName not defined!"
		exit 7762 
	}
	
	Write-Host "`n[$scriptName] Load Local branches`n"
	$gitBranch = executeReturn 'git branch'
	
	Write-Host "`n[$scriptName] Local branches`n"
	$localBranches = @()
	foreach ($branchName in $gitBranch) {
		$branchName = ($branchName.Replace(" ","")).Replace("*","")
		Write-Host "[$scriptName]   $branchName"
		$localBranches += $branchName
	}
	
	Write-Host "`n[$scriptName] Load remote branches`n"
	executeExpression 'git fetch --prune'
	if ($remoteURL) {
		$gitlsremoteheads = executeSuppress "git ls-remote $remoteURL 2>`$null | Select-String 'refs/heads'"
	} else {
		$gitlsremoteheads = executeSuppress 'git ls-remote 2>$null | Select-String "refs/heads"'
	}
	
	Write-Host "`n[$scriptName] Remote branches`n"
	$remoteBranches = @()
	foreach ($branchName in $gitlsremoteheads) {
		$branchName = $(($branchName.tostring()).Replace('refs/heads/','|').split('|')[-1])
		Write-Host "[$scriptName]   $branchName"
		$remoteBranches += $branchName
	}
	
	Write-Host "`n[$scriptName] Delete Local Branches that are not active on Remote`n"
	foreach ( $localBranch in $localBranches ) {
		if ($remoteBranches -contains $localBranch) {
			Write-Host "active branch $localBranch"
		} else {
			executeExpression "git branch -D $localBranch"
		}
	}
	

	if ( $environment -eq 'DOCKER' ) {

		Write-Host "`n[$scriptName] Load docker images`n"
		$dockerImages = executeReturn 'docker images --format "{{.Repository}}:{{.Tag}}:{{.ID}}" 2> $null'
		
		# Numbered lists for summary report
		$imagesListBeforeHousekeeping = foreach ($i in $dockerImages) { $i_countb++; Write-Output "$i_countb. $($i.split(':')[0]):$($i.split(':')[1])"`n }
		
		Write-Host "`n[$scriptName] Delete images for inactive branches`n"
		$imagesRetained = @()
		foreach ($i in $dockerImages) {
			if ($i -like "${solutionName}_*") {
				$remove = $True
				foreach ($b in $remoteBranches) {
					if (( $i -like "${solutionName}_$b*" ) -or ( $i -like "${solutionName}_container_*" )) {
						$imagesRetained += $( $b_count++; Write-Output "$b_count. $i"`n )
						$remove = $False
						break
					}
				}
				if ( $remove ) {
					executeSuppress "docker rmi $($i.split(':')[2])"
					$i_countd++
					$imagesListDeleted = "$imagesListDeleted $i_countd. $($i.split(':')[0]):$($i.split(':')[1])`n"
				}
			}
		}
		if (!( $i_countd )) { Write-Host "  < none >" }
		
		Write-Host "`n[$scriptName] Housekeeping Summary`n"
		Write-Host "[$scriptName]   List of docker images (before housekeeping)`n $imagesListBeforeHousekeeping"
		
		$images = docker images --format "{{.Repository}}:{{.Tag}}:{{.ID}}" 2> $null
		$imagesListPostHousekeeping = foreach ($i in $images) { $i_countp++; Write-Output "$i_countp. $($i.split(':')[0]):$($i.split(':')[1])`n" }
		Write-Host "[$scriptName]   List of docker images (after housekeeping)`n $imagesListPostHousekeeping"
		
		Write-Host "[$scriptName]   List of docker images retained`n $imagesRetained"
		Write-Host "[$scriptName]   List of docker images deleted`n$imagesListDeleted"
	}

} else {

	Write-Host "[$scriptName] Action prefix is not 'remoteURL' so housekeeping not attempted"

}

executeExpression "cd $workspace"

if ( ! (( $branch -eq 'master' ) -or ( $branch -eq 'refs/heads/master' ))) {
	Write-Host "[$scriptName] Purge artifacts for feature branches"
	if ( $entryArtPrefix ) {
		executeExpression "Set-Content $solutionName.ps1 'Write-Host `"Dummy Artefact for Feature Branch`"'"
	} else {
		$zipPackage = (Get-Item '*.zip').Name
		if ( $zipPackage ) {
			executeExpression "Remove-Item -Force $zipPackage"
			executeExpression "New-Item -Name $zipPackage -ItemType File"
		}
		$dirPackage = (Get-Item 'TasksLocal').Name
		if ( $dirPackage ) {
			executeExpression "Remove-Item -Recurse -Force '${dirPackage}\*'"
			executeExpression "Add-Content ${dirPackage}\readme.md 'Dummy artifact created by entry.ps1 for feature branch $branch'"
		}
	}
}

Write-Host "`n[$scriptName] ---------- stop ----------"
