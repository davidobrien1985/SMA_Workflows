workflow JEM_VMBuild99SCOMAgent {

    param (
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
    $SCOMAccessAccount = Get-AutomationPSCredential -Name 'SMA SCOM access account'
#endregion Get custom variables

#region Main workflow
    
    Write-Verbose 'Starting runbook JEM_VMBuild99SCOMAgent' 

    Inlinescript {
        
        Write-Verbose -Message 'Importing the SCOM PowerShell Module.'
        $null = Import-Module OperationsManager

        Write-Verbose -Message 'Get the pending SCOM Agent and approve it.'
        Get-SCOMPendingManagement -Credential $using:SCOMAccessAccount | Where-Object -FilterScript {$PSItem.AgentName -eq "$using:VMName"} | Approve-SCOMPendingManagement -ActionAccount $using:SCOMAccessAccount
    }

    Write-Verbose 'Completed runbook JEM_VMBuild99SCOMAgent'
#endregion Main workflow
}