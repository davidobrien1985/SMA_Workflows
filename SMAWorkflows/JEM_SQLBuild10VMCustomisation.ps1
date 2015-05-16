workflow JEM_SQLBuild10VMCustomisation {

    param
    (
        [Parameter(Mandatory=$true)]
        [STRING]$VMName,
        [Parameter(Mandatory=$true)]
        [int]$SQLDPartitionSize,
        [Parameter(Mandatory=$true)]
        [STRING]$LDEVOS,
        [Parameter(Mandatory=$true)]
        [STRING]$LDEVBackup
    )

#region Runbook header
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'
    $WebServiceCred = Get-AutomationPSCredential -Name 'credSMAWorker'
    $WebserviceEndpoint = Get-AutomationVariable -Name 'SMAWebService'
    $SMAJobID = $PSPrivateMetadata.JobID.GUID
    $Job = Get-SMAJob -Id $SMAJobID -WebServiceEndpoint $WebserviceEndpoint -Credential $WebServiceCred
    $Runbook = Get-SMARunbook -Id $Job.RunbookId -WebserviceEndpoint $WebserviceEndpoint -Credential $WebServiceCred
#endregion Runbook header

#region Get custom variables
    $LocalAdmin = Get-AutomationPSCredential -Name 'SMAUser_GlobalLocalAdmin'
    $vCenter = Get-AutomationVariable -Name 'vCenterCorpDev'
    $vCenterRunAs = GetAutomationPSCredential -Name 'vCenterRunAs'
    $vCenterRunAsUser = $vcenterRunAs.UserName
    $vcenterRunasUserPwd = $vCenterRunas.GetNetworkCredential().Password
#endregion Get custom variables

#region Set custom variables
    
    #Set size of SQL data partitions
    $SQLLPartitionSize = $SQLDPartitionSize * 0.30
    $SQLTPartitionSize = $SQLDPartitionSize * 0.30
    $SQLXPartitionSize = $SQLDPartitionSize * 1.20


#endregion Set custom variables


#region Main workflow
    
    Write-Verbose "Starting runbook JEM_SQLBuild10VMCustomisation" 

    InlineScript {

        $VMName = $using:VMName
        $LDEVOS = $using:LDEVOS
        $LDEVBackup = $using:LDEVBackup
        $SQLDPartitionSize = $using:SQLDPartitionSize
        $SQLLPartitionSize = $using:SQLLPartitionSize
        $SQLTPartitionSize = $using:SQLTPartitionSize
        $SQLXPartitionSize = $using:SQLXPartitionSize

        add-pssnapin vmware.vimautomation.core
    
        Connect-VIServer -Server $USING:vCenter -User $USING:vCenterRunAsUser -Password $USING:vcenterRunasUserPwd

        # Get the VMware VM object
        $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue     

        # Create Datastore on VMware
        $null = New-Datastore -VMHost $VM.Host -Name "$($VMName)_OS_$($LDEVOS.Insert(2,'_'))" -Vmfs -Path "naa.60060e801602cb00000102cb0000$LDEVOS" -Verbose
        $OSDatastore = Get-Datastore -Name "$($VMName)_OS_$($LDEVOS.Insert(2,'_'))"
        $null = New-Datastore -VMHost $VM.Host -Name "$($VMName)_Backup_$($LDEVBackup.Insert(2,'_'))" -Vmfs -Path "naa.60060e801602cb00000102cb0000$LDEVBackup" -Verbose
        $BUDataStore = Get-Datastore -Name "$($VMName)_Backup_$($LDEVBackup.Insert(2,'_'))"

        Start-Sleep -Seconds 20

        # Create the 4 disks on VMware and attach to the VM
        # Create HardDisk for Partition D:
        $DDisk = New-HardDisk -VM $VM -CapacityGB $SQLDPartitionSize -Datastore $OSDatastore.Name -StorageFormat Thick -Controller 'SCSI Controller 0' -Verbose
        # Create HardDisk for Partition L
        $LDisk = New-HardDisk -VM $VM -CapacityGB $SQLLPartitionSize -Datastore $OSDatastore.Name -StorageFormat Thick -Controller 'SCSI Controller 0' -Verbose
        # Create HardDisk for Partition T:
        $TDisk = New-HardDisk -VM $VM -CapacityGB $SQLTPartitionSize -Datastore $OSDatastore.Name -StorageFormat Thick -Controller 'SCSI Controller 0' -Verbose
        # Create HardDisk for Partition X:
        $XDisk = New-HardDisk -VM $VM -CapacityGB $SQLXPartitionSize -Datastore $BUDataStore.Name -StorageFormat Thick -Controller 'SCSI Controller 0' -Verbose

        # Create SQL DSC document to install SQL per variables, add AD Delegation groups to local groups
        # Is Default Instance or Named Instance?


        # Configure SQL post config tasks / jobs /  scripts
        # Configure SQL Server memory depending on VM hardware
    

        # register SQL SPN in AD

    }

    Inlinescript {
        
        $DVD = Get-WmiObject -Class win32_volume -Filter 'DriveType=5'  
        try {
            Set-WmiInstance -Arguments @{DriveLetter='Z:'} -InputObject $DVD 
        }
        catch {

        }
                
        #Get all disks that are offline
        $Disks = Get-Disk | Where-Object -FilterScript {$PSItem.OperationalStatus -eq 'Offline'}
        foreach ($Disk in $Disks) {
            
            $Partition = $null

            Initialize-Disk -Number $Disk.Number -PartitionStyle MBR
            Set-Disk -Number $Disk.Number -IsOffline $false

            $size = $Disk.Size / 1GB

            if ((-not (Get-Partition -DriveLetter D -ErrorAction SilentlyContinue )) -and ($size -eq $using:SQLDPartitionSize)) {
                $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -DriveLetter D 
            }
            elseif ((-not (Get-Partition -DriveLetter L -ErrorAction SilentlyContinue )) -and ($size -eq $using:SQLLPartitionSize)) {
                $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -DriveLetter L 
            }
            elseif ((-not (Get-Partition -DriveLetter T -ErrorAction SilentlyContinue )) -and ($size -eq $using:SQLTPartitionSize)) {
                $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -DriveLetter T 
            }
            elseif ((-not (Get-Partition -DriveLetter X -ErrorAction SilentlyContinue )) -and ($size -eq $using:SQLXPartitionSize)) {
                $Partition = New-Partition -DiskNumber $Disk.Number -UseMaximumSize -DriveLetter X 
            }

            $null = Format-Volume -AllocationUnitSize 65536 -Partition $Partition -FileSystem NTFS -Force -Confirm:$false
            
        }

    } -PSComputerName $VMName -PSCredential $LocalAdmin


    Write-Verbose "Completed runbook JEM_SQLBuild10VMCustomisation"
#endregion Main workflow


}