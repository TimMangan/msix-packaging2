param($jobId, $host, $vmName, $vmsCount, $machinePassword, $templateFilePath, $initialSnapshotName)

write-host "JOB: $jobId"
try
{
    if ($vmName -and (Get-VMSnapshot -Name $initialSnapshotName -VMName $vmName -ComputerName $host -ErrorAction SilentlyContinue))
    {
        Write-Host "Reverting VM snapshot for $($host) / $($vmName): $initialSnapshotName"
        Restore-VMCheckpoint -ComputerName $host -Name $vmName -SnapshotName "$initialSnapshotName" -Confirm:$false
        if ( (get-vm -ComputerName $host -Name $vmName).state == 'Off' )
        {
            Write-Host "Starting VM"
            Start-VM -ComputerName $host -Name $vmName 
            $limit = 60
            while ((get-vm -ComputerName $host -Name $vmName).state != 'Running')
            {
                Start-Sleep 5
                $limit -= 1
                if ($limit == 0)
                {
                    Write-host "Job: $jobid timeout while starting restored checkpoint."
                    return
                }
            }
        }
    }

    MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword

    if ($vmName)
    {
        #Checkpoint-VM -Name $vmName -SnapshotName "AfterMsixConversion_Job$jobId"
        #Write-Host "Creating VM snapshot for $($vmName): AfterMsixConversion_Job$jobId"
        #Restore-VMSnapshot -Name "$initialSnapshotName" -VMName $vmName -Confirm:$false
        #Write-Host "Restoring VM snapshot for $($vmName): $initialSnapshotName"
    }
}
finally
{
    # if this is a VM that can be re-used, release the global semaphore after creating a semaphore handle for this process scope
    if ($vmName)
    {
        $semaphore = New-Object -TypeName System.Threading.Semaphore -ArgumentList @($vmsCount, $vmsCount, "Global\MPTBatchConversion")
        $semaphore.Release()
        $semaphore.Dispose()
    }

    #Read-Host -Prompt 'Press any key to exit this window '
    Write-Host "JOB: $($jobId) Complete."
}