Param (
	[string]$runnerURL,
	[string]$personalAccessToken,
	[string]$runnerSA,
	[string]$runnerTags,
	[string]$runnerExecutor,
	[string]$runnerSAPassword,
	[string]$runnerName,
	[string]$stable,
	[string]$docker,
	[string]$git,
	[string]$restart
)

function executeExpression ($expression) {
	Write-Host "[$(Get-date)] $expression"
	try {
		Invoke-Expression "$expression"
	    if(!$?) { Write-Host "[FAILURE][$scriptName] `$? = $?" ; $error ; exit 1 }
	} catch { Write-Host "[EXCEPTION][$scriptName] ..."; Write-Output $_.Exception|format-list -force ; $error ; exit 2 }
    if ( $error ) { Write-Host "[$scriptName][ERROR] `$error[0] = $error"; exit 3 }
    if (( $LASTEXITCODE ) -and ( $LASTEXITCODE -ne 0 )) { Write-Host "[$scriptName][EXIT] `$LASTEXITCODE = $LASTEXITCODE "; exit $LASTEXITCODE }
}

$scriptName = 'bootstrap-runner.ps1'
cmd /c "exit 0" # ensure LASTEXITCODE is 0
$error.clear()

Write-Host "`n[$scriptName] ---------- start ----------"
if ($runnerURL) {
    Write-Host "[$scriptName] runnerURL           : $runnerURL"
} else {
	Write-Host "[$scriptName] runnerURL not supplied! Exit with error 7241"
	Write-Host "Usage example : .\bootstrap-runner.ps1 https://gitlab.com/ xxxxxxxxxxxxxxxxxxx .\gitlab-runner dotnet-tag -docker no"
	exit 7241
}

if ($personalAccessToken) {
    Write-Host "[$scriptName] personalAccessToken : `$personalAccessToken"
} else {
    Write-Host "[$scriptName] personalAccessToken not supplied! Exit with error 7242"; exit 7242
}

if ($runnerSA) {
    Write-Host "[$scriptName] runnerSA            : $runnerSA"
} else {
    Write-Host "[$scriptName] runnerSA            : $runnerSA (not supplied, will install as inbuilt account)"
}

if ($runnerTags) {
    Write-Host "[$scriptName] runnerTags          : $runnerTags"
} else {
	$runnerTags = 'Default'
    Write-Host "[$scriptName] runnerTags          : $runnerTags (not supplied, set to default)"
}

if ($runnerExecutor) {
    Write-Host "[$scriptName] runnerExecutor      : $runnerExecutor"
} else {
	$runnerExecutor = 'shell'
    Write-Host "[$scriptName] runnerExecutor      : $runnerExecutor (not supplied, set to default)"
}

if ($runnerSAPassword) {
    Write-Host "[$scriptName] runnerSAPassword    : `$runnerSAPassword"
} else {
	if ($runnerSA) {
		$runnerSAPassword = -join ((65..90) + (97..122) + (33) + (35) + (43) + (45..46) + (58..64) | Get-Random -Count 30 | ForEach-Object {[char]$_})
	    Write-Host "[$scriptName] runnerSAPassword    : runnerSAPassword (not supplied but runnerSA set, so randomly generated)"
	} else {
	    Write-Host "[$scriptName] runnerSAPassword    : (not supplied and runnerSA not supplied, will install as inbuilt account)"
	}
}

if ($runnerName) {
    Write-Host "[$scriptName] runnerName          : $runnerName"
} else {
	$runnerName = $env:COMPUTERNAME
    Write-Host "[$scriptName] runnerName          : $runnerName (default)"
}

if ($stable) {
    Write-Host "[$scriptName] stable              : $stable"
} else {
	$stable = 'yes'
    Write-Host "[$scriptName] stable              : $stable (not supplied, set to default)"
}

if ($git) {
    Write-Host "[$scriptName] git                 : $git (Note: GitLab runner does not provide a Git binary)"
} else {
	$git = 'yes'
    Write-Host "[$scriptName] git                 : $git (not supplied, set to default)"
}

if ($docker) {
    Write-Host "[$scriptName] docker              : $docker"
} else {
	$docker = 'yes'
    Write-Host "[$scriptName] docker              : $docker (not supplied, set to default)"
}

if ($restart) {
    Write-Host "[$scriptName] restart             : $restart (only applies if docker install selected)"
} else {
	$restart = 'yes'
    Write-Host "[$scriptName] restart             : $restart (not supplied, set to default, only applies if docker install selected)"
}

Write-Host "[$scriptName] pwd                 : $(Get-Location)"
Write-Host "[$scriptName] whoami              : $(whoami)`n"

$server = Get-ScheduledTask -TaskName 'ServerManager' -erroraction 'silentlycontinue'
if ( $server ) {
	executeExpression "Get-ScheduledTask -TaskName 'ServerManager' | Disable-ScheduledTask -Verbose"
} else {
	Write-Host "[$scriptName] Scheduled task ServerManager not installed, disable not required."
}

if ( Test-Path ".\automation\CDAF.windows") {
	Write-Host "[$scriptName] Use existing Continuous Delivery Automation Framework in ./automation"
} else {
	if ( $stable -eq 'yes' ) { 
		Write-Host "[$scriptName] Download Continuous Delivery Automation Framework"
		Write-Host "[$scriptName] `$zipFile = 'WU-CDAF.zip'"
		$zipFile = 'WU-CDAF.zip'
		Write-Host "[$scriptName] `$url = `"http://cdaf.io/static/app/downloads/$zipFile`""
		$url = "http://cdaf.io/static/app/downloads/$zipFile"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
		executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
		executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
	} else {
		Write-Host "[$scriptName] Get latest CDAF from GitHub"
		Write-Host "[$scriptName] `$zipFile = 'windows-master.zip'"
		$zipFile = 'windows-master.zip'
		Write-Host "[$scriptName] `$url = `"https://codeload.github.com/cdaf/windows/zip/master`""
		$url = "https://codeload.github.com/cdaf/windows/zip/master"
		executeExpression "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls11,Tls12'"
		executeExpression "(New-Object System.Net.WebClient).DownloadFile('$url', '$PWD\$zipFile')"
		executeExpression 'Add-Type -AssemblyName System.IO.Compression.FileSystem'
		executeExpression '[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zipfile", "$PWD")'
		executeExpression 'mv windows-master\automation .'
	}
}

executeExpression 'cat .\automation\CDAF.windows'
executeExpression '.\automation\provisioning\runner.bat .\automation\remote\capabilities.ps1'

if ( $runnerSAPassword ) {
	executeExpression "./automation/provisioning/newUser.ps1 $runnerSA `$runnerSAPassword -passwordExpires 'no'"
	executeExpression "./automation/provisioning/addUserToLocalGroup.ps1 'Administrators' '$runnerSA'"
	executeExpression "./automation/provisioning/setServiceLogon.ps1 '$runnerSA'"
	executeExpression "./automation/provisioning/installRunner.ps1 '$runnerURL' `$personalAccessToken '$runnerName' '$runnerTags' '$runnerExecutor' '$runnerSA' `$runnerSAPassword"
} else {
	executeExpression "./automation/provisioning/installRunner.ps1 '$runnerURL' `$personalAccessToken '$runnerName' '$runnerTags' '$runnerExecutor'"
}

if ( $git -eq 'yes' ) { 
	executeExpression "./automation/provisioning/base.ps1 'git'"
}

if ( $docker -eq 'yes' ) { 
	executeExpression "./automation/provisioning/InstallDocker.ps1 -restart '$restart'"
}

Write-Host "`n[$scriptName] ---------- stop ----------"
