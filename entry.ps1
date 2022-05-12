. $PSScriptRoot\batch_convert.ps1

## Setup:
##      You need a "controller" machine plus one or more "worker" machines that will perform capture operations, plus a hypervisor:  
##            The worker machines should be Hyper-V VMs. (you can edit batch_convert.ps1 if you need a different hypervisor but you are on your own on that).
##            If multiple workers are utilized, you will be packaging in paralell.  These workers may be present on different hypervisors.
##            These instructions assume all machines are domain joined for simplicity.  It should be possible to do with non-domain joined worker machines.
##      The MMPT on the controller simply remotes the work to the worker.  
##            It does this by copying necessary files over to a temp folder on the worker, including MMPT executables and dependencies.
##            It seems to run the copy MMPT, but still needs the driver to be installed, hence you take care of that (see instructions below) manually
##            Since you probably want Windows Update disabled on the worker (and that must be enabled to perform driver install).
##            It also appears that the package is created on the worker, so if you want to change configuration (including allowing non-store version numbers and/or changeing the default exclusion list) you'd have to do it on the worker setup, although I'm not sure the copy MMPT runs in the container to get those configurations!
##      On the Controller: 
##            Place the two files, entry.ps1 and batch_convert.ps1 in a folder.
##            enable-psremoting
##            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All  (Note: You may need to use the optional features gui to get this to work)
##            Import-Module Hyper-V
##            Install the Microsoft MSIX Packaging Tool (MMPT)
##            Start the MMPT and configure telemetry and any settings needed. (This script doesn't use the MMPT to sign the packages, it will be done by the script directly).
##      Create one or more worker VMs on Hyper-V hypervisors :
##             Install the Microsoft MSIX Packaging tool
##             enable-psremoting
##             Start the packaging tool, choose  telemetry option, then start an app and get to the point that the MMPT driver is installed, then close tool.
##             Disable Windows Updates, etc.  (NOTE: If you don't pre-load the driver you must leave Windows Update enabled).
##             Nueter Antivius like defender (turn off features and add C:\ as exclusion folder)
##             Take a snapshot/checkpoint and give it a name.  This should preferably be done with VM running, but may be while shut down.
##      On the hypervisor (Windows 10):
##             It is likely that you already have the full Hyper-V platform installed.  If not, do so, reboot, and configure: 
##                 Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All
##      On the hypervisor (Server):
##              It is likely that you already have the full Hyper-V platform installed.  If not, do so, reboot, and configure: 
##                 Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
##      On hypervisor (all):
##             --> not needed <-- Import-Module Hyper-V
##             Enable ps-remoting
##             You may need to enable WinRM, often via GPO Administrative Templates
## Testing Setup:
##     From the controller, with a worker VM running:
##             Start a PowerShell/ISE window as administrator
##             Use "get-VM -ComputerName hypervisorName -Name vmname" to ensure you can talk to the hypervisor.  
##             run "enter-PsSession -ComputerName vmname" to ensure you can run remote powershell commands to the worker.
##
## Usage:
##     Edit this script up to and including the conversionsParameters variable for your particulars.
##     Run this script (preferably from an administrative powershell/ise window).
##     When prompted, enter the username/credentials needed on the remote worker VM.
##     When packages are created, but before signing, there will be a prompt to continue.
##     When signing is completed, look in the "out" folder under the folder containing this script.  Packages and logs may be found there.

Import-Module Hyper-V

## When set to false, the out folder is emptied prior to any packaging operations.
$doNotCleanupAtStart = $false   ## $true 

## When set to true, run the MMPT to package enabled applications in the list.
$PackagePackages = $true ## $false  

## When set to true, sign packages created by the MMPT.  You might skip this if using TMEditX
$SignPackages = $false  ## $true

## When set to true, run TMEditX to update the packages.
$AutoFixPackages = $true  ## $false

## When set to true, retry any failed packaging by the MMPT.  Sometimes things go bad!
$retryBad = $true  ## $false

## When set to 0, all applications in the list are run.  If you add an app to the end of the list you can use this to skip the previous ones.
$skipFirst = 0

###################################
## Manditory fields to be edited ##
###################################

## This field must match the subject field of the code signing certificate.  It will be used as the PublisherName field of the package.
$PublisherName = "CN=CompanyName";

## This is put into the package as the publisher display name.
$PublisherDisplayName = "Packaged by Company Name";

## Path to the signtool executable.  This may be on the controller machine locally or a network share.
$signtoolPath = "\\nuc2\Installers\Cert\signtool.exe"

## Path to the code-signing certificate. This may be on the controller machine locally or a network share.
$certfile = "\\nuc2\Installers\Cert\Digicert3.pfx"

## Password for the certificate file.
$certpassword = "xxxxxxxx" 

## Timestamping service URL requested.
$timestamper = 'http://timestamp.digicert.com'


## Variable optionally used by the applications list when you provide it ps1 files.
$DefaultInstallerPath = "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe";

## Variable optionally used by the applications list.  
$InstallerArgStart = "-ExecutionPolicy Bypass -File \\nuc2\installers\Automation\Apps"

## Variable optionally used by the applications list.
$PreInstallerArgStart = "\\nuc2\installers\Automation\Apps"

