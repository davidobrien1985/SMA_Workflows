workflow JEM_SendEmail {

    param
    (
        [Parameter(Mandatory=$true)]
        [string]$EmailBody
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
    $ExchangeCred = Get-AutomationPSCredential -Name 'SMA Exchange access account'
    $SMTPServer = Get-AutomationVariable -Name 'SMTPServer'
    $SMTPFrom = Get-AutomationVariable -Name 'SMTPFrom'
    $SMTPTo = Get-AutomationVariable -Name 'SMTPTo'
#endregion Get custom variables

#region Main workflow
    
    Write-Verbose 'Starting runbook JEM_SendEmail' 


$Subject = "JEM - SMA Notification"

Send-MailMessage -SmtpServer $SMTPserver -To $SMTPTo -From $SMTPFrom -Body $EmailBody -Subject $Subject -Priority high -Credential $ExchangeCred

Write-Verbose 'Completed runbook JEM_SendEmail' 

#endregion Main workflow
}