###  NOTE: These scripts support running multiple initial packaging runs in parallel by using PowerShell jobs.
###        In remote packaging using the MMPT, a copy of the MMPT runs on the local computer/VM that the powershell 
###        script runs on, and for the packaging contacts it's counterpart MMPT that runs on the remote machine to perform the capture, 
###	   and the local copy MMPT then creates the package.
###	   The local machine can run multiple copies at the same time, however you can only push the number of parallel
###	   copies running at the same time locally so far, as the IO performance becomes limiting at times and the 
###	   remote communication will break down and fail.  Using Intel NUCs with SSDs and a clean network I can get
###        up to 4 remotes on a good day.
###
###        Ensuring that the snapshots on the remote packaging VMs is up to date is crucial for good packages.
###        After a snapshot is more than a week old, it probably needs to be updated, or your package will capture
###        backgroud updates by Windows and Windows components like Edge, Defender, and now AI stuff.

########################################
##### VM Environment Array $virtualMachines
#####     Specifies the virtual machines and their hypervisor host and snapshot.
#####     The parameters for each entry are:
#####         Name:        Used as both the name that the hypervisor uses for the VM AND the network name of the running OS.
#####         Credential:  Used for accessing the running VM. Leave blank here and the main script
#####		           will prompt for the credential once and set it using the utility function below
#####         host:        Name of the VM host hypervisor used to control the VM
#####         hostType:    Type of the host hypervisor:  One of { 'HyperV' }
#####         initialSnapshotName: Name of the Snapshot/Checkpoint to revert the VM to before booting and packaging.
#####         enabled:     Easy way to enable/disable entries here.  The scripts also use the utility function later in
#####		           this file to temporarily disable a VM if it fails too often.
##### NOTE: Adding in a new hypervisor type is possible, however all of the scripting dealing with the VM management (in other ps1 files)
#####       would need to be modified by you.
########################################
$virtualMachines = @(
    @{ Name = "n1WorkerA"; Credential = ''; host='nuc1'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n1WorkerB"; Credential = ''; host='nuc1'; hostType='HyperV'; initialSnapshotName='Reboot'; enabled=$false }
    @{ Name = "n1WorkerC"; Credential = ''; host='nuc1'; hostType='HyperV'; initialSnapshotName='Auto'; enabled=$false }
    @{ Name = "n2WorkerA"; Credential = ''; host='nuc2'; hostType='HyperV'; initialSnapshotName='2023.118'; enabled=$false }
    @{ Name = "n2WorkerB"; Credential = ''; host='nuc2'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n2WorkerC"; Credential = ''; host='nuc2'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n3WorkerB"; Credential = ''; host='nuc3'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n3WorkerC"; Credential = ''; host='nuc3'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n5WorkerA"; Credential = ''; host='nuc5'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n5WorkerB"; Credential = ''; host='nuc5'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n5WorkerC"; Credential = ''; host='nuc5'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n6WorkerA"; Credential = ''; host='nuc6'; hostType='HyperV'; initialSnapshotName='Ready'; enabled=$false }
    @{ Name = "n6WorkerB"; Credential = ''; host='nuc6'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n6WorkerC"; Credential = ''; host='nuc6'; hostType='HyperV'; initialSnapshotName='Snap'; enabled=$false }
    @{ Name = "n7WorkerA"; Credential = ''; host='nuc7'; hostType='HyperV'; initialSnapshotName='Updates'; enabled=$true }
    @{ Name = "n7WorkerB"; Credential = ''; host='nuc7'; hostType='HyperV'; initialSnapshotName='Updates'; enabled=$true }
    @{ Name = "n7WorkerC"; Credential = ''; host='nuc7'; hostType='HyperV'; initialSnapshotName='Updates'; enabled=$false }
    @{ Name = "n7WorkerD"; Credential = ''; host='nuc7'; hostType='HyperV'; initialSnapshotName='Updates'; enabled=$false }
)

##########################################
## Update-VMArrayWithCredentials
##    Used to add credentials for remoting access into the array of VMs that (might) be used.
##########################################
function Update-VMArrayWithCredentials($credential)
{
    ## This function is used to fill the log-in credentials into the memory array.
    foreach ($vmEntry in $virtualMachines)
    {
        $vmEntry.Credential = $credential
    }
}

##########################################
## Set-VMArrayEntryEnablement
##    Used to enable/disable a VM in the VM Array by Name in memory.
##    Member Parameters:
##        $VmName:  Name of the VM
##        $EnDisAble: $true or $false
##########################################
function Set-VMArrayEntryEnablement($VmName, $EnDisAble)
{
    foreach ($vmEntry in $virtualMachines)
    {
        if ($vmEntry.Name -eq $VmName)
        {
            $vmEntry.enabled = $EnDisAble
        }
    }
}
