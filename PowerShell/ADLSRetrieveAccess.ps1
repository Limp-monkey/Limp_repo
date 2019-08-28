#-----------------------------------------
#Input Area
#-----------------------------------------
Param
(
  [Parameter (Mandatory= $true)]
  [String] $DataLakeStoreName = "jankotestadls",

  [Parameter (Mandatory= $true)]
  [String] $SqlServer = "sasweudevnapmain1sql.44379d05ea61.database.windows.net"
)

#$ErrorActionPreference = "Stop"

$ADLSPermissionType = 'Group'
$ADLSPATHPERMISSION = 'None' #All = Read,Write,Execute
$ConnectionName = "AzureRunAsConnection"
$SqlCredentialAsset = "sql_srv_mi_nap_tchnl_crdnt"
$Database = "metadata"

$SqlCredential = Get-AutomationPSCredential -Name $SqlCredentialAsset 

Connect-AZAccount -Identity

# $AutomationConnection = Get-AutomationConnection -Name $ConnectionName 
# Add-AZAccount -ServicePrincipal -TenantId $AutomationConnection.TenantId -ApplicationId $AutomationConnection.ApplicationId -CertificateThumbprint $AutomationConnection.CertificateThumbprint 


#-----------------------------------------
#Manual login into Azure
#-----------------------------------------
#Connect-AZAccount -Subscription "SAS-UAT-Infrastructure"
#Set-AZContext -Subscription "SAS-Production-Infrastructure"

#-----------------------------------------
#Functions
#-----------------------------------------

Function convert_access_indentifier
{
  Param([string]$input_access)

      if($input_access -like 'rwx')
      {'all'}
      if($input_access -like 'r-x')
      {'ReadExecute'}
      if($input_access -like '-wx')
      {'WriteExecute'}
      if($input_access -like 'r--')
      {'Read'}
      if($input_access -like 'rw-')
      {'ReadWrite'}
      if($input_access -like '-w-')
      {'Write'}
      if($input_access -like '--x')
      {'WriteExecute'}  
      if($input_access -like '---')
      {'None'}
}


#-----------------------------------------
# SQL connection
#-----------------------------------------

$SqlUsername = $SqlCredential.UserName 
$SqlPass = $SqlCredential.GetNetworkCredential().Password 

# Define the connection to the SQL Database 

        $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$SqlServer;Database=$Database;User ID=$SqlUsername;Password=$SqlPass;")

        $Conn.Open()


 # Define the SQL command to get all groups with access
        $Cmd_access=new-object system.Data.SqlClient.SqlCommand("select * from cmpl.cmpl_dtlk_accs_lst where ace_type = 'Group'  and dtstr = '$DataLakeStoreName'", $Conn)
        $Cmd_access.CommandTimeout=120

        # Execute the SQL command
        $Ds_access=New-Object system.Data.DataSet
        $Da_access=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd_access)
        [void]$Da_access.fill($Ds_access)

        # Output
        $GroupsWithAccess = $Ds_access.Tables.accs_for_id 
        $ADLSPathPermissions = $Ds_access.Tables.accs

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
            ForEach ($row in $Ds_access.Tables[0])
                  {

                    if($row.dtset_path -eq $Folder)
                        {
                        Write-Host "[*] Add back  .convert_access_indentifier($row.accs)  access for $AccessFor on /$Folder"

                        if($row.incl_child_fldrs -eq 'y')
                            {
                            Set-AZDataLakeStoreItemAclEntry `
                                            -AccountName $DataLakeStoreName `
                                            -Path /$Folder `
                                            -AceType $ADLSPermissionType `
                                            -Permissions (convert_access_indentifier($row.accs)) `
                                            -Id  $row.accs_for_id `
                                            -Concurrency 128 `
                                            -Recurse 
                            }
                        else
                            {
                            Set-AZDataLakeStoreItemAclEntry `
                                            -AccountName $DataLakeStoreName `
                                            -Path /$Folder `
                                            -AceType $ADLSPermissionType `
                                            -Permissions (convert_access_indentifier($row.accs)) `
                                            -Id  $row.accs_for_id `
                                            -Concurrency 128  
                            }
                   
                        Write-Host "[*] Add back $ADLSPathPermissions access for $AccessFor on /$Folder"


                        if($row.incl_child_fldrs -eq 'y')
                            {
                            Set-AZDataLakeStoreItemAclEntry `
                                            -AccountName $DataLakeStoreName `
                                            -Path /$Folder `
                                            -AceType $ADLSPermissionType `
                                            -Permissions (convert_access_indentifier($row.accs)) `
                                            -Id  $row.accs_for_id `
                                            -Concurrency 128 `
                                            -Default `
                                            -Recurse 
                            }
                        else
                            {
                            Set-AZDataLakeStoreItemAclEntry `
                                            -AccountName $DataLakeStoreName `
                                            -Path /$Folder `
                                            -AceType $ADLSPermissionType `
                                            -Permissions (convert_access_indentifier($row.accs)) `
                                            -Id  $row.accs_for_id `
                                            -Concurrency 128 `
                                            -Default  
                            }
                   
                        Write-Host "[*] Add back convert_access_indentifier($row.accs) default access for $AccessFor on /$Folder"
                    }
                }
    
    }
