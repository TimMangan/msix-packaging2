

. $PSScriptRoot\VmArray.ps1
. $PSScriptRoot\ApplicationArray.ps1
. $PSScriptRoot\batch_convert.ps1

## Purpose:
##   This is a branch copy from the Microsoft MSIX-Toolkit that has been edited to provide more features 
##      than what was written by Microsoft.
##   The specifics include:
##      Reliability: 
##          Things go wrong in a remote capture in the real world. Sometimes we want the tool to detect the failure and retry it.
##          Also track the number of errors/VM and take it out of rotation (unless it is the last one).
##      List Maintenance: 
##           It is easier to have the script include a large array of VMs and Apps, and to enable/disable as needed.
##           Added the ability to ask for packaging of just the last few apps in the list.
##           Added the ability to ask for just one app from the list by name.
##      Packaging Control:
##           Added suport for a pre-installer command and arguments available on a per-app basis.  
##           This may be needed on some apps to lay down an external dependency on the packaging VM before packaging.
##           Made it easier to use powershell wrappers for the pre and regular install of the app.
##           Added support to detect and use PowerShell 7/6/5 when app script is powershell. 
##             NOTE: The detected version must exist both on this controller and on target packaging VMs.
##      Package Signing:
##           Added option to sign the MSIX packages, workflow of remote packaging skips this in the MMPT for some reason.
##      Package Fixing:
##           Add option to automatic package fixing by TMEditX cli


