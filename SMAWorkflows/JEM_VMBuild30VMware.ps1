workflow JEM_VMBuild30VMware {

    param
    (
        [Parameter(Mandatory=$false)]
        [STRING]$VMName,
        [Parameter(Mandatory=$false)]
        [int]$Memory,
        [Parameter(Mandatory=$false)]
        [int]$CPU,
        [Parameter(Mandatory=$false)]
        [int]$DiskSize,
        [Parameter(Mandatory=$false)]
        [STRING]$IPAddress
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

    $vCenter = Get-AutomationVariable -Name 'vCenterCorpDev'
    $vCenterRunAs = GetAutomationPSCredential -Name 'vCenterRunAs'
    $vCenterRunAsUser = $vcenterRunAs.UserName
    $vcenterRunasUserPwd = $vCenterRunas.GetNetworkCredential().Password
#endregion Get custom variables

#region Main workflow
    
    Write-Verbose "Starting runbook JEM_VMBuild30VMware" -Verbose
    
    Checkpoint-Workflow

    $Output = InlineScript {
        add-pssnapin vmware.vimautomation.core
    
        Connect-VIServer -Server $USING:vCenter -User $USING:vCenterRunAsUser -Password $USING:vcenterRunasUserPwd
    
        $VM = Get-VM -Name $USING:VMName -ErrorAction SilentlyContinue

        if ($VM) {
            Write-Verbose -Message "VM $USING:VMName already exists. Skip creation."
        }
        else {
            #New-VM -Name $Using:VMName -DiskGB $USING:DiskSize -MemoryGB $USING:Memory -NumCpu $USING:CPU -VMHost $USING:vCenter 
            try {
                $DatastoreCluster = Get-DatastoreCluster -Name 'Shared-SDRS-Primus'
                New-VM -Template 'WS2012-R2-STD' -Name $Using:VMName -VMHost epresx133.alinta.net.int -ResourcePool Normal -Datastore $DatastoreCluster -Verbose
                
                Write-Verbose 'Need to create VM'
            }
            catch {
                $Output = $Error[0]
                Write-Error -Message $Output
                return $Output
            }
        }
        do {
            Write-Verbose 'Waiting for the VM to be created'
            Start-Sleep -Seconds 5
        }
        while ((Get-VM -Name $USING:VMName -ErrorAction SilentlyContinue).PowerState -ne 'PoweredOff')
        try {
            Write-Verbose "Reconfiguring the VM $USING:VMName "
            Write-Verbose "Set-VM -Name $USING:VMName -MemoryGB $USING:Memory -NumCpu $USING:CPU"
            Get-VM -Name $USING:VMName | Set-VM -Name $USING:VMName -MemoryGB $USING:Memory -NumCpu $USING:CPU -Confirm:$false
            Get-VM -Name $USING:VMName | Get-HardDisk | Set-HardDisk -CapacityGB $USING:DiskSize -Confirm:$false
            Get-VM -Name $USING:VMName | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName 'DC-DC_WinAppClusterVLAN' -StartConnected $true -Confirm:$false 
        }
        catch {
            $Output = $Error[0]
            Write-Error -Message $Output 
            return $Output           
        }
    }  

    InlineScript {
        add-pssnapin vmware.vimautomation.core
    
        Connect-VIServer -Server $USING:vCenter -User $USING:vCenterRunAsUser -Password $USING:vcenterRunasUserPwd

        $OSSpec = Get-OSCustomizationSpec -Name 'Auto_WS2012_R2_STD -10.157.14 - Alinta' | New-OSCustomizationSpec -Type NonPersistent -Name $USING:VMName
        $OSSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $USING:IPAddress -SubnetMask 255.255.255.0 -Dns 10.156.5.14 -DefaultGateway 10.157.14.10
        $VM = Get-VM -Name $USING:VMName 
        Set-VM -VM $VM -OSCustomizationSpec $OSSpec -Confirm:$false 
        Remove-OSCustomizationSpec $USING:VMName -Confirm:$false



    } -PSConfigurationName Microsoft.PowerShell32
    
    Checkpoint-Workflow

    # Start VM
    InlineScript {
        add-pssnapin vmware.vimautomation.core
    
        Connect-VIServer -Server $USING:vCenter -User $USING:vCenterRunAsUser -Password $USING:vcenterRunasUserPwd
        
        Write-Verbose "Starting $USING:VMName ..."

        Get-VM -Name $USING:VMName | Start-VM -Verbose -Confirm:$false

        do
        {
            Write-Verbose "Waiting for VM $USING:VMName to Power up."
            Start-Sleep -Seconds 5
        }
        while ($(Get-VM -Name $USING:VMName).PowerState -ne 'PoweredOn')

        do {
            Write-Verbose "Waiting for VM $USING:VMName to report back after customisation."
            Start-Sleep -Seconds 10
        }
        until ($(Get-VIEvent -Entity $USING:VMName | Where-Object -FilterScript {$PSItem.FullFormattedMessage -like "*Customization of VM $USING:VMName succeeded.*"}))
    }
    
    Write-Verbose "Because of lack of control over VMware, waiting 2.5 minutes until VM is ready..."
    Start-Sleep -Seconds 150

    #Apply customisation to OS
    JEM_VMBuild31VMwareOSConfig -VMName $VMName

    return $Output
    Write-Verbose "Completed runbook JEM_VMBuild30VMware"
#endregion Main workflow


}