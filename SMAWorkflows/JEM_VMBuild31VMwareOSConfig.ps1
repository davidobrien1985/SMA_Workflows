workflow JEM_VMBuild31VMwareOSConfig {

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
    $ADCred = Get-AutomationPSCredential -Name 'SMA AD access account'
    $LocalAdmin = Get-AutomationPSCredential -Name 'SMAUser_GlobalLocalAdmin'
    #$SourcesShare = Get-AutomationVariable -Name 'SourcesShare'
#endregion Get custom variables

#region Set custom variables

$DSCConfigPath = 'C:\Windows\temp\PSDSC'

#endregion Set custom variables


#region Main workflow
    
    Write-Verbose "Starting runbook JEM_VMBuild31VMwareOSConfig" 

    # Copy DSC Resource Kit modules to VM 

    Write-Verbose -Message 'Copying DSC Resource Kit modules to VM.'
    inlinescript {
        Copy-Item -Path '\\wprfil112\fileprd17\IS_Windows_Platforms\Projects\Documentation\Automation\Binaries\SMA Worker Prerequisites\DSCKit\*' -Destination "\\$using:VMName\c$\Program Files\WindowsPowerShell\Modules" -Recurse -Force
    } -PSComputerName $env:COMPUTERNAME -PSCredential $LocalAdmin -PSAuthentication CredSSP


    #Create the Configuration block


    InlineScript {

        Configuration OSConfig {
            param (
                [Parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [String]$NodeName,
                [Parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [pscredential]$ADCred
            )
                
            Import-DscResource -ModuleName xCredSSP
           
            Node $NodeName {
                
                xCredSSP Server {
                    Ensure = "Present"
                    Role = "Server"
                }

                xCredSSP Client {
                    Ensure = "Present"
                    Role = "Client"
                    DelegateComputers = "*.alinta.net.int"
                }
                
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
                
                #Add the previously created Domain Group to the local Administrator group
                Group LocalAdmins {
                    Ensure = 'Present'
                    GroupName = 'Administrators'
                    Members = "ALINTA\DLG-Server_$($USING:VMName)_localadmin"
                    Credential = $USING:ADCred
                }
                #Add the previously created Domain Group to the local Remote Desktop Users group
                Group RemoteDesktopUsers {
                    Ensure = 'Present'
                    GroupName = 'Remote Desktop Users'
                    Members = "ALINTA\DLG-Server_$($USING:VMName)_RemoteDesktop"
                    Credential = $USING:ADCred
                }

                Package SCOMAgent {
                    Name = 'Microsoft Monitoring Agent'
                    Ensure = 'Present'
                    Path = '\\wprfil112\fileprd17\IS_Windows_Platforms\Projects\Documentation\Automation\Binaries\ClientSources\SCOM Agent 2012 R2_1.0\AMD64\MOMAgent.msi'
                    Arguments = '/norestart /qb USE_SETTINGS_FROM_AD=0 MANAGEMENT_GROUP=JEMENA MANAGEMENT_SERVER_DNS=WPROPM101.alinta.net.int ACTIONS_USE_COMPUTER_ACCOUNT=1 USE_MANUALLY_SPECIFIED_SETTINGS=1 ACCEPTENDUSERLICENSEAGREEMENT=1'
                    ProductId = '{786970C5-E6F6-4A41-B238-AE25D4B91EEA}'
                }

                Package CM12Agent {
                    Name = 'Configuration Manager Client'
                    ProductId = '{8864FB91-94EE-4F16-A144-0D82A232049D}'
                    Ensure = 'Present'
                    Path = '\\wprfil112\fileprd17\IS_Windows_Platforms\Projects\Documentation\Automation\Binaries\ClientSources\ConfigMgr2012_Client\ccmsetup.exe'
                    Arguments = 'SMSMP=WPRCFM102.ALINTA.NET.INT SMSSITECODE=CM1 SMSFSP=WPRCFM101.alinta.net.int SMSCACHESIZE=10240'
                }
                
            }
        }

        $ConfigurationData = @{
            AllNodes = @(
                @{
                    NodeName = "$USING:VMName"
                    PSDscAllowPlainTextPassword = $true
                }
            )
        }

        Write-Verbose -Message "Creating the PSDCS MOF in $USING:DSCConfigPath"
        OSConfig -OutputPath "$USING:DSCConfigPath\$USING:VMName" -NodeName $USING:VMName -ConfigurationData $ConfigurationData -ADCred $USING:ADCred

        Write-Verbose -Message 'Applying DSC Configutation.'
        Start-DscConfiguration -Path "$USING:DSCConfigPath\$USING:VMName" -Wait -Force -Verbose -Credential $USING:LocalAdmin
    
    } -PSComputerName $VMName -PSCredential $LocalAdmin

    Write-Verbose "Completed runbook JEM_VMBuild31VMwareOSConfig"
#endregion Main workflow


}