Param
(

  [Parameter (Mandatory= $true)]
  [String] $project_ad_group =  '',

  [Parameter (Mandatory= $true)]
  [String] $resource_group_name =  '',

  [Parameter (Mandatory= $true)]
  [String] $json_files_path =  '',
  
  [Parameter (Mandatory= $true)]
  [String] $key_vault_name =  '',

  [Parameter (Mandatory= $true)]
  [String] $data_factory_name =  '',

  [Parameter (Mandatory= $true)]
  [String] $adls_from_dbx_kvu =  '', ##ID

  [Parameter (Mandatory= $true)]
  [String] $adls_from_dbx_kvs =  '', ##ID
    
  [Parameter (Mandatory= $true)]
  [String] $adls_from_adf_kvu =  '',

  [Parameter (Mandatory= $true)]
  [String] $adls_from_adf_kvs =  ''

)

<#####################################
 manual connect
#####################################>

<#
 Connect-AzAccount -Subscription "SAS-UAT-Infrastructure"
 Set-AzContext -Subscription "SAS-UAT-Infrastructure"
#>


                                                            <#####################################

                                                                     Supporting parameters

                                                            #####################################>

$admin_ad_group= ''
$common_resource_group_name = ''
$tenant = ""
$subscription_id = ""

$datalake_name = ''

$linked_service_key_vault_name = "KeyVault_Connection"
$linked_service_immutable_name = "ADLS_ImmutableDS_Connection"
$linked_service_landing_name = "ADLS_LandingZone_Connection"
$linked_service_source_image_name = "ADLS_SourceImageDS_Connection"

$location = 'westeurope'

$adls_from_dbx_secret_kvu = ConvertTo-SecureString $adls_from_dbx_kvu -AsPlainText -Force
$adls_from_dbx_secret_kvs = ConvertTo-SecureString $adls_from_dbx_kvs -AsPlainText -Force
$adls_from_adf_secret_kvu = ConvertTo-SecureString $adls_from_adf_kvu -AsPlainText -Force
$adls_from_adf_secret_kvs = ConvertTo-SecureString $adls_from_adf_kvs -AsPlainText -Force


$adls_from_dbx_kvu_name = 'adls-from-dbx-kvu'
$adls_from_dbx_kvs_name = 'adls-from-dbx-kvs'

$adls_from_adf_kvu_name = 'adls-from-adf-kvu'
$adls_from_adf_kvs_name = 'adls-from-adf-kvs'


$adls_from_dbx_name = (Get-AzADServicePrincipal -ApplicationId $adls_from_dbx_kvu).DisplayName
$adls_from_adf_name = (Get-AzADServicePrincipal -ApplicationId $adls_from_adf_kvu).DisplayName

$data_factory_identity = (Get-AzDataFactoryV2 -ResourceGroupName $resource_group_name -Name $data_factory_name).Identity | Select PrincipalId
$data_factory_application_id = (Get-AzADServicePrincipal -DisplayName $data_factory_name).ApplicationId
$data_factory_object_id = (Get-AzADServicePrincipal -DisplayName $data_factory_name).Id 


$data_lake_folders = @("/", "/Landing", "/DataLake-Source-Image", "/DataLake-Immutable", "/Landing/Archive", "/Landing/Error", "/Landing/Input", "/Landing/Work")


                                                            <#####################################

                                                                            JSONs

                                                            #####################################>


Write-Host "[*] Starting building JSON files"

<#####################################
 Key Vault 
#####################################>


Write-Host "[*] Key Vault Linked Service JSON"

$linked_service_key_vault_json  = @"
{
                    "name": "$linked_service_key_vault_name",
                    "type": "Microsoft.DataFactory/factories/linkedservices",
                    "properties": {
                        "description": "$key_vault_name" ,
                        "type": "AzureKeyVault",
                        "typeProperties": {
                            "baseUrl": "https://$key_vault_name.vault.azure.net/"
                        },
                        "annotations": []
                    }
}
"@ |  Out-File -FilePath "$json_files_path\linked_service_key_vault.json"

<#####################################
 Immutable
#####################################>

Write-Host "[*] Immutable Linked Service JSON"

$linked_service_immutable_json  = @"
{
    "name": "$linked_service_immutable_name",
    "properties": {
        "type": "AzureDataLakeStore",
        "typeProperties": {
            "dataLakeStoreUri": "https://$datalake_name.azuredatalakestore.net/webhdfs/v1",
            "servicePrincipalId": "$adls_from_adf_kvu",
            "servicePrincipalKey": {
                "type": "AzureKeyVaultSecret",
                "store": {
                    "referenceName": "$linked_service_key_vault_name",
                    "type": "LinkedServiceReference"
                },
                "secretName": "$adls_from_adf_kvs_name"
            },
            "tenant": "$tenant",
            "subscriptionId": "$subscription_id",
            "resourceGroupName": "$common_resource_group_name"
        },
        "annotations": []
    },
    "type": "Microsoft.DataFactory/factories/linkedservices"
}
"@ |  Out-File -FilePath "$json_files_path\linked_service_immutable.json"



