Param
(
  [Parameter (Mandatory= $true)]
  [String] $DataLakeStoreName = "",

  [Parameter (Mandatory= $true)]
  [String] $BlobStoreToSaveCSV = ""

)###################################################### PREP #################################################################################

$credname = "" ## crediential in AA
$ConnectionName = "AzureRunAsConnection"
$BlobCredentialAsset = '' ## crediential in AA



$today = get-date -format "yyyyMMdd"
$TmpFileName = New-TemporaryFile
$WriteFileName = $datalakestorename +"_" + $today+"_audit_access_list.csv"
$current_depth = 0;
$max_depth = 4; # how deep into the data lake does the iteration go. 

$BlobCredential = Get-AutomationPSCredential -Name $BlobCredentialAsset 
$BlobKey = $BlobCredential.GetNetworkCredential().Password 

$blobcontext = New-AzureStorageContext -StorageAccountName $BlobStoreToSaveCSV -StorageAccountKey $BlobKey

$AutomationConnection = Get-AutomationConnection -Name $ConnectionName 
Add-AzureRmAccount -ServicePrincipal -TenantId $AutomationConnection.TenantId -ApplicationId $AutomationConnection.ApplicationId -CertificateThumbprint $AutomationConnection.CertificateThumbprint 

## Create a new array to store all the folders
$AllFoldersArray = New-Object System.Collections.ArrayList

#################################################################################
                            
                            #FUNCTIONS 

#################################################################################

## create a new function that will recursively generate the list of folder and subfolders.

function recurseDataLakeStoreChildItem ([System.Collections.ICollection] $AllFolders, [hashtable] $Params) {
    $ChildItems = Get-AzureRMDataLakeStoreChildItem @Params;
    $Path = $Params["Path"];
    $current_depth = $current_depth + 1;
    foreach ($ChildItem in $ChildItems) {
         if ($ChildItem.Type -like "DIRECTORY" -and $current_depth -le $max_depth ) {
                $AllFoldersArray.Add($Path +"/" + $ChildItem.Name) | Out-Null
                $Params.Remove("Path");
                $Params.Add("Path", $Path + "/" + $ChildItem.Name);
                recurseDataLakeStoreChildItem -AllFolders $AllFolders -Params $Params;
            }
        
    }

}


function check_access_for ([string]$TypeIn, [string]$objectIdIn) {

          $AccessFor = if($TypeIn -eq "Group"){
                                                Get-AzureRMADGroup  -ObjectId $objectIdIn | Select-Object DisplayName 
                                                }
                        elseif($TypeIn -eq 'User'){
                                                  $AccessFor = Get-AzureRMADServicePrincipal  -ObjectId $objectIdIn | Select-Object DisplayName
                                                   }

                        if([string]::IsNullOrEmpty($AccessFor)){
                                                                $AccessFor = Get-AzureRMADUser -ObjectId $objectIdIn | Select-Object DisplayName
                                                                }
                      
          $AccessFor
}

Function DeleteFileContent
{

    Remove-Item -Path $TmpFileName #$WriteToFile -Force
}

Function WriteToFile
{
   Param ([string]$permission_list)

   $Line = "$permission_list"

   Add-content $WriteToFile -value $Line
}

#################################################################################
                            
                            #MAIN 

#################################################################################

## log the ADLS name and depth
"Data lake: $datalakestorename" >> $TmpFileName
"checking until depth: $max_depth" >> $TmpFileName

## create the folder structure 
$AllFoldersArray.Add("/") | Out-Null #root

recurseDataLakeStoreChildItem -AllFolders $AllFolders -Params  @{ 'Path' = '/'; 'Account' = $datalakestorename }

# delete target file, if it exists
$destination_script_exists = Test-Path $TmpFileName #$WriteToFile 

if($destination_script_exists)
    {
    DeleteFileContent
    }

############## get the permissios and write them to the file

ForEach ($Folder in $AllFoldersArray) 
        {

                $AccessSingleFolder = Get-AzureRMDataLakeStoreItemAclEntry  `
                                        -AccountName $DATALAKESTORENAME `
                                        -Path $Folder

                    ForEach($PermissionList in $AccessSingleFolder | Where-Object {$_.Id -ne ""} ) 
                    {

                           $IDTranslated = check_access_for -typeIn $PermissionList.Type.ToString() -objectIdIn $PermissionList.Id

                                            [PSCustomObject]@{
                                            Datastore = $datalakestorename
                                            Folder = $Folder -replace "//", "/"
                                            Type = ($PermissionList.Type |Out-String).trim() # ace_type = user = 0 /group = 1
                                            Id = $PermissionList.Id
                                            Name = if([string]::IsNullOrEmpty($IDTranslated)){"Unknown"}else{$IDTranslated.DisplayName.ToString()} ## move this out to the check_access_for function
                                            Scope = ($PermissionList.Scope |Out-String).trim() # access = 0 default = 1
                                            Permission = $PermissionList.Permission
                                            insert_date = get-date -format "yyyy-MM-dd HH:mm:ss"
                                            } | ConvertTo-CSV -NoTypeInformation | Select-Object -Skip 1 >> $TmpFileName 
                                                  
                    }
           
              
        }

Set-AzureStorageBlobContent -Container "adls-permissions" -File $TmpFileName.FullName -Blob "$datalakestorename\$WriteFileName" -Context $blobcontext -Force
