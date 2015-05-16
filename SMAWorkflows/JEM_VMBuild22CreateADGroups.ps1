workflow JEM_VMBuild22CreateADGroups {

    param
    (
        [Parameter(Mandatory=$true)]
        [STRING]$VMName
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
    $ADCred = Get-AutomationPSCredential -Name 'SMA AD access account'
#endregion Get custom variables

#region Main workflow
    
    Write-Verbose "Starting runbook JEM_VMBuild22CreateADGroups" 

    $Output = Inlinescript {
        try {
            $VerbosePreference = 'SilentlyContinue'
            $null = Import-Module -Name ActiveDirectory
            $VerbosePreference = 'Continue'
        }
        catch {
            $output = $Error[0]
            Write-Verbose $output
        }
        $ErrorActionPreference = 'SilentlyContinue'
        $localadminGroup = Get-ADGroup -Identity "DLG-Server_$($USING:VMName)_localadmin"
        $RDPGroup = Get-ADGroup -Identity "DLG-Server_$($USING:VMName)_RemoteDesktop"

        $OUPath = "OU=Task Groups,OU=Delegation Groups,OU=Admin,DC=alinta,DC=net,DC=int"

        try {
            if ($localadminGroup) {
                Write-Verbose -Message 'AD DLG Group already exists. Skip creation'
            }
            else {
                New-ADGroup -Credential $USING:ADCred -Name "DLG-Server_$($USING:VMName)_localadmin" -SamAccountName "DLG-Server_$($USING:VMName)_localadmin" -GroupCategory Security -DisplayName "DLG-Server_$($USING:VMName)_localadmin" -Path $OUPath -GroupScope Global -ErrorAction Stop
            }
            if ($RDPGroup) {
                Write-Verbose -Message 'AD DLG Group already exists. Skip creation'
            }
            else {
                New-ADGroup -Credential $USING:ADCred -Name "DLG-Server_$($USING:VMName)_RemoteDesktop" -SamAccountName "DLG-Server_$($USING:VMName)_RemoteDesktop" -GroupCategory Security -DisplayName "DLG-Server_$($USING:VMName)_RemoteDesktop" -Path $OUPath -GroupScope Global -ErrorAction Stop
            }
        }
        catch {
            $output = $Error[0]
            Write-Verbose $output
        }
        
        $ErrorActionPreference = 'Stop'

    } #-PSCredential $ADCred -PSComputerName $env:COMPUTERNAME
    $Output
    Write-Verbose -Message "Completed runbook JEM_VMBuild22CreateADGroups"
#endregion Main workflow

}