<#####################################
 Source Image
#####################################>

Write-Host "[*] Source Image Linked Service JSON"

$linked_service_source_image_json  = @"
{
    "name": "$linked_service_source_image_name",
    "properties": {
        "type": "AzureDataLakeStore",
        "typeProperties": {
            "dataLakeStoreUri": "https://$datalake_name.azuredatalakestore.net/webhdfs/v1",
            "servicePrincipalId": "$adls_from_adf_kvu",
            "servicePrincipalKey": {
                "type": "AzureKeyVaultSecret",
                "store": {
                    "referenceName": "$linked_service_key_vault_name",
                    "type": "LinkedServiceReference"
                },
                "secretName": "$adls_from_adf_kvs_name"
            },
            "tenant": "$tenant",
            "subscriptionId": "$subscription_id",
            "resourceGroupName": "$common_resource_group_name"
        },
        "annotations": []
    },
    "type": "Microsoft.DataFactory/factories/linkedservices"
}
"@ |  Out-File -FilePath "$json_files_path\linked_service_source_image.json"

<#####################################
 Landing
#####################################>

Write-Host "[*] Source Image Linked Service JSON"

$linked_service_landing_json  = @"
{
    "name": "$linked_service_landing_name",
    "properties": {
        "type": "AzureDataLakeStore",
        "typeProperties": {
            "dataLakeStoreUri": "https://$datalake_name.azuredatalakestore.net/webhdfs/v1",
            "servicePrincipalId": "$adls_from_adf_kvu",
            "servicePrincipalKey": {
                "type": "AzureKeyVaultSecret",
                "store": {
                    "referenceName": "$linked_service_key_vault_name",
                    "type": "LinkedServiceReference"
                },
                "secretName": "$adls_from_adf_kvs_name"
            },
            "tenant": "$tenant",
            "subscriptionId": "$subscription_id",
            "resourceGroupName": "$common_resource_group_name"
        },
        "annotations": []
    },
    "type": "Microsoft.DataFactory/factories/linkedservices"
}
"@ |  Out-File -FilePath "$json_files_path\linked_service_landing.json"


Write-Host "[*] Finished building JSON file"
                                                            <#####################################

                                                                        KEY VAULT

                                                            #####################################>


Write-Host "[*] Provisioning Key Vault Content"

<#####################################
 set access policy on Key Vault
#####################################>

Write-Host "[*] Setting access policy on Key Vault"

## NAP
Write-Host "[*] NAP AD Group access policy"

Set-AzKeyVaultAccessPolicy `
        -VaultName $key_vault_name `
        -ObjectId (Get-AzADGroup -SearchString $nap_ad_group).Id `
        -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge `
        -PermissionsToSecrets get,list,set,delete,backup,restore,recover,purge `
        -PermissionsToCertificates get,list,delete,create,import,update,managecontacts,getissuers,listissuers,setissuers,deleteissuers,manageissuers,recover,purge,backup,restore  `
        -PermissionsToStorage get,list,delete,set,update,regeneratekey,getsas,listsas,deletesas,setsas,recover,backup,restore,purge `
        -PassThru

## Project AD group
Write-Host "[*] Project AD Group access policy"

Set-AzKeyVaultAccessPolicy `
        -VaultName $key_vault_name `
        -ObjectId (Get-AzADGroup -SearchString $project_ad_group).Id `
        -PermissionsToKeys create,import,delete,list `
        -PermissionsToSecrets get,list,set,delete `
        -PermissionsToCertificates get,list,delete,create,import,update  `
        -PermissionsToStorage get,list,delete,set,update `
        -PassThru

## ADF
Write-Host "[*] Azure Data Factory access policy"

Set-AzKeyVaultAccessPolicy `
        -VaultName $key_vault_name `
        -ObjectId $data_factory_object_id `
        -PermissionsToKeys create,import,delete,list `
        -PermissionsToSecrets get,list,set,delete `
        -PermissionsToCertificates get,list,delete,create,import,update  `
        -PermissionsToStorage get,list,delete,set,update `
        -PassThru

Write-Host "[*] Finished setting access policy on Key Vault"


<#####################################
 create service principal secrets in KV
#####################################>

Write-Host "[*] Creating secrets in Key Vault"

Set-AzKeyVaultSecret `
            -VaultName $key_vault_name `
            -Name $adls_from_dbx_kvu_name `
            -SecretValue $adls_from_dbx_secret_kvu `
            -ContentType "service principal app ID for user $adls_from_dbx_name"

Set-AzKeyVaultSecret `
            -VaultName $key_vault_name `
            -Name $adls_from_dbx_kvs_name `
            -SecretValue $adls_from_dbx_secret_kvs `
            -ContentType "Service principal secret for user $adls_from_dbx_name"

Set-AzKeyVaultSecret `
            -VaultName $key_vault_name `
            -Name $adls_from_adf_kvu_name `
            -SecretValue $adls_from_adf_secret_kvu `
            -ContentType "service principal app ID for user $adls_from_adf_name"
Set-AzKeyVaultSecret `
            -VaultName $key_vault_name `
            -Name $adls_from_adf_kvs_name `
            -SecretValue $adls_from_adf_secret_kvs `
            -ContentType "Service principal secret for user $adls_from_adf_name"

Write-Host "[*] Finished creating secrets in Key Vault"

                                                            <#####################################

                                                                      AZURE DATA LAKE STORE

                                                            #####################################>


Write-Host "[*] Adding ReadExecute Azure Data Lake Store access to $adls_from_dbx_name on top levels:"

ForEach ($data_lake_folder in $data_lake_folders)
    {

        Write-Host "[*] $data_lake_folder"

        Set-AZDataLakeStoreItemAclEntry `
                        -AccountName $datalake_name `
                        -Path $data_lake_folder `
                        -AceType 'User' `
                        -Permissions 'ReadExecute' `
                        -Id (Get-AzADServicePrincipal -DisplayName $adls_from_dbx_name).Id `
                        -Concurrency 128  

        Set-AZDataLakeStoreItemAclEntry `
                        -AccountName $datalake_name `
                        -Path $data_lake_folder `
                        -AceType 'User' `
                        -Permissions 'ReadExecute' `
                        -Id (Get-AzADServicePrincipal -DisplayName $adls_from_dbx_name).Id `
                        -Concurrency 128  `
                        -Default
    }

Write-Host "[*] Finished adding ReadExecute Azure Data Lake Store access to $adls_from_dbx_name on top levels"


Write-Host "[*] Adding ReadExecute Azure Data Lake Store access to $adls_from_adf_name on top levels:"

ForEach ($data_lake_folder in $data_lake_folders)
    {

        Write-Host "[*] $data_lake_folder"

        Set-AZDataLakeStoreItemAclEntry `
                        -AccountName $datalake_name `
                        -Path $data_lake_folder `
                        -AceType 'User' `
                        -Permissions 'ReadExecute' `
                        -Id (Get-AzADServicePrincipal -DisplayName $adls_from_adf_name).Id `
                        -Concurrency 128  

        Set-AZDataLakeStoreItemAclEntry `
                        -AccountName $datalake_name `
                        -Path $data_lake_folder `
                        -AceType 'User' `
                        -Permissions 'ReadExecute' `
                        -Id (Get-AzADServicePrincipal -DisplayName $adls_from_adf_name).Id `
                        -Concurrency 128  `
                        -Default
    }

Write-Host "[*] Finished adding ReadExecute Azure Data Lake Store access to $adls_from_adf_name on top levels"


                                                            <#####################################

                                                                        AZURE DATA FACTORY

                                                            #####################################>

Write-Host "[*] Creating linked services in Data Factory"

Write-Host "[*] Key Vault Linked Service"

Set-AzDataFactoryV2LinkedService `
            -ResourceGroupName $resource_group_name `
            -DataFactoryName $data_factory_name `
            -Name $linked_service_key_vault_name `
            -File "$json_files_path\linked_service_key_vault.json" `
            -Force | Format-List


Write-Host "[*] Immutable Linked Service"

Set-AzDataFactoryV2LinkedService `
            -ResourceGroupName $resource_group_name `
            -DataFactoryName $data_factory_name `
            -Name $linked_service_immutable_name `
            -File "$json_files_path\linked_service_immutable.json" `
            -Force | Format-List
            
Write-Host "[*] Source Image Linked Service"

Set-AzDataFactoryV2LinkedService `
            -ResourceGroupName $resource_group_name `
            -DataFactoryName $data_factory_name `
            -Name $linked_service_source_image_name `
            -File "$json_files_path\linked_service_source_image.json" `
            -Force | Format-List

Write-Host "[*] Landing Linked Service"

Set-AzDataFactoryV2LinkedService `
            -ResourceGroupName $resource_group_name `
            -DataFactoryName $data_factory_name `
            -Name $linked_service_landing_name `
            -File "$json_files_path\linked_service_landing.json" `
            -Force | Format-List


Write-Host "[*] Finished creating linked services in Data Factory"

