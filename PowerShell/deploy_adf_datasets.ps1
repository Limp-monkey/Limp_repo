$Dataset_list =  "$env:SYSTEM_ARTIFACTSDIRECTORY\_Deployments\Azure_Data_Factory\$env:PIPELINE_DEPLOYMENT_OBJECT_LIST_FOLDER\datasets.txt"

Get-Content $Dataset_list | ForEach-Object {
$Dataset = $_

$dataset_json = Get-Content $env:SYSTEM_ARTIFACTSDIRECTORY\_$env:PIPELINE_SOURCE_DATA_FACTORY_NAME\dataset\$Dataset.json | ConvertFrom-Json

New-AzResource -ResourceType "Microsoft.DataFactory/factories/datasets"  -ResourceGroupName $env:PIPELINE_TARGET_RESOURCE_GROUP_NAME  -Name "$env:PIPELINE_TARGET_DATA_FACTORY_NAME/$Dataset" -ApiVersion $env:PIPELINE_APIVERSION -Properties  $dataset_json -IsFullObject -Force


}