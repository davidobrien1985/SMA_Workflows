workflow JEM_VMBuild {

    param
    (
        [Parameter(Mandatory=$true)] 
        [STRING]$VMName,
        [Parameter(Mandatory=$true)]
        [int]$MemoryinGB,
        [Parameter(Mandatory=$true)]
        [int]$CPU,
        [Parameter(Mandatory=$true)]
        [int]$DiskSizeinGB,
        [Parameter(Mandatory=$true)]
        [string]$IPAddress,
        [Parameter(Mandatory=$true)]
        [switch]$SQL,
        [Parameter(Mandatory=$false)]
        [string]$SQLInstanceName,
        [Parameter(Mandatory=$false)]
        [string]$SQLCollation,
        [Parameter(Mandatory=$false)]
        [int]$SQLDPartitionSize,
        [Parameter(Mandatory=$false)]
        [STRING]$LDEVOS,
        [Parameter(Mandatory=$false)]
        [STRING]$LDEVBackup,
        [Parameter(Mandatory=$false)]
        [STRING]$SQLProjectName,
        [Parameter(Mandatory=$false)]
        [STRING]$SQLAgentPassword,
        [Parameter(Mandatory=$false)]
        [STRING]$SQLServicePassword
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
#endregion Get custom variables

#region Main workflow
    
    Write-Verbose "Starting runbook $($Runbook.RunbookName)" 

    #region Check inputs

    $VMName = $VMName.ToUpper()

    if ($VMName -match "^[W][P,D][R,V][A-Z]{3}[1,5]{1}\d{2}$") {
        if (($VMName[-2] -eq '0') -and ($VMName[-1] -eq '0')) {
            Write-Error -Message "$VMName does not match the naming convention. It must not end on '00'. Please check and try again." -Category InvalidArgument
        } 
        else {
            Write-Verbose -Message "$VMName checked."
        }
    } 
    else {
        Write-Error -Message "$VMName does not match the naming convention. Please check and try again."
    }

    if (($IPAddress -match "^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$")) {
        Write-Verbose -Message "$IPAddress checked. Continue."
    } 
    else {
       Write-Error -Message "$IPAddress is not a valid IP Address. Please check the format and try again." -Category InvalidArgument
    }

    #endregion Check inputs
    
    #Execute AD runbooks
    JEM_VMBuild20ActiveDirectory -VMName $VMName

    #Execute VM creation runbooks
    $Result = JEM_VMBuild30VMware -VMName $VMName -Memory $MemoryinGB -CPU $CPU -DiskSize $DiskSizeinGB -IPAddress $IPAddress

    Restart-Computer -PSComputerName $VMName -PSCredential $LocalAdmin -Wait -For PowerShell -Force

    if ($SQL) {
        Write-Verbose -Message "$VMName is a SQL VM and will now be configured for SQL."
        JEM_SQLBuild10VMCustomisation -VMName $VMName -SQLDPartitionSize $SQLDPartitionSize -LDEVOS $LDEVOS -LDEVBackup $LDEVBackup
        JEM_SQLBuild11CreateADObjects -SQLProjectName $SQLProjectName -VMName $VMName -SQLAgentPassword $SQLAgentPassword -SQLServicePassword $SQLServicePassword
        JEM_SQLBuild12InstallSQL -VMName $VMName -SQLInstanceName $SQLInstanceName -SQLCollation $SQLCollation -SQLProjectName $SQLProjectName
    }

    # Notify admins of completion 
    JEM_SendEmail -EmailBody "$VMName has been successfully deployed."

    Write-Verbose "Completed runbook $($Runbook.RunbookName)"
#endregion Main workflow


}