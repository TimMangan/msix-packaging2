# Batch Conversion scripts
A set of basic scripts that allow converting a batch of installers on a set of machines using MSIX Packaging Tool MMPT) and then optionally complete them with the Package Support Framework (PSF) using TMEditX.

## Supporting scripts
| File | Purpose |
|----|----|
| entry.ps1 | Controlling script that you run that contains the configuration to control the packaging. See below. Provides application, virtual machine, and /or remote machine information then executes scripts based on information provided. |
| batch_convert.ps1 | Dispatch work jobs to target machines. |
| sign_deploy_run.ps1 | The MSIX Packaging Tool fails to sign packages when a remote session is used. This script will be used to sign resulting packages when enabled. |
| run_job.ps1 | Worker script to attempt to control the MMPT on the remote VM. |

## Overview of operations
These scripts may be used to automate the packaging process for MSIX.  It will use a controller VM to manage the process and perform many of the steps.  It will use one or more other virtual machines to perform the package capturing portion of the process.

This architecture allows for the capture machine to be revered to clean snapshot between uses, but we also get parallel capture of multiple applications if you supply multiple VMs.  As provided, these scripts depend on using Microsoft Hyper-V as the hypervisor for controlling the VMs -- but someone smart with another hypervisor can surely modify them for that use also.

You will edit the controlling script to:
* Designate a list of hypervisor hosts, worker vms , and snapshot names.
* Designate a list of applications to be packaged, including package name, installer scripts, and other controls.
* Specify Code signing certificate.
* Define operations to be run.  These include:
* * Packaging using the Microsoft MSIX Packaging Tool.
* * Optionally signing that package.
* * Fixing the package using TMEditX.

## Requirements
You'll need at least two VMs (more if you want to work in parallel).  Experience with the Microsoft MSIX Packaging Tool has shown that it starts failing if you try to package on more than 4 VMs at a time.

The Microsoft MSIX Packaging Tool (MMPT).  This is free from the Microsoft Store.  You'll need a copy installed on the controller and on each worker VM.

A Code Siging Certificate.

Optionally, a copy of the licened product TMEditX, available from TMurgent Technologies.  TMEditX is used to:
* A analyze the package created by the MMPT
* Inject and configure the PSF into an updated package, using the analysis but possibly overridden by application specific controls in the application list.
* Save the package off in either MSIX or CIM format, including re-signing the package.


## Setup
Here is what you need for setup.  Machines may or may not be domain joined.  Additional detail is provided in the comments of the entry.ps1 file.

### Controller
These scripts would be placed in a folder on the controlling virtual machine.  

This machine must have the MSIX Packaging Tool installed and configured.

This machine must also have access to the Code Signing Certificate, and to the referenced application installers.  These may be on a remote share as long as the logged in user has access to them.  

Remote PowerShell should be enabled.

This machine is where TMEditX is also installed, if used.

### Worker VM(s)
These VMs are typical repackaging VMs.  The image should be very clean and lots of noisy things disabled.

The VM must have the MMPT installed and configured.  As you'll want windows updates disabled on the machine, you'll need to start a packaging session manually to get the MMPT driver installed (once it is installed just close the MMPT).

If other scripting technology is needed to help with the application installations, such as PassiveInstall ( https:\\gitbug.com\TimMangan\PassiveInstall ), these should also be installed.

The worker VMs also need access to the appliction share using the logged in user credentials.

A well-named snapshot should be taken.  This is traditionally taken with the OS shut down, but may be taken with the OS running and user logged in as long as that same account will be used when the remote packaging is run.  This non-traditional approach seems to help to keep Microsoft from re-enabling Windows Update better (but not perfectly) than the traditional approach.

Remote PowerShell must be enabled.

## Usage Overview
Edit the file entry.ps1 with the parameters of your virtual/remote machines and installers you would like to convert, as well as specifying the operations you want.

Run: entry.ps1 from an elevated PowerShell window.

The output will appear in a series of subfolders that are created in a folder named `out` under the folder containing these scripts.  There are separate folders for logging and packages.

## Entry.ps1 configuration
See the script as documentation on the configuration is embedded there now.

## Acknolowgements
This work was adapted from a small portion of the github project Microsoft/msix-packaging
