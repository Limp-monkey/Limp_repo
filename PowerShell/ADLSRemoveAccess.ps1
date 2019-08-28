#-----------------------------------------
#Input Area
#-----------------------------------------
#-----------------------------------------
Param
(
  [Parameter (Mandatory= $true)]
  [String] $DataLakeStoreName = "jankotestadls",

  [Parameter (Mandatory= $true)]
  [String] $SqlServer = "sasweudevnapmain1sql.44379d05ea61.database.windows.net"
)
#$ErrorActionPreference = "Stop"


$ADLSPERMISSIONTYPE = 'Group'
$ADLSPATHPERMISSION = 'None' #All = Read,Write,Execute
$ConnectionName = "AzureRunAsConnection"
$SqlCredentialAsset = "sql_srv_mi_nap_tchnl_crdnt"
$Database = "metadata"

$SqlCredential = Get-AutomationPSCredential -Name $SqlCredentialAsset 

#$AutomationConnection = Get-AutomationConnection -Name $ConnectionName 
#Connect-AZAccount -ServicePrincipal -TenantId $AutomationConnection.TenantId -ApplicationId $AutomationConnection.ApplicationId -CertificateThumbprint $AutomationConnection.CertificateThumbprint 

# Connect to Azure using the Managed identities for Azure resources identity configured on the Azure VM that is hosting the hybrid runbook worker
Connect-AZAccount -Identity
 
#-----------------------------------------
#Manual login into Azure
#-----------------------------------------
#Connect-AZAccount -Subscription "SAS-UAT-Infrastructure"
#Set-AZContext -Subscription "SAS-Production-Infrastructure"

#-----------------------------------------
# SQL connection
#-----------------------------------------

$SqlUsername = $SqlCredential.UserName 
$SqlPass = $SqlCredential.GetNetworkCredential().Password 

# Define the connection to the SQL Database 

        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$SqlServer;Database=$Database;User ID=$SqlUsername;Password=$SqlPass;")

        $Conn.Open()


 # Define the SQL command to get all groups with access
        $Cmd_access=new-object system.Data.SqlClient.SqlCommand("select * from cmpl.cmpl_dtlk_accs_lst where ace_type = 'Group' and dtstr = '$DataLakeStoreName'", $Conn)
        $Cmd_access.CommandTimeout=120

        # Execute the SQL command
        $Ds_access=New-Object system.Data.DataSet
        $Da_access=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd_access)
        [void]$Da_access.fill($Ds_access)

        # Output the count
        $GroupsWithAccess = $Ds_access.Tables.accs_for_id 

 # Define the SQL command to get emergency lock folders
        $Cmd_el_list=new-object system.Data.SqlClient.SqlCommand("select * from cmpl.cmpl_emerg_lock_lst where dtstr = '$DataLakeStoreName'", $Conn)
        $Cmd_el_list.CommandTimeout=120

        # Execute the SQL command
        $Ds_el_list=New-Object system.Data.DataSet
        $Da_el_list=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd_el_list)
        [void]$Da_el_list.fill($Ds_el_list)

        # Output the count
        $EmergencyLockFolders = $Ds_el_list.Tables.dtset_path 
       
        # Close the SQL connection
        $Conn.Close()

#-----------------------------------------
# Main
#-----------------------------------------

ForEach ($Folder in $EmergencyLockFolders)
    {
            ForEach ($row in $Ds_access.Tables[0] )
                  {

                  Write-Host "[*] Removing access for $AccessFor on /$Folder"

                    if($row.dtset_path -eq $Folder)
                        {
                        Set-AZDataLakeStoreItemAclEntry `
                                    -AccountName $DataLakeStoreName `
                                    -Path /$Folder `
                                    -AceType $ADLSPermissionType `
                                    -Permissions $ADLSPATHPERMISSION `
                                    -Id  $row.accs_for_id `
                                    -Recurse `
                                    -Concurrency 128 
                        

                        Write-Host "[*] Removed access for $AccessFor on /$Folder"

                        Set-AZDataLakeStoreItemAclEntry `
                                    -AccountName $DataLakeStoreName `
                                    -Path /$Folder `
                                    -AceType $ADLSPermissionType `
                                    -Permissions $ADLSPATHPERMISSION `
                                    -Id  $row.accs_for_id `
                                    -Recurse `
                                    -Concurrency 128 `
                                    -Default  

                        Write-Host "[*] Removed default access for $AccessFor on /$Folder"
                        }
                }
    
    }




