#-----------------------------------------
#Input Area
#-----------------------------------------
Param
(
  [Parameter (Mandatory= $true)]
  [String] $DataLakeStoreName = "",

  [Parameter (Mandatory= $true)]
  [String] $SqlServer = "",

  [Parameter (Mandatory= $true)]
  [String] $accs_for_project = ""
)

$ConnectionName = "AzureRunAsConnection"
$SqlCredentialAsset = "" # cred in AA
$Database = "metadata"

$SqlCredential = Get-AutomationPSCredential -Name $SqlCredentialAsset 

Connect-AZAccount -Identity 

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
        $Cmd_access=new-object system.Data.SqlClient.SqlCommand("select * from cmpl.cmpl_dtlk_accs_lst where dtstr = '$DataLakeStoreName' and accs_for_project = '$accs_for_project'", $Conn)
        $Cmd_access.CommandTimeout=120

        # Execute the SQL command
        $Ds_access=New-Object system.Data.DataSet
        $Da_access=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd_access)
        [void]$Da_access.fill($Ds_access)

        # Output
        $GroupsWithAccess = $Ds_access.Tables.accs_for_id 
        $ADLSPathPermissions = $Ds_access.Tables.accs

        # Close the SQL connection
        $Conn.Close()
        
#-----------------------------------------
# Main
#-----------------------------------------

            ForEach ($row in $Ds_access.Tables[0])
                  {

                        Write-Host "[*] Add back .convert_access_indentifier($row.accs)  access for $row.accs_for_name on $row.dtset_path"

                        if($row.incl_child_fldrs -eq 'y')
                            {
                            Set-AZDataLakeStoreItemAclEntry `
                                            -AccountName $DataLakeStoreName `
                                            -Path $row.dtset_path `
                                            -AceType $row.ace_type `
                                            -Permissions (convert_access_indentifier($row.accs)) `
                                            -Id  $row.accs_for_id `
                                            -Concurrency 128 `
                                            -Recurse 
                            }
                        else
                            {
                            Set-AZDataLakeStoreItemAclEntry `
                                            -AccountName $DataLakeStoreName `
                                            -Path $row.dtset_path `
                                            -AceType $row.ace_type `
                                            -Permissions (convert_access_indentifier($row.accs)) `
                                            -Id  $row.accs_for_id `
                                            -Concurrency 128  
                            }
                   
                        Write-Host "[*] Add back .convert_access_indentifier($row.accs) default access for $row.accs_for_name on $row.dtset_path"


                        if($row.incl_child_fldrs -eq 'y')
                            {
                            Set-AZDataLakeStoreItemAclEntry `
                                            -AccountName $DataLakeStoreName `
                                            -Path $row.dtset_path `
                                            -AceType $row.ace_type `
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
                                            -Path $row.dtset_path `
                                            -AceType $row.ace_type `
                                            -Permissions (convert_access_indentifier($row.accs)) `
                                            -Id  $row.accs_for_id `
                                            -Concurrency 128 `
                                            -Default  
                            }
                   
                        Write-Host "[*] Finished adding .convert_access_indentifier($row.accs) default and access for $row.accs_for_name on $row.dtset_path"
                    
                }