## Variable optionally used by the applications list to control TMEditX operations when AutoFixMsix is enabled
$DefaultFixes = "/ApplyAllFixes /AutoSaveAsMsix"

# This line prompts for user credentials need to access the worker VMs.  It is needed before we create the worker list.
$credential = Get-Credential


# This is a list of the worker VMs.
## The Name should be both the name of the VM as well as the OS hostname.
## The host is the name of the Hyper-V host that is hosting that VM.
## The initialSnapshotName field is the snapshot to revert to for any packaging operation.
## The enabled field allows you to define a big list and just enable the ones available currently. 
$virtualMachines = @(
    @{ Name = "n1WorkerA"; Credential = $credential; host='nuc1'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n1WorkerB"; Credential = $credential; host='nuc1'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n1WorkerC"; Credential = $credential; host='nuc1'; initialSnapshotName='Auto'; enabled=$true }
    @{ Name = "n2WorkerA"; Credential = $credential; host='nuc2'; initialSnapshotName='Auto'; enabled=$true }
    @{ Name = "n2WorkerB"; Credential = $credential; host='nuc2'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n2WorkerC"; Credential = $credential; host='nuc2'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n3WorkerB"; Credential = $credential; host='nuc3'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n3WorkerC"; Credential = $credential; host='nuc3'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n5WorkerA"; Credential = $credential; host='nuc5'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n5WorkerB"; Credential = $credential; host='nuc5'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n5WorkerC"; Credential = $credential; host='nuc5'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n6WorkerA"; Credential = $credential; host='nuc6'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n6WorkerB"; Credential = $credential; host='nuc6'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n6WorkerC"; Credential = $credential; host='nuc6'; initialSnapshotName='Snap'; enabled=$false }
)

# This array has an entry for each application to be packaged.
## InstallerPath is used as the executable to run for any PreInstaller or Installer activity.
## PreInstaller, if provided, runs on the worker VM before packaging operations. Set to $nul otherwise.
## InstallerArguments and the command line arguments to be run in the packaging tool.
## PackageName through PackageVersion are fields for the package.
## Enabled may be set to false if you want to skip this item without removing it from the list.
## Started and Completed MUST be set to false; the memory copy of this array item will be altered by the script.
## Fixups provides command line arguments to control TMEditX.
$conversionsParameters = @(
    @{
        InstallerPath = $DefaultInstallerPath;
        PreInstallerArguments = $nul
        InstallerArguments = "$($InstallerArgStart)\7Zip\PassiveInstall.ps1";
        PackageName = "7Zip";
        PackageDisplayName = "7-Zip";
        PublisherName = $PublisherName;
        PublisherDisplayName = $PublisherDisplayName;
        PackageVersion = "19.0.0.0";
        Enabled = $true; 
        Started = $false;
        Completed = $false;
        Fixups = "$($DefaultFixes) /UseRegLeg"
    },
    @{
       InstallerPath = $DefaultInstallerPath;
       PreInstallerArguments = $nul
       InstallerArguments = "$($InstallerArgStart)\Ace\PassiveInstall.ps1";
       PackageName = "Ace";
       PackageDisplayName = "Ace";
       PublisherName = $PublisherName;
       PublisherDisplayName = $PublisherDisplayName;
       PackageVersion = "1.4.0.0";
       Enabled = $true; 
       Started = $false;
       Completed = $false;
       Fixups = $DefaultFixes
    }
)

$workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")
if (Test-Path  ($workingDirectory))
{
    Write-Host 'Out directory already exists.'
}
else
{
    Write-Host 'Creating out directory.'
    New-Item -Force -Type Directory ($workingDirectory)
}
        
$EnabledVMCount = 0
foreach ($vm in $virtualMachines)
{
    if ($vm.enabled -eq $true)
    {
        $EnabledVMCount += 1
    }
}

$EnabledPackageCount = 0
foreach ($conf in $conversionsParameters)
{
    if ($conf.Enabled -eq $true)
    {
        $EnabledPackageCount += 1
    }
}

if ($PackagePackages)
{
    Write-Host "Converting $($EnabledPackageCount - $skipFirst) packages using $($EnabledVMCount) VMs." -ForegroundColor Cyan
    RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines $workingDirectory -RetryBad $retryBad -DonotCleanupAtStart $doNotCleanupAtStart -SkipFirst $skipFirst
}

$countPackages = (get-item "$($workingDirectory)\MSIX\*.msix").Count
Write-Host "$($countPackages) packages created." -ForegroundColor Green

##### Uncomment out this line to pause the scripting after intial packaging has completed.
#####Read-Host -Prompt "Press Enter key to continue to package signing $($countPackages) packages."

if ($signPackages)
{
    Write-Host "Sign $($countPackages) packages..." -ForegroundColor Cyan
    if ($countPackages -gt 0)
    {
        SignPackages "$workingDirectory\MSIX" $signtoolPath $certfile $certpassword $timestamper
    }
}

if ($AutoFixPackages)
{
    Write-Host "AutoFix $($countPackages) packages..." -ForegroundColor Cyan
    AutoFixPackages $conversionsParameters "$workingDirectory\MSIX" "$workingDirectory\MSIXPsf"
}


Write-Host "Done." -ForegroundColor Green