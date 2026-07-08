#Requires -Version 5.1
<#
.SYNOPSIS
    Registers the git-cleanup command on your user PATH.

.DESCRIPTION
    Adds the folder containing this installer (which also contains
    git-cleanup.cmd and git-cleanup.ps1) to the current user's PATH environment
    variable so that 'git-cleanup' can be run from any directory. The change is
    idempotent and also applied to the current session.

.PARAMETER Uninstall
    Remove this folder from the user PATH instead of adding it.

.EXAMPLE
    .\Install-GitCleanup.ps1
    Adds git-cleanup to the user PATH.

.EXAMPLE
    .\Install-GitCleanup.ps1 -Uninstall
    Removes git-cleanup from the user PATH.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$scope = 'User'

# Read the persisted user PATH (may be null if never set).
$currentPath = [Environment]::GetEnvironmentVariable('Path', $scope)
if ($null -eq $currentPath) { $currentPath = '' }

# Split into normalized entries for comparison.
$entries = $currentPath -split ';' | Where-Object { $_ -ne '' }
$alreadyPresent = $entries | Where-Object { $_.TrimEnd('\') -ieq $scriptDir.TrimEnd('\') }

if ($Uninstall) {
    if (-not $alreadyPresent) {
        Write-Host "git-cleanup is not on your user PATH; nothing to remove." -ForegroundColor Yellow
        return
    }
    $newEntries = $entries | Where-Object { $_.TrimEnd('\') -ine $scriptDir.TrimEnd('\') }
    $newPath = ($newEntries -join ';')
    [Environment]::SetEnvironmentVariable('Path', $newPath, $scope)
    $env:Path = ($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ine $scriptDir.TrimEnd('\') }) -join ';'
    Write-Host "Removed from user PATH:" -ForegroundColor Green
    Write-Host "    $scriptDir"
    Write-Host "Open a new terminal for the change to take full effect." -ForegroundColor DarkGray
    return
}

if ($alreadyPresent) {
    Write-Host "git-cleanup is already on your user PATH:" -ForegroundColor Green
    Write-Host "    $scriptDir"
}
else {
    $newPath = if ($currentPath -eq '') { $scriptDir } else { "$($currentPath.TrimEnd(';'));$scriptDir" }
    [Environment]::SetEnvironmentVariable('Path', $newPath, $scope)
    Write-Host "Added to user PATH:" -ForegroundColor Green
    Write-Host "    $scriptDir"
}

# Update the current session so it works immediately here too.
$sessionEntries = $env:Path -split ';' | Where-Object { $_ -ne '' }
if (-not ($sessionEntries | Where-Object { $_.TrimEnd('\') -ieq $scriptDir.TrimEnd('\') })) {
    $env:Path = "$($env:Path.TrimEnd(';'));$scriptDir"
}

Write-Host ""
Write-Host "Done. Open a NEW terminal, then run 'git-cleanup' from any git repository." -ForegroundColor Cyan
Write-Host "Try 'git-cleanup -DryRun' first to preview." -ForegroundColor DarkGray
