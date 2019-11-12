
. ./profile.ps1
. ./utils.ps1
. ./marketplace.ps1
. ./luis.ps1
. ./bot.ps1
. ./tenant.ps1


$Name = "VHA-Blueprint"
$tenantId = Get-HbsUniqueTenantId -Name $Name
$resourceGroup = "Virtual-Healthcare-Blueprint"
$context = Get-AzContext
$subscriptionId = $context.subscription.id
$planId = "free"
$offerId = "microsofthealthcarebot"
$location = "US"
$ds_location = "eastus"
$luisAuthLocation = "westus"
$env = "dev"
$luisAppFile = "../lu/LUIS.Triage.json"
$restorePath = "../bot-templates/teams-handoff.json"
$portalEndpoint = "https://us.healthbot-$env.microsoft.com/account"


Try {

    Write-Host "Creating/Using ResourceGroup $resourceGroup..." -NoNewline
    $rg = New-ResourceGroupIfNeeded -resourceGroup $resourceGroup -location $ds_location    
    Write-Host "Done" -ForegroundColor Green
    
    Write-Host "Creating LUIS Authoring Account $tenantId-authoring..." -NoNewline
    $luisAuthoring = New-AzCognitiveServicesAccount -ResourceGroupName $resourceGroup -Name $tenantId-authoring `
                    -Type LUIS.Authoring -SkuName "F0" -Location $luisAuthLocation -ErrorAction Stop
    $luisAuthoringKey = Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroup -Name $tenantId-authoring                
    Write-Host "Done" -ForegroundColor Green
    
    Write-Host "Creating LUIS Prediction Account $tenantId..." -NoNewline
    $luis = New-AzCognitiveServicesAccount -ResourceGroupName $resourceGroup -Name $tenantId `
        -Type LUIS -SkuName "S0" -Location $luisAuthLocation -ErrorAction Stop
    $luisKey = Get-AzCognitiveServicesAccountKey -ResourceGroupName $resourceGroup -Name $tenantId                
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Creating Application Insights $tenantId..." -NoNewline
    $appInsights = New-AzApplicationInsights -ResourceGroupName $resourceGroup -Name $tenantId -Location $ds_location -ErrorAction Stop
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Creating SaaS Marketplace offering $offerId..." -NoNewline
    $marketplaceApp = New-HbsSaaSApplication -ResourceName $Name -planId $planId -offerId $offerId -SubscriptionId $subscriptionId
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Creating MSA Appliction $tenantId..." -NoNewline    
    $app = New-HbsConvergedApplication -displayName $tenantId

    Write-Host "Done" -ForegroundColor Green

    Write-Host "Creating Bot Registration $tenantId..." -NoNewline
    $bot = New-HbsBotRegistration -displayName $Name -botId $tenantId -subscriptionId $subscriptionId -resourceGroup $resourceGroup -appId $app.app.appId -planId $planId
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Getting Webchat secret..." -NoNewline
    $webchatSecret = Get-HbsWebchatSecret -resourceId $bot.id
    Write-Host "Done" -ForegroundColor Green

    $saasSubscriptionId = Split-Path $marketplaceApp.id -Leaf
    Write-Host "Creating HBS Tenant $tenantId..." -NoNewline
    $saasTenant = New-HbsTenant -name $Name -tenantId $tenantId -appId $app.app.appId -appSecret $app.creds.secretText -webchatSecret $webchatSecret `
        -saasSubscriptionId $saasSubscriptionId `
        -planId $planId -offerId $offerId `
        -subscriptionId $subscriptionId `
        -resourceGRoup $resourceGroup `
        -location $location `
        -instrumentationKey $appInsights.InstrumentationKey
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Restoring from backup" -NoNewline
    $restoreJSON = Get-Content -Raw -Path $restorePath
    Restore-HbsTenant -location $location -tenant $saasTenant -data $restoreJSON
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Importing LUIS Application from $luisAppFile..." -NoNewline
    $luisJSON = Get-Content -Raw -Path $luisAppFile
    $luisApplicationId = Import-LuisApplication -luisJSON $luisJSON -location $luisAuthLocation -authKey $luisAuthoringKey.Key1
    Write-Host "Done" -ForegroundColor Green

    Write-Host "Assigning LUIS app to LUIS account" -NoNewline
    $assignLuisApp = Set-LuisApplicationAccount -appId $luisApplicationId -subscriptionId $subscriptionId `
                        -resourceGroup $resourceGroup -accountName $tenantId -location $luisAuthLocation -authKey $luisAuthoringKey.Key1
    Write-Host "Done" -ForegroundColor Green

    $saasTenant 
    Write-Host "Your new Healthcare Bot was created: " $portalEndpoint/$tenantId -ForegroundColor Green
    Write-Host "Your new SaaS Application was created: https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource/providers/Microsoft.SaaS/saasresources/$saasSubscriptionId/overview" -ForegroundColor Green

}
Catch {
    Write-Host
    Write-Error -Exception $_.Exception
}
