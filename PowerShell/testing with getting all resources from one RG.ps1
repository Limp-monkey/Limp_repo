##Connect-AzAccount
param(
    [Parameter(Mandatory=$false)]
    [String] $Subscription,   
    [Parameter(Mandatory=$false)]
    [String] $ResourceGroupName

)
$DataLakeSub = Get-AzSubscription | Select-Object Name, Id | where Name -eq $Subscription

$DataLakeRG = get-azresourcegroup |  Where {$_.ResourceGroupName -eq $ResourceGroupName}

$DataLakeRG = $DataLakeRG | foreach { $_.ResourceGroupName } 

Get-AzResource | where {$_.ResourceGroupName -eq $DataLakeRG} | Select-Object Name,  ResourceType, Location