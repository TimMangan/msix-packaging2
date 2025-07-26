# Batch Conversion scripts

A set of basic scripts that allow converting a list of application installers into MSIX packages using the MSIX Package Tool,
using one or more remote VMs in parallel to speed up processing, and optionally running them through TMEditX to improve them.

## Supporting scripts

1. entry.ps1 - Primary script. Provides application, virtual machine, and /or remote machine information then executes scripts based on information provided.
2. VMArrray.ps1 - Creates the list of VMs to use.
3. Template\_ApplicationArray.ps1 - List of applications for packaging with parameters for how to install. \\
4. batch\_convert.ps1 - Worker functions to dispatch work to target machines
5. sign\_deploy\_run.ps1 - Worker script to sign resulting packages
6. run\_job.ps1 - Worker script for the local side of a remote packaging using the MMPT.
7. Make-NetworkConnection-Private.ps1  Useful in your setup.

## Usage

Edit the VmArrays.ps1 file for the VMs and Snapshots you will use.

Edit the Template\_Applications.ps1 file and rename to Applications.ps1 for the Applications that you will package.  You can add many, disable them in the file, or just select one from the array for a packaging run.
Edit the top of the file entry.ps1 with the specifics to control the process, and applications to be packaged.
Run: In an elevated PowerShell window, run entry.ps1

