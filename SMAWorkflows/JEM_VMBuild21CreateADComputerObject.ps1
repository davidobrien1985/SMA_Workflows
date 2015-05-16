workflow JEM_VMBuild21CreateADComputerObject {

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

    Write-Verbose "Starting runbook JEM_VMBuild21CreateADComputerObject" 
    
    $Output = InlineScript {

        try {
            $VerbosePreference = 'SilentlyContinue'
            $null = Import-Module -Name ActiveDirectory
            $VerbosePreference = 'Continue'
        }
        catch {
            Write-Error -Message $Error[0]
        }

        #Check if AD object already exists and return to workflow
        $ErrorActionPreference = 'SilentlyContinue'
        $ADObject = Get-ADComputer -Identity $USING:VMName
        $ErrorActionPreference = 'Stop'     
        try {
            if (-not $ADObject) {
                Write-Verbose 'Computer does not exist in domain. Will create it now.'
                #create OU Path from $VMName
                if ($USING:VMName -like '*SQL*') {
                    $OUPath = 'OU=SQL,OU=Servers,OU=Resources,DC=alinta,DC=net,DC=int'
                }
                else {
                    $OUPath = 'OU=Infrastructure,OU=Servers,OU=Resources,DC=alinta,DC=net,DC=int'
                }
        
            
                $Output = New-ADComputer -Credential $USING:ADCred -Name $USING:VMName -SAMAccountName $USING:VMName -Path $OUPath -Description 'Created by SMA runbook JEM_VMBuild21CreateADComputerObject' -Verbose
                return $Output
            }
            else {
                Write-Verbose 'Computer already exists. Will skip creation.'
            }
        }
        catch {
            $Output = $Error[0]
            Write-Verbose $Output
            return $Output
        }

        Write-Verbose "Adding $using:VMName to Security Group xJen_Security_Policy_SQL_Jumphost_Servers"
        Add-ADGroupMember -Identity 'xJen_Security_Policy_SQL_Jumphost_Servers' -Members "$using:VMName$"

    } #-PSComputerName $env:COMPUTERNAME -PSCredential $ADCred

    $Output

    Write-Verbose "Completed runbook JEM_VMBuild21CreateADComputerObject"
#endregion Main workflow


}