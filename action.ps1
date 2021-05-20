#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.
      
# Verify that we're running on a properly configured neonFORGE jobrunner 
# and import the deployment and action scripts from neonCLOUD.
      
# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.
      
$ncRoot = $env:NC_ROOT
      
if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}
      
$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")
      
Push-Location $ncPowershell
. ./includes.ps1
Pop-Location
      
# Read the inputs and initialize other variables.
      
$buildBranch     = Get-ActionInput "build-branch" $true
$buildConfig     = Get-ActionInput "build-config" $false
$buildLogName    = Get-ActionInput "build-log"    $true
$buildLogPath    = [System.IO.Path]::Combine($env:GITHUB_WORKSPACE, $buildLogName)
$buildTools      = Get-ActionInputBool "build-tools"
$buildInstallers = Get-ActionInputBool "build-installers"
$buildCodeDoc    = Get-ActionInputBool "build-codedoc"
$failOnError     = Get-ActionInputBool "build-codedoc"

# Initialize the builder script options,

$configOption     = ""
$toolsOption      = ""
$installersOption = ""
$codeDocOption    = ""

if ($buildConfig -ne "release")
{
    $configOption = "-debug"
}

if ($buildTools)
{
    $toolsOption = "-tools"
}
              
if ($buildInstallers)
{
    $installersOption = "-installers"
}
              
if ($buildCodeDoc)
{
    $codeDocOption = "-codedoc"
}

# Perform the operation in a try/catch.

try
{
    # Fetch the current local repo branch and commit via: git

    Push-Cwd $env:NF_ROOT

        $buildBranch = $(& git branch --show-current).Trim()
        ThrowOnExitCode

        $buildCommit = $(& git rev-parse HEAD).Trim()
        ThrowOnExitCode

    Pop-Cwd

    # Set some output variables.

    Set-ActionOutput "build-branch"      $buildBranch
    Set-ActionOutput "build-config"      $buildConfig
    Set-ActionOutput "build-log"         $buildLogPath
    Set-ActionOutput "build-commit"      $buildCommit
    Set-ActionOutput "build-commit-uri" "https://github.com/$env:GITHUB_REPOSITORY/commit/$buildCommit"

    # Delete any existing build log file.
      
    if ([System.IO.File]::Exists($buildLogPath))
    {
        [System.IO.File]::Delete($buildLogPath)
    }
      
    $repoPath    = "github.com/nforgeio/neonKUBE"
    $buildScript = [System.IO.Path]::Combine($env:NF_TOOLBIN, "neon-builder.ps1")

    # Perform the build.

    pwsh $buildScript $configOption $toolsOption $installersOption $codeDocOption 2>&1 > $buildLogPath
    ThrowOnExitCode
}
catch
{
    Write-ActionError "****************************************************************"
    Write-ActionError "* BUILD FAILED!                                                *"
    Write-ActionError "*                                                              *"
    Write-ActionError "* Check the captured log in the next step for more information *"
    Write-ActionError "****************************************************************"
    Write-ActionException $_

    Set-ActionOutput "success" "false"

    if ($failOnError)
    {
        exit 1
    }

    return
}

Set-ActionOutput "success" "true"
