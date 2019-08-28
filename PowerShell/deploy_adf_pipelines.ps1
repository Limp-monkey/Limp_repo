$pipeline_list =  "$env:SYSTEM_ARTIFACTSDIRECTORY\_Deployments\Azure_Data_Factory\$env:PIPELINE_DEPLOYMENT_OBJECT_LIST_FOLDER\pipelines.txt"

Get-Content $pipeline_list | ForEach-Object {
$pipeline = $_

$pipeline_json = Get-Content $env:SYSTEM_ARTIFACTSDIRECTORY\_$env:PIPELINE_SOURCE_DATA_FACTORY_NAME\pipeline\$pipeline.json | ConvertFrom-Json

New-AzResource -ResourceType "Microsoft.DataFactory/factories/pipelines"  -ResourceGroupName $env:PIPELINE_TARGET_RESOURCE_GROUP_NAME  -Name "$env:PIPELINE_TARGET_DATA_FACTORY_NAME/$pipeline" -ApiVersion $env:PIPELINE_APIVERSION -Properties  $pipeline_json -IsFullObject -Force


}