## Setup:
##      You need a "controller" machine plus one or more "worker" machines that will perform capture operations, plus a hypervisor:  
##            The worker machines should be Hyper-V VMs. (you can edit batch_convert.ps1 if you need a different hypervisor but you are on your own on that).
##            If multiple workers are utilized, you will be packaging in paralell.  These workers may be present on different hypervisors.
##            These instructions assume all machines are domain joined for simplicity.  It should be possible to do with non-domain joined worker machines.
##      The MMPT on the controller simply remotes the work to the worker.  
##            It does this by copying necessary files over to a temp folder on the worker, including MMPT executables and dependencies.
##            It seems to run the copy MMPT, but still needs the driver to be installed, hence you take care of that (see instructions below) manually
##            Since you probably want Windows Update disabled on the worker (and that must be enabled to perform driver install).
##            It also appears that as the package is created by both the worker and machine you are running this script on,
##              you should keep the configuration (including allowing non-store version numbers and/or changing the default 
##              exclusion list) on both MMPTs idential.
##      On the Controller: 
##            Place the ps1 files in a folder: 
##                  entry.ps1, VMArray.ps1, ApplicationArray.ps1, batch_convert.ps1, run_job.ps1, sign_deploy.ps1
##            Ensure your network is set to private.  Use Make-NetworkConnection-Private.ps1 if needed.
##            Ensure network interfaces are private and enabe PSremoting (WsMan) and Firewall rules
##                  Get-NetConnectionProfile | Set-NetConnectionProfile -Network Private
##                  Enable-PsRemoting
##            Ensure Hyper-V Tools (only) are in this VM (Note: You may need to use the optional features gui to get this to work)
##                  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All  
##            Install the Microsoft MSIX Packaging Tool No need to configure package signing as that doesn't work from CLI
##            Start the MMPT and configure telemetry and any other settings needed. (This script doesn't use the MMPT to 
##              sign the packages, it will be done by the script directly).
##      Create one or more worker VMs on Hyper-V hypervisors :
##             Install the Microsoft MSIX Packaging tool.  Start a packaging to get the driver installed before you 
##               disable windows update.
##             Ensure network interfaces are private and enabe PSremoting (WsMan) and Firewall rules
##                  Get-NetConnectionProfile | Set-NetConnectionProfile -Network Private
##                  Enable-PsRemoting
##             Disable Windows Updates, etc.  (NOTE: If you don't pre-load the driver you must leave Windows Update enabled).
##             Nueter Antivius like defender (turn off features and add C:\ as exclusion folder)
##             Take a snapshot/checkpoint and give it a name.  This should preferably be done with VM running, but may 
##               be while shut down.
##             Edit the VMArray.ps1 file and add your VMs that you will package on.
##      On the hypervisor (Windows 10):
##             It is likely that you already have the full Hyper-V platform installed.  If not, do so, reboot, and configure: 
##                 Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Tools-All
##      On the hypervisor (Server):
##              It is likely that you already have the full Hyper-V platform installed.  If not, do so, reboot, and configure: 
##                 Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
##      On hypervisor (all):
##             --> not needed <-- Import-Module Hyper-V
##             Ensure network interfaces are private and enabe PSremoting (WsMan) and Firewall rules
##                  Get-NetConnectionProfile | Set-NetConnectionProfile -Network Private
##                  Enable-PsRemoting
##             You may need to enable WinRM, often via GPO Administrative Templates
##      Edit the ApplicationArray.ps1 file with details for your appliations.
##      Edit the items near the top of this file, under 'Feature Control' and 'Configuration Control' 
## Testing Setup:
##     From the controller, with a worker VM running:
##             Start a PowerShell/ISE window as an administrator
##             Use "get-VM -ComputerName hypervisorName -Name vmname" to ensure you can talk to the hypervisor.  
##             run "enter-PsSession -ComputerName vmname" to ensure you can run remote powershell commands to the worker(s).
##
## TMEditX: This is an optional separate (licensed) program with command line interface to update the package with 
##   PSF and other analyzed fixes.  There are many opt-in and opt-out controls available.
## Current command line options to control behavior include:
##         /RunUiMinimized                             ## Start the UI minimized to the taskbar.  Used for automation.
##         /ApplyAllFixes                              ## Perform Pre-Psf, Psf, and Recommended fixes (possibly as affected by other parameters)
##         /ApplyCleanupFixes                          ## Perform Pre-Psf Cleanup Fixes
##         /AutoSkipPsf                                ## Do not apply PSF, even if analysis suggests it
##         /SkipConsoleApps                            ## When applying the PSF, set this option that affects PsfRuntime to not add the PSF to any console application.
##         /SkipDynDll                                 ## When applying the PSF, don't add DynamicLibraryFixup, even if analysis suggeste it.
##         /SkipEnvVar                                 ## When applying the PSF, don't add EnvVarFixup, even if analysis suggeste it.
##         /SkipFrf                                    ## When applying the PSF, don't add either file based fixup (FileRedirectionFixup or MfrFixup), even if analysis suggeste it.
##         /SkipRegLeg                                 ## When applying the PSF, don't add RegLegacyFixup, even if analysis suggeste it.
##         /UseDebugPsf                                ## When applying the PSF, use the debug version.
##         /UseLauncher                                ## Force use of Psflauncher, even if analysis doesn't suggest it.
##         /UseDynDll                                  ## Force use of DynamicLibraryFixup ( and Psflauncher), even if analysis doesn't suggest it.
##         /UseFrf                                     ## Force use of a file based fixup ( and Psflauncher), even if analysis doesn't suggest it.
##         /UseRegLeg                                  ## Force use of RegLegacyFixup ( and Psflauncher), even if analysis doesn't suggest it      
##         /UseWaitForDebugger                         ## Force use of WaitForDebuggerFixup ( and Psflauncher).
##         /AutoReplaceFrfWithMfr                      ## If a file based fixup is required, use MfrFixup instead of FileRedirectionFixup.  This is now obsolete as it is the default.
##         /AutoAddILV                                 ## Make InstalledLocationVirtualization a recommended fixup instead of available.
##         /AutoSkipILV                                ## Prevent InstalledLocationVirtualization from being added, including making MfrFixup not be in IlvAware mode.
##         /AutoCopyDlls_System32                      ## Copy all dlls in the package into the VFS\SystemX86 and VFS\SystemX64 folders  (preferred over the next item)
##         /AutoCopyDlls_PkgRoot                       ## Copy all dlls in the package into the root folder of the package. (Doesn't work if a x86 and x64 dll have the same name).
##         /SkipAddVCRuntimesForPsf                    ## When adding the PSF, don't add PSF VCRuntime dependency files. (They get removed anyway if /AutoFixVcRuntimes is also set).
##          formerly /ReplaceVCRuntimeWithDependency   ## alias for next item.
##	       /AutoFixVcRuntimes                          ## Remove certain VC Runtimes from the package.
##         /AddCapabilityAllowElevation                ## Make this fixup recommended instead of available.
##         /AutoAddCapabilityInternetClient            ## Make this fixup recommended instead of available.
##         /AutoAddCapabilityInternetClientServer      ## Make this fixup recommended instead of available.
##         /AutoAddFileSystemWriteVirtualization       ## Make this fixup recommended instead of available
##         /AutoAddRegistryWriteVirtualization         ## Make this fixup recommended instead of available
##         /AutoAddCandidateExesForApplicationAlias    ## Make this fixup recommended instead of available.
##         /AutoFixControlPanelApplets                 ## Make this fixup recommended instead of available.  NOTE: Overrides cofiguration setting for this when applied.
##         /AutoFixRunKeys                             ## Make this fixup recommended instead of available.
##         /AutoFixStartMenuFolders                    ## Make this fixup recommended instead of available.  NOTE: Overrides cofiguration setting for this when applied.
##
##
##         /AutoSaveAsMsix
##         /AutoSaveAsFolder  folderpath               ## Must be followed by the folder to save the package to
##         /AutoSkipPackageSigning                     ## Override the signing settings of the configuration, if present.
##     Seperate from editing, use these to convert msix packages to AppAttach formats (only one type per command)
##         /AutoConvertToVHD
##         /AutoConvertToVHDX
##         /AutoConvertToCim
##         /AUTOCONVERTSAVEFILEPATH  filepath         ## path to the file.  In the case of CIM conversion, this will be the folder name to be created, and should still end in .CIM
##     See product documentation for details.
##     These options will be used in the app records to override application specific "configurationParameters" as needed.
##
## Usage:
##     Edit this script up to and including the AppConversionParameters variable for your particulars.
##     Edit VmArray.ps1 to establish the VMs to be used.  You can package on multiple machines in parallel, 
##       but CPU/Memory resources on the Controller VM will limit how far you can push it.  Start small.
##     Run this script (preferably from an administrative powershell/ise window).
##     When prompted, enter the username/credentials needed on the remote worker VM.
##     When signing is completed, look in the "out" folder under the folder containing this script.  Packages and logs may be found there.  If fixing with TMEdit is enabled, there are two folders, one with the original MSIX captures and another with the fixed-up packages.
##     Also there is a folder there with log files for each packaging attempt, and another with the "template" file created for each app job.
##     In case of packaging failure, the worker VM will have a snapshot with the name of the app and timestamp so that you can troubleshoot. 

