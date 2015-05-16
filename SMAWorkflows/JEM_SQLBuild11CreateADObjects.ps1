workflow JEM_SQLBuild11CreateADObjects {

    param
    (
        [Parameter(Mandatory=$true)]
        [STRING]$SQLProjectName,
        [Parameter(Mandatory=$true)]
        [STRING]$VMName,
        [Parameter(Mandatory=$true)]
        [STRING]$SQLAgentPassword,
        [Parameter(Mandatory=$true)]
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
    $ADCred = Get-AutomationPSCredential -Name 'SMA AD access account'
    $LocalAdmin = Get-AutomationPSCredential -Name 'SMAUser_GlobalLocalAdmin'
#endregion Get custom variables

#region Main workflow
    
    Write-Verbose "Starting runbook JEM_SQLBuild11CreateADObjects" 

    JEM_SendEmail -EmailBody "The Password for User Account SVC-SQL_$($VMName)_E1 is $SQLServicePassword . Please add this to your Password store"
    JEM_SendEmail -EmailBody "The Password for User Account SVC-SQL_$($VMName)_A1 is $SQLAgentPassword . Please add this to your Password store"
    
    Inlinescript {
        
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
        $SQLAdminGroup = Get-ADGroup -Identity "DLG-SQL_$($USING:SQLProjectName)-ADMIN-Prod"
        $SQLROGroup = Get-ADGroup -Identity "DLG-SQL_$($USING:SQLProjectName)-RO-Prod"
        $SQLRWXGroup = Get-ADGroup -Identity "DLG-SQL_$($USING:SQLProjectName)-RWX-Prod"
        $ErrorActionPreference = 'Stop'

        $OUPath = "OU=Task Groups,OU=Delegation Groups,OU=Admin,DC=alinta,DC=net,DC=int"

        try {
            if ($SQLAdminGroup) {
                Write-Verbose -Message 'AD DLG Group already exists. Skip creation'
            }
            else {
                New-ADGroup -Credential $USING:ADCred -Name "DLG-SQL_$($USING:SQLProjectName)-ADMIN-Prod" -SamAccountName "DLG-SQL_$($USING:SQLProjectName)-ADMIN-Prod" -GroupCategory Security -DisplayName "DLG-SQL_$($USING:SQLProjectName)-ADMIN-Prod" -Path $OUPath -GroupScope Global -ErrorAction Stop
            }
            if ($SQLROGroup) {
                Write-Verbose -Message 'AD DLG Group already exists. Skip creation'
            }
            else {
                New-ADGroup -Credential $USING:ADCred -Name "DLG-SQL_$($USING:SQLProjectName)-RO-Prod" -SamAccountName "DLG-SQL_$($USING:SQLProjectName)-RO-Prod" -GroupCategory Security -DisplayName "DLG-SQL_$($USING:SQLProjectName)-RO-Prod" -Path $OUPath -GroupScope Global -ErrorAction Stop
            }
            if ($SQLRWXGroup) {
                Write-Verbose -Message 'AD DLG Group already exists. Skip creation'
            }
            else {
                New-ADGroup -Credential $USING:ADCred -Name "DLG-SQL_$($USING:SQLProjectName)-RWX-Prod" -SamAccountName "DLG-SQL_$($USING:SQLProjectName)-RWX-Prod" -GroupCategory Security -DisplayName "DLG-SQL_$($USING:SQLProjectName)-RWX-Prod" -Path $OUPath -GroupScope Global -ErrorAction Stop
            }
        }
        catch {
            $output = $Error[0]
            Write-Verbose $output
        }

       
        $OUPathSVCAccounts = "OU=Service Accounts,OU=Admin,DC=alinta,DC=net,DC=int"
        $ErrorActionPreference = 'SilentlyContinue'
        $DBEngine = Get-ADUser -Identity "SVC-SQL_$($using:VMName)_E1"
        $Service = Get-ADUser -Identity "SVC-SQL_$($using:VMName)_A1"
        $ErrorActionPreference = 'Stop'

        if ($DBEngine) {
            Write-Verbose -Message 'AD Service Account for SQL Database Engine already exists.'
        }
        else {
            New-ADUser -Credential $using:LocalAdmin -Name "SVC-SQL_$($using:VMName)_E1" -AccountPassword $(ConvertTo-SecureString -AsPlainText $using:SQLServicePassword -Force) -UserPrincipalName "SVC-SQL_$($using:VMName)_E1@alinta.net.int" -CannotChangePassword $true -DisplayName "Service Account, SVC-SQL_$($using:VMName)_E1" -Enabled $true -PasswordNeverExpires $true -Path $OUPathSVCAccounts -SamAccountName "SVC-SQL_$($using:VMName)_E1" -Description "Database Engine service account created by SMA for $using:VMName" -Verbose
        }
        if ($Service) {
            Write-Verbose -Message 'AD Service Account for SQL Agent already exists.'
        }
        else {
            New-ADUser -Credential $using:LocalAdmin -Name "SVC-SQL_$($using:VMName)_A1" -AccountPassword $(ConvertTo-SecureString -AsPlainText $using:SQLAgentPassword -Force) -UserPrincipalName "SVC-SQL_$($using:VMName)_A1@alinta.net.int" -CannotChangePassword $true -DisplayName "Service Account, SVC-SQL_$($using:VMName)_A1" -Enabled $true -PasswordNeverExpires $true -Path $OUPathSVCAccounts -SamAccountName "SVC-SQL_$($using:VMName)_A1" -Description "SQL Agent service account created by SMA for $using:VMName" -Verbose
        }

        # Create secure SMA Assets for each of the new Accounts so that these can be reused later on
        $secPasswordSQLService = ConvertTo-SecureString -AsPlainText $using:SQLServicePassword -Force
        $SQLServicecreds = New-Object System.Management.Automation.PSCredential ("alinta\SVC-SQL_$($using:VMName)_E1", $secPasswordSQLService)
        Set-SmaCredential -Name "SVC-SQL_$($using:VMName)_E1" -WebServiceEndpoint $using:WebserviceEndpoint -Value $SQLServicecreds -Credential $using:WebServiceCred -Verbose

        $secPasswordSQLAgent = ConvertTo-SecureString -AsPlainText $using:SQLAgentPassword -Force
        $SQLAgentcreds = New-Object System.Management.Automation.PSCredential ("alinta\SVC-SQL_$($using:VMName)_A1", $secPasswordSQLService)
        Set-SmaCredential -Name "SVC-SQL_$($using:VMName)_A1" -WebServiceEndpoint $using:WebserviceEndpoint -Value $SQLAgentcreds -Credential $using:WebServiceCred -Verbose

        
    } #-PSCredential $ADCred -PSComputerName $env:COMPUTERNAME

    Write-Verbose -Message "Completed runbook JEM_SQLBuild11CreateADObjects"
#endregion Main workflow

}