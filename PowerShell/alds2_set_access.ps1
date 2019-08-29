[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true,Position=1)] [string] $StorageAccountName,
  [Parameter(Mandatory=$True,Position=2)] [string] $AccessKey#,
  #[Parameter(Mandatory=$True,Position=3)] [string] $PermissionString
)

# Rest documentation:
# https://docs.microsoft.com/en-us/rest/api/storageservices/datalakestoragegen2/path/update


$date = [System.DateTime]::UtcNow.ToString("R") # ex: Sun, 10 Mar 2019 11:50:10 GMT

<#####################################
                SQL 
#####################################>

$SqlUsername = ""
$SqlPass = ""
$SqlServer = ".database.windows.net"
$Database = ""


$Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$SqlServer;Database=$Database;User ID=$SqlUsername;Password=$SqlPass;")

$Conn.Open()


# Define the SQL command to run. In this case we are getting the number of rows in the table
$Cmd=new-object system.Data.SqlClient.SqlCommand("select * from cmpl_dtlk_accs_lst where dtstr='$StorageAccountName'", $Conn)
$Cmd.CommandTimeout=120

# Execute the SQL command
$Ds_access=New-Object system.Data.DataSet
$Da_access=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd)
[void]$Da_access.fill($Ds_access)

# Output the count

$datasets = ($Ds_access.Tables.dtset_path) | Sort-Object | Get-Unique

# Close the SQL connection
$Conn.Close()

 
 ForEach($dataset in $datasets)
{

   $PermissionString_access = ""
   $PermissionString_default = ""
            ForEach($access in $Ds_access.Tables[0])  
            {
                If($access.dtset_path -eq $dataset)
                {
                    $PermissionString_access += $access.ace_type + ":" + $access.accs_for_id + ":" + $access.accs + ","
                    $PermissionString_default += "default:" + $access.ace_type + ":" + $access.accs_for_id + ":" + $access.accs + ","
                }
            }


    $PermissionString = $PermissionString_access.Substring(0, $PermissionString_access.Length -1) + "," + $PermissionString_default.Substring(0, $PermissionString_default.Length -1)
      
            $n = "`n"
            $method = "PATCH"

            $stringToSign = "$method$n" #VERB
            $stringToSign += "$n" # Content-Encoding + "\n" +  
            $stringToSign += "$n" # Content-Language + "\n" +  
            $stringToSign += "$n" # Content-Length + "\n" +  
            $stringToSign += "$n" # Content-MD5 + "\n" +  
            $stringToSign += "$n" # Content-Type + "\n" +  
            $stringToSign += "$n" # Date + "\n" +  
            $stringToSign += "$n" # If-Modified-Since + "\n" +  
            $stringToSign += "$n" # If-Match + "\n" +  
            $stringToSign += "$n" # If-None-Match + "\n" +  
            $stringToSign += "$n" # If-Unmodified-Since + "\n" +  
            $stringToSign += "$n" # Range + "\n" + 
            $stringToSign +=    
                                <# SECTION: CanonicalizedHeaders + "\n" #>
                                "x-ms-acl:$PermissionString" + $n +
                                "x-ms-date:$date" + $n + 
                                "x-ms-version:2018-11-09" + $n # 
                                <# SECTION: CanonicalizedHeaders + "\n" #>

            $stringToSign +=    
                                <# SECTION: CanonicalizedResource + "\n" #>
                                "/$StorageAccountName/" + $dataset + "/" + $n + 
                                "action:setAccessControl"
                                <# SECTION: CanonicalizedResource + "\n" #>

            $sharedKey = [System.Convert]::FromBase64String($AccessKey)
            $hasher = New-Object System.Security.Cryptography.HMACSHA256
            $hasher.Key = $sharedKey

            $signedSignature = [System.Convert]::ToBase64String($hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign)))


            $authHeader = "SharedKey ${StorageAccountName}:$signedSignature"

            $headers = @{"x-ms-date"=$date} 
            $headers.Add("x-ms-version","2018-11-09")
            $headers.Add("Authorization",$authHeader)
            $headers.Add("x-ms-acl",$PermissionString)

            $URI = "https://$StorageAccountName.dfs.core.windows.net/" + $dataset + "/" + "?action=setAccessControl"

            Try {
              Invoke-RestMethod -method $method -Uri $URI -Headers $headers # returns empty response
              $true
            }
            catch {
              $ErrorMessage = $_.Exception.Message
              $StatusDescription = $_.Exception.Response.StatusDescription
              $false

              Throw $ErrorMessage + " " + $StatusDescription
            }

}