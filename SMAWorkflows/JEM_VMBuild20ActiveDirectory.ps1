workflow JEM_VMBuild20ActiveDirectory {

    param
    (
        [Parameter(Mandatory=$false)]
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


#endregion Get custom variables

#region Main workflow
    
    Write-Verbose "Starting runbook JEM_VMBuild20ActiveDirectory" 
    Checkpoint-Workflow
    JEM_VMBuild21CreateADComputerObject -VMName $VMName
    Checkpoint-Workflow
    JEM_VMBuild22CreateADGroups -VMName $VMName
#endregion Main workflow
    
    Write-Verbose "Completed runbook JEM_VMBuild20ActiveDirectory"

}