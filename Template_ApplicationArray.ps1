## NOTE:
## This file is a template used to define the array of applications to be packaged / fixed / converted.
## Edit this file and rename the copy as ApplicationArray.ps1

########################################
##### Apps
#####    Paramaters:
#####        InstallerPath:         Path for the command to run to perform any app pre-install and app install, i.e. PowerShell.exe
#####        PreInstallerArguments: Arguments to the command for preinstallation, or $nul to skip preinstallation script
#####
#####        InstallerArguments:    Arguments for the command for installation.  It assumes this will be a .ps1 file and we will use powershell to run this script.
#####        PackageName:           Name of the package. Output file will use the packagename as part of the filename
#####        PackageDisplayName:    For the manifest.
#####        PublisherName:         For the manifest.
#####        PackageVersion:        For the manifest.
#####        Enabled:               Set to false to always skip the entry without removing it.  This may be changed in memory to false when a specific app is requested to be handled in the main script.
#####        Started:               Set to false here, changed in memory during processing.
#####        Completed:             Set to false here, changed in memory during processing.
#####        Fixups:                Arguments to TMEditX when applying fixups. (output filename will be added to the end of the arguments automatically)
#####                               Normally just $DefaultFixes and $SaveAs, but can be different for some apps. See entry.ps1 (or TMEditX documentation) for a list of options available.
#######################################

$AppConversionParameters = @(
    @{
        InstallerPath = $DefaultInstallerPath;
        PreInstallerArguments = $nul
        InstallerArguments = "$($InstallerArgStart)\7-Zip\PassiveInstall.ps1";
        PackageName = "7Zip";
        PackageDisplayName = "7-Zip";
        PublisherName = $PublisherName;
        PublisherDisplayName = $PublisherDisplayName;
        PackageVersion = "24.8.0.0";
        Enabled = $true; 
        Started = $false;
        Completed = $false;
        Fixups = "/UseRegLeg $($DefaultFixes) $($SaveAs)"
    },
    @{
       InstallerPath = $DefaultInstallerPath;
       PreInstallerArguments = $nul
       InstallerArguments = "$($InstallerArgStart)\AdobeReaderDC\extracted\PassiveInstall.ps1";
       PackageName = "AdobeReader";
       PackageDisplayName = "Adobe Reader";
       PublisherName = $PublisherName;
       PublisherDisplayName = $PublisherDisplayName;
       PackageVersion = "22.32.282.0";
       Enabled = $true; 
       Started = $false;
       Completed = $false;
       Fixups = "$($DefaultFixes) $($SaveAs)"
    },
    @{
       InstallerPath = $DefaultInstallerPath;
       PreInstallerArguments = $nul
       InstallerArguments = "$($InstallerArgStart)\AutoDWG\DwgSeeCad\PassiveInstall.ps1";
       PackageName = "AutoDWG-DwgSeeCad";
       PackageDisplayName ="DwgSee Cad";
       PublisherName = $PublisherName;
       PublisherDisplayName = $PublisherDisplayName;
       PackageVersion = "2025.0.0.0";
       Enabled = $true; 
       Started = $false;
       Completed = $false;
       Fixups = "$($DefaultFixes) /AutoAddFileSystemWriteVirtualization  $($SaveAs)"
    },
    @{
       InstallerPath = $DefaultInstallerPath;
       PreInstallerArguments = $nul
       InstallerArguments = "$($InstallerArgStart)\ConEmuPack\PassiveInstall.ps1";
       PackageName = "ConEmu";
       PackageDisplayName = "ConEmu";
       PublisherName = $PublisherName;
       PublisherDisplayName = $PublisherDisplayName;
       PackageVersion = "23.7.24.0";
       Enabled = $true; 
       Started = $false;
       Completed = $false;
       Fixups = "$($DefaultFixes) /AddCapabilityAllowElevation $($SaveAs)"
    }
)

##### Apps
########################################
