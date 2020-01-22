. ./profile.ps1
. ./utils.ps1
. ./marketplace.ps1
. ./luis.ps1
. ./bot.ps1
. ./tenant.ps1
. ./ad.ps1

Write-Host  "Running CTM-Blueprint..." -ForegroundColor Green
$context = Get-AzContext
$userId = $context.Account.id
$subscriptionId = $context.subscription.id
$planId = "free"
$offerId = "microsofthealthcarebot"

$objectId =$(Get-AzureADUser -Filter "UserPrincipalName eq '$userId'").ObjectId
Write-Host ObjectId: $objectId

Try {
    $resourceGroup = "CTM-Blueprint"
    Write-Host "Running Template Deplpyment"
    $output = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroup -TemplateFile "../arm-templates/azuredeploy.json" -objectId $objectId
        
    Write-Host "Creating SaaS Marketplace offering $offerId..." -NoNewline
    $marketplaceApp = New-HbsSaaSApplication -ResourceName $output.Outputs["uniqueServiceName"].Value -planId $planId -offerId $offerId -SubscriptionId $subscriptionId
    Write-Host $marketplaceApp

}    
Catch {
    Write-Host
    Write-Error -Exception $_.Exception    
}    
