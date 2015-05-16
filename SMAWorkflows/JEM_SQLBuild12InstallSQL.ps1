workflow JEM_SQLBuild12InstallSQL {

    param
    (
        [Parameter(Mandatory=$true)]
        [STRING]$VMName,
        [Parameter(Mandatory=$true)]
        [STRING]$SQLInstanceName,
        [Parameter(Mandatory=$true)]
        [string]$SQLCollation,
        [Parameter(Mandatory=$true)]
        [string]$SQLProjectName
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
    $SQLServiceAccount = Get-AutomationPSCredential -Name "SVC-SQL_$($VMName)_E1"
    $SQLAgentAccount = Get-AutomationPSCredential -Name "SVC-SQL_$($VMName)_A1"
#endregion Get custom variables

#region Set custom variables

$DSCConfigPath = 'C:\Windows\temp\PSDSC'

#endregion Set custom variables


#region Main workflow
    
    Write-Verbose "Starting runbook JEM_SQLBuild12InstallSQL" 

    if ($SQLInstanceName -eq $null) {
        $SQLInstanceName = $VMName
    }

    InlineScript {
        Configuration SQLServer {

            Import-DscResource -Module xSQLServer

            Node $using:VMName {


                $Features = 'SQLENGINE,FULLTEXT'

                WindowsFeature DotNetFramework35 {
                    Name = 'NET-Framework-Core'
                    Ensure = 'Present'
                    Source = '\\wprfil112\fileprd17\IS_Windows_Platforms\Projects\Documentation\Automation\Binaries\ClientSources\sxs'
                }

                WindowsFeature DotNetFramework45 {
                    Name = 'NET-Framework-45-Core'
                    Ensure = 'Present'
                    Source = '\\wprfil112\fileprd17\IS_Windows_Platforms\Projects\Documentation\Automation\Binaries\ClientSources\sxs'
                }

                File CopySQLSources {
                    SourcePath = '\\wprfil112\fileprd17\IS_Windows_Platforms\Projects\Documentation\Automation\Binaries\SQL\SQL2012_Install\SQL_2012_Enterprise_ED_Cal'
                    DestinationPath = 'C:\windows\temp\SQL\SQLServer2012.en'
                    Recurse = $true
                    Type = 'Directory'
                    Ensure = 'Present'
                }

                xSQLServerSetup Install {
                    SourcePath = 'C:\windows\temp\SQL'
                    SetupCredential = $using:LocalAdmin
                    InstanceName = $using:SQLInstanceName
                    Features = $Features
                    UpdateEnabled = 'True'
                    UpdateSource = 'C:\windows\temp\SQL\SQLServer2012.en\updates'
                    SQLSysAdminAccounts = "DLG-SQL_$($USING:SQLProjectName)-ADMIN-Prod"
                    SQLSvcAccount = $using:SQLServiceAccount
                    AgtSvcAccount = $using:SQLAgentAccount
                    SQLCollation = $using:SQLCollation
                    InstallSharedDir = ''
                    InstallSharedWOWDir = ''
                    InstanceDir = "D:\Data01\MSSQLServer\$USING:SQLInstanceName\Data"
                    InstallSQLDataDir = "D:\Data01\MSSQLServer\$USING:SQLInstanceName"
                    SQLUserDBDir = "D:\Data01\MSSQLServer\$USING:SQLInstanceName\Data"
                    SQLUserDBLogDir = "L:\Log01\MSSQLServer\$USING:SQLInstanceName\Log"
                    SQLTempDBDir = "T:\TempDB01\MSSQLServer\$USING:SQLInstanceName\TempDB"
                    SQLTempDBLogDir = "T:\TempDB01\MSSQLServer\$USING:SQLInstanceName\TempDB"
                    SQLBackupDir = "X:\SQLBackup\MSSQLServer\$USING:SQLInstanceName\Backup"
                    <#
                    ASDataDir = ''
                    ASLogDir = ''
                    ASBackupDir = ''
                    ASTempDir = ''
                    ASConfigDir = ''
                    #>
                    DependsOn = @('[WindowsFeature]DotNetFramework35','[File]CopySQLSources')
                }

                xSqlServerSetup 'SQLMT'
                    {
                        DependsOn = @('[WindowsFeature]DotNetFramework35','[File]CopySQLSources')
                        SourcePath = 'C:\windows\temp\SQL'
                        SetupCredential = $using:LocalAdmin
                        InstanceName = "NULL"
                        Features = "SSMS,ADV_SSMS"
                    }
                }

            }

        $ConfigurationData = @{
            AllNodes = @(
                @{
                    NodeName = "$using:VMName"
                    PSDscAllowPlainTextPassword = $true
                }
            )
        }

        Write-Verbose -Message 'Compiling SQL DSC file.'
        SQLServer -OutputPath "$USING:DSCConfigPath\$USING:VMName" -LocalAdmin $using:LocalAdmin -SQLInstanceName $using:SQLInstanceName -VMName $using:VMName -SQLProjectName $using:SQLProjectName -SQLCollation $using:SQLCollation -ConfigurationData $ConfigurationData
        Write-Verbose -Message 'Applying DSC config'
        Start-DscConfiguration -Wait -Verbose -Path "$USING:DSCConfigPath\$USING:VMName" -Force -Credential $USING:LocalAdmin

    # End of InlineScript
    } -PSComputerName $VMName -PSCredential $LocalAdmin

    Write-Verbose "Completed runbook JEM_SQLBuild12InstallSQL"
#endregion Main workflow


}