Import-Module Hyper-V

#########################################
#### FEATURE CONTROL  (and default value commented out)
####    This section provides overall control of the batch run feautures that you want to set
####    The default value commented out at the end of a line provides for a complete run.

$CleanupOutputFolderAtStart = $false    #$true
## Boolean, when set to $true the output folder is cleared before stating a run.

$PackageAllPackages         = $false     #$true
## Boolean, when set to $true, a run will package the apps using the MMPT, subhect to override by $skpFrrst,  
## PackageMissingPackagesm and $doOnlyThisPackageName settings.

$PackageMissingPackages     = $false    #$true
## Boolean, when set to $true, only run the MMPT pass for all enabled packages missing a file in the output folder.

$skipFirst                  = 0         
## Number, Normally set to zero; set to a number to skip the first X apps in the array, useful if you add a few to the end of the list and just want to package it or if you need to stop and restart the script.

$doOnlyThisPackageName      =  'XMing' ## 'TMurgent-TestAppPath1In1Out' ##         
## String, normally set to ''; Set to the PackageName of a single app Name to run just that app, ignoring all App Array enabled/disabled settings.

$retryBad                   = $false    
## Boolean, when set to $true, run a secondary MMPT pass for all enabled packages still missing a file in the output after primary pass.

$SignPackages               = $false     #$true
## Boolean, when set to $true, run a Signing pass on all packages produced by the MMPT.  If all packages will pass through TMEditX
## this might not be needed.

$AutoFixPackages            = $true     #$true
## Boolean, when set to $true, run a fixing pass using TMEditX on all packages produced by the MMPT folder.

# After packaging conversions to MSIX App Attach Formats
$AutoConvertPackagesVHD     = $false
$AutoConvertPackagesVHDX    = $false
$AutoConvertPackagesCIM     = $false

##### FEATURE CONTROL
########################################

########################################
##### Configuration Control
#####   These items are specific to your setup.  The assumption is that you will use a code signing certificate
#####   in a pfx file.
$PublisherName = "CN=TMurgent.local"
## String, this will be used as the Publisher field of the AppXManifest file of the package, and must match the
## Subject field of the certificate.

$PublisherDisplayName = "Packaged by TMurgent Technologies, LLP"
## String, Display string for the AppXManifest.

$signtoolPath = "\\nuc2\Installers\Tim\Cert\signtool.exe"
$certfile = "\\nuc1\installers\MSIX_Sequencing_Labs\_MSIX_Packaging_Signing\TMurgent.local.pfx"
$certpassword = "******" 
$timestamper = 'http://timestamp.acs.microsoft.com'

$DefaultInstallerPath = Find-BestPowerShellExe

## These are the base folders that application assets will be found under.  Entries in the ApplicationArray are relative to these folders.
$PreInstallerArgStart = "-ExecutionPolicy Bypass -File \\nuc2\installers\Automation\Apps"
$InstallerArgStart = "-ExecutionPolicy Bypass -File \\nuc2\installers\Automation\Apps"
## These are used when running command remotely on the worker VM using remote powershell.
## Depending on your environment, the executionPolicy bypass may or may not be needed.

$DefaultFixes = "/ApplyAllFixes /UseDebugPsf "
## String, Used in the TMEditX command line arguments for most applications in the list.
## Another possible example is: $DefaultFixes = "/ApplyAllFixes /AutoFixVcRuntimes "


$SaveAsFolder = "\\nuc7\Packages\TMEditX.6.0.43.0"
## String, The MMPT packages will be saved in a folder relative to this script folder, called Out\MMPT, but this folder
## is used for storing the output of the TMEditX fixed packages when enabled.

$SaveAs = "/AutoSaveAsMsix /AutoSaveAsFolder $($SaveAsFolder)"
## String, used as part of the command line arguments for TMEditX.  Normally not changed.
##### CONFIGURATION Control
########################################



########################################
##### Apps
#####    Paramaters:
#####        InstallerPath:         Path for the command to run to perform app pre-install and app install, i.e. PowerShell.exe
#####        PreInstallerArguments: Arguments to the command for preinstallation, or $nul to skip preinstallation script
#####        InstallerArguments:    Arguments for the command for installation
#####        PackageName:           Name of the package. Output file will be "$($PackageName).zip"
#####        PackageDisplayName:    For the manifest.
#####        PublisherName:         For the manifest.
#####        PackageVersion:        For the manifest.
#####        Enabled:               Set to false to always skip the entry without removing it.
#####        Started:               Set to false here, changed in memory during processing.
#####        Completed:             Set to false here, changed in memory during processing.
#####        Fixups:                Arguments to TMEditX (output filename will be added to the end of the arguments automatically)
#####                               Normally just $DefaultFixes and $SaveAs, but can be different for some apps.


##### Apps
########################################

########################################
########################################
########################################
### You should not need to modify below this line
########################################
########################################
########################################

cls

if ($doOnlyThisPackageName -ne '')
{
    ## Acts as a quick in-memory configuration override to process just one package by name
    Write-host "Override to work on just one package: $($doOnlyThisPackageName)"
    foreach ($conf in $AppConversionParameters)
    {
        if ($conf.PackageName -eq $doOnlyThisPackageName)
        {
            $conf.Enabled = $true
        }
        else
        {
            $conf.Enabled = $false
        }
    }
}

$EnabledPackageCount = 0
$EntriesCount = 0
foreach ($conf in $AppConversionParameters)
{
    $EntriesCount += 1
    if ($conf.Enabled -eq $true)
    {
        $EnabledPackageCount += 1
    }
    $conf.Started = $false
    $conf.Completed = $false;
}


Write-host "$($EnabledPackageCount) packages of $($EntriesCount) entries now enabled for processing."

### Prompt for credentials to work with hypervisor and VM
$credential = $null 
if ($PackageAllPackages -or $PackageMissingPackages -or $retryBad)
{
    $credential = Get-Credential

    ## Update the in-memory copy of the VM array to include this credential
    Update-VMArrayWithCredentials $credential
}


$EnabledVMCount = 0
foreach ($vm in $virtualMachines)
{
    if ($vm.enabled -eq $true)
    {
        $EnabledVMCount += 1
    }
}
Write-host "$($EnabledVMCount) VMs enabled in the pool."

$workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")
if (Test-Path  ($workingDirectory))
{
    Write-Host "$($workingDirectory) directory already exists."
}
else
{
    Write-Host "Creating out directory $($workingDirectory)."
    New-Item -Force -Type Directory ($workingDirectory)
}

$alreadyCreated = 0        
foreach ($conv in $AppConversionParameters)
{
    if ((Test-Path -Path "$($workingDirectory)\MSIX\$($conv.PackageName)_*.msix"))
    {
        ##$conv.Enabled =  $false
        #$conv.Started = $true
        $conf.Completed = $true
        $alreadyCreated += 1
    }
}
Write-Host "$($alreadyCreated) packages already exist and will not be recreated."


if ($PackageAllPackages)
{
    Write-Host "Converting $($EnabledPackageCount - $skipFirst) packages using $($EnabledVMCount) VMs." -ForegroundColor Cyan
    RunConversionJobs -AppConversionParameters $AppConversionParameters -virtualMachines $virtualMachines $workingDirectory -RetryBad $retryBad -CleanupOutputFolderAtStart $CleanupOutputFolderAtStart -SkipFirst $skipFirst

    ## This seems to be working a little better for retries.
    if ($PackageMissingPackages)
    {
        $allreadyCreated = 0
        foreach ($conv in $AppConversionParameters)
        {
            if ((Test-Path -Path "$($workingDirectory)\MSIX\$($conv.PackageName)_*.msix"))
            {
                ##$conv.Enabled =  $false
                #$conv.Started = $true
                $conf.Completed = $true
                $alreadyCreated += 1
            }
        }

        Write-Host "Converting up to $($EnabledPackageCount - $skipFirst) packages using $($EnabledVMCount) VMs." -ForegroundColor Cyan
        RunConversionJobs -AppConversionParameters $AppConversionParameters -virtualMachines $virtualMachines $workingDirectory -RetryBad $retryBad -CleanupOutputFolderAtStart $false -SkipFirst $skipFirst
    }
}
else
{
    if ($PackageMissingPackages)
    {
        foreach ($conv in $AppConversionParameters)
        {
            if ((Test-Path -Path "$($workingDirectory)\MSIX\$($conv.PackageName)_*.msix"))
            {
                ##$conv.Enabled =  $false
                #$conv.Started = $true
                $conv.Completed = $true
            }
        }

        Write-Host "Converting up to $($EnabledPackageCount - $skipFirst) packages using $($EnabledVMCount) VMs." -ForegroundColor Cyan
        RunConversionJobs -AppConversionParameters $AppConversionParameters -virtualMachines $virtualMachines $workingDirectory -RetryBad $retryBad -CleanupOutputFolderAtStart $false -SkipFirst $skipFirst
    }
}

$countPackages = (get-item "$($workingDirectory)\MSIX\*.msix").Count
Write-Host "$($countPackages) packages created." -ForegroundColor Green

## MMPT isn't signing packages created by template, so we need to do it ourselves
if ($signPackages)
{
    Write-Host "Sign $($countPackages) packages..." -ForegroundColor Cyan
    if ($countPackages -gt 0)
    {
        SignPackages "$workingDirectory\MSIX" $signtoolPath $certfile $certpassword $timestamper $doOnlyThisPackageName
    }
}

## Run TMEditX to fix-up packages
if ($AutoFixPackages)
{
    $sDate = Date
    Write-host "Start AutoFixing: $($sDate)"
    Write-Host "AutoFix up to $($countPackages) packages..." -ForegroundColor Cyan
    AutoFixPackages $AppConversionParameters "$workingDirectory\MSIX" "$SaveAsFolder"  
    $eDate = Date
    Write-host "End AutoFixing: $($eDate)"
    Write-host "Delta " ($eDate - $sDate).TotalMinutes
}

$EditedPackagesCount = (get-item "$($SaveAsFolder)\*.msix").Count
Write-Host "$($EditedPackagesCount) edited packages created." -ForegroundColor Green



if ($AutoConvertPackagesVHD)
{
    $sDate = Date
    Write-host "Starting Conversions to VHD $($sDate)"
    Write-Host "AutoConvert up to $($EditedPackagesCount) packages..." -ForegroundColor Cyan
    AutoConvertPackages $AppConversionParameters "$SaveAsFolder" "$SaveAsFolder\VHD" "VHD"   
    $eDate = Date
    Write-host "End AutoConvertToVHD: $($eDate)"
    Write-host "Delta " ($eDate - $sDate).TotalMinutes
}

if ($AutoConvertPackagesVHDX)
{
    $sDate = Date
    Write-host "Starting Conversions to VHDX $($sDate)"
    Write-Host "AutoConvert up to $($EditedPackagesCount) packages..." -ForegroundColor Cyan
    AutoConvertPackages $AppConversionParameters "$SaveAsFolder" "$SaveAsFolder\VHDX" "VHDX" 
    $eDate = Date
    Write-host "End AutoConvertToVHDX: $($eDate)"
    Write-host "Delta " ($eDate - $sDate).TotalMinutes
}

if ($AutoConvertPackagesCIM)
{
    $sDate = Date
    Write-host "Starting Conversions to CIM $($sDate)"
    Write-Host "AutoConvert up to $($EditedPackagesCount) packages..." -ForegroundColor Cyan
    AutoConvertPackages $AppConversionParameters "$SaveAsFolder" "$SaveAsFolder\CIM" "CIM"   
    $eDate = Date
    Write-host "End AutoConvertToCIM: $($eDate)"
    Write-host "Delta " ($eDate - $sDate).TotalMinutes
}

Write-Host "Done." -ForegroundColor Green