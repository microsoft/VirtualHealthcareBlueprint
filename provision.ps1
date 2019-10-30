

function New-HbsSaaSApplication() 
{
    param(
        $ResourceName,        
        $SubscriptionId,
        $planId,
        $offerId
    )    

    $accessToken = Get-AzBearerToken

    $headers = @{
        Authorization = $accessToken
    }
    $data = @{
        Properties = @{
            PublisherId = "microsoft-hcb"
            OfferId = $offerId
            SaasResourceName = $ResourceName
            SKUId = $planId
            PaymentChannelType = "SubscriptionDelegated"
            Quantity = 1
            TermId = "hjdtn7tfnxcy"
            PaymentChannelMetadata = @{
                AzureSubscriptionId = $SubscriptionId
            }
        }
    }
    $body = $data | ConvertTo-Json
    $result = Invoke-WebRequest -Uri https://management.azure.com/providers/microsoft.saas/saasresources?api-version=2018-03-01-beta  `
                                -Method 'put' -Headers $headers `
                                -Body $body -ContentType "application/json"

    if ($result.StatusCode -eq 202) {
        $location = $result.Headers['location'];
        $r = Invoke-WebRequest -Uri $location -Method 'get' -Headers $headers -ContentType "application/json"
        if ($null -eq $r) {
            return
        }
        while ($r.StatusCode -ne 200) {
            Write-Host "." -NoNewline
            Start-Sleep -Seconds 1 
            $r = Invoke-WebRequest -Uri $location -Method 'get' -Headers $headers -ContentType "application/json"
        }
        $operationStatus = ConvertFrom-Json $r.Content
        if ($operationStatus.properties.status -eq "PendingFulfillmentStart") {
            return $operationStatus
        }
        else {
            Write-Error "Failed to create" $ResourceName
        }
    }
}

function Get-HbsMarketplaceToken
{
    $tenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47"
    $authority = "https://login.microsoftonline.com/$tenantId/oauth2/token"    
    $resource = "62d94f6c-d599-489b-a797-3e10e42fbe22"
    $clientId = "346f6d5e-5aea-4d13-8de4-f1e947f546f9"
    $clientSecret = Get-Content "marketplace_principle_secret.txt" | ConvertTo-SecureString
    $tokenResponse = Get-ADALToken -Authority $authority -ClientId $clientId -Resource $resource -ClientSecret $clientSecret
    return $tokenResponse.AccessToken
}

function Get-HbsMarketplaceSaaSApplication {
    param (
        [Parameter(Mandatory)]
        [string]
        $subscriptionId
    )
    $token = Get-HbsMarketplaceToken
    $headers = @{
        Authorization = "Bearer " + $token
    }

    $result = Invoke-WebRequest -Uri https://marketplaceapi.microsoft.com/api/saas/subscriptions/$subscriptionId/?api-version=2018-08-31  `
                                -Method 'get' -Headers $headers `
                                -ContentType "application/json" 
    $subscription = ConvertFrom-Json $result.Content
    return $subscription
}

function Get-RandomCharacters($length, $characters) { 
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length } 
    $private:ofs="" 
    return [String]$characters[$random]
}

function Get-HbsUniqueTenantId {
    param (
        $Name
    )
    $cleanName = ($Name -replace "[^a-zA-Z0-9_-]*", "").ToLower();
    $suffix = Get-RandomCharacters -length 7 -characters 'abcdefghiklmnoprstuvwxyz1234567890' 
    return "$cleanName-$suffix"
}

function Set-HbsMarketplaceSubscription {
    param (
        $subscriptionId,
        $planId
    )

    $body = @{
        planId = $planId
        quantity = ""
    } | ConvertTo-Json

    $token = Get-HbsMarketplaceToken
    $headers = @{
        Authorization = "Bearer " + $token
    }
    Invoke-WebRequest -Uri https://marketplaceapi.microsoft.com/api/saas/subscriptions/$subscriptionId/activate?api-version=2018-08-31 `
                        -Method "post" `
                        -ContentType "application/json" `
                        -Headers $headers `
                        -Body $body
}

function New-HbsConvergedApplication {
    param (
        $displayName,
        $appSecret        
    )

    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $body = @{
        displayName = $displayName
        password = $appSecret 
    } | ConvertTo-Json

    $result = Invoke-WebRequest -Uri $onboardingEndpoint/saas/applications/?api-version=2019-07-01 `
                      -Method "post" `
                      -ContentType "application/json" `
                      -Headers $headers `
                      -Body $body
    $applicationsResponse = ConvertFrom-Json $result.Content                      
    return $applicationsResponse   
}

function New-HbsBotRegistration {
    param (
        $displayName,
        $botId,
        $appId,
        $subscriptionId,
        $resourceGroup
    )
    
    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $body = @{
            location = "global"
            sku = @{
                name = "F0"
            }
            kind = "bot"
            properties = @{
                name = $botId
                displayName = $displayName
                endpoint = "https://bot-api-us.healthbot-dev.microsoft.com/bot/dynabot/$botId"
                msaAppId = $appId
                enabledChannels = @("webchat", "directline")
                configuredChannels=  @("webchat", "directline")
            }
    } | ConvertTo-Json

    $result = Invoke-WebRequest `
                -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.BotService/botServices/$botId/?api-version=2017-12-01" `
                -Method "put" `
                -ContentType "application/json" `
                -Headers $headers `
                -Body $body 
    $botRegistration = ConvertFrom-Json $result.Content 
    return $botRegistration
}

function Get-HbsWebchatSecret {
    param (
        $resourceId
    )
    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $result = Invoke-WebRequest -Uri "https://management.azure.com/$resourceId/channels/WebChatChannel/listChannelWithKeys/?api-version=2017-12-01" `
                               -Method "post" `
                               -ContentType "application/json" `
                               -Headers $headers
    $botChannel = ConvertFrom-Json $result.Content                
    return $botChannel.properties.properties.sites[0].key
}

function New-HbsTenant {
    param (
        [Parameter(Mandatory)]
        [string]
        $name,
        $tenantId,
        $appId,
        $appSecret,
        $webchatSecret,
        $saasSubscriptionId,
        $planId,
        $offerId
    )

    $body = @{
        name = $tenantId
        friendly_name = $name
        app_id = $appId
        app_secret = $appSecret
        email = (Get-AzContext).Account.Id
        webchat_secret = $webchatSecret
        usermanagement = "portal"
        saasSubscriptionId = $saasSubscriptionId
        planId = $planId
        offerId = $offerId
    } | ConvertTo-Json

    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $result = Invoke-WebRequest -Uri http://localhost:8083/api/saas/tenants/?api-version=2019-07-01 `
                      -Method "post" `
                      -ContentType "application/json" `
                      -Headers $headers `
                      -Body $body
    $tenant = ConvertFrom-Json $result.Content                
    return $tenant
}

#New-HbsSaaSApplication -ResourceName "SaaS App-2" -planId free -SubscriptionId dfdf63df-6c7e-44f9-be51-e45ca146ddb8
#Get-HbsMarketplaceToken
#Get-HbsMarketplaceSaaSApplication -subscriptionId af1d14b1-f5da-56dd-acf3-29cdb4f16705
#Set-HbsMarketplaceSubscription -subscriptionId af1d14b1-f5da-56dd-acf3-29cdb4f16705 -planId free
#New-HbsConvergedApplication -displayName "my app" -password $password
#$bot = New-HbsBotRegistration -displayName "mybotarie" -botId "mybotarie-123456789" -subscriptionId "dfdf63df-6c7e-44f9-be51-e45ca146ddb8" -resourceGroup "SaaSHealthcareBotsRG" -password $password
#$webchatSecret = Get-HbsWebchatSecret -resourceId $bot.id

$Name="Arie ## Schwartzman Demo Bot"
$tenantId = Get-HbsUniqueTenantId -Name $Name
$resourceGroup = "MarketplaceBot"
$subscriptionId = "eabec01e-cbfe-4695-9ad8-4211c2495782"
$planId = "free"
$offerId = "microsofthealthcarebot"
$onboardingEndpoint = "http://localhost:8083/api"

Try {
    Write-Host "Creating SaaS Marketplace offering $offerId..." -NoNewline
    $marketplaceApp = New-HbsSaaSApplication -ResourceName $Name -planId $planId -offerId $offerId -SubscriptionId $subscriptionId
    Write-Host "Done" -ForegroundColor Green
    $appSecret = Get-RandomCharacters -length 30 -characters 'abcdefghiklmnoprstuvwxyz1234567890!"§$%&/()=?}][{@#*+'
    Write-Host "Creating MSA Appliction $tenantId..." -NoNewline
    $app = New-HbsConvergedApplication -displayName $tenantId -appSecret $appSecret
    Write-Host "Done" -ForegroundColor Green
    Write-Host "Creating Bot Registration $tenantId..." -NoNewline
    $bot = New-HbsBotRegistration -displayName $Name -botId $tenantId -subscriptionId $subscriptionId -resourceGroup $resourceGroup -appId $app.id
    Write-Host "Done" -ForegroundColor Green
    Write-Host "Getting Webchat secret..." -NoNewline
    $webchatSecret = Get-HbsWebchatSecret -resourceId $bot.id
    Write-Host "Done" -ForegroundColor Green
    $saasSubscriptionId = Split-Path $marketplaceApp.id -Leaf
    Write-Host "Creating HBS Tenant $tenantId..." -NoNewline
    $tenant = New-HbsTenant -name $Name -tenantId $tenantId -appId $app.id -appSecret $appSecret -webchatSecret $webchatSecret `
                             -saasSubscriptionId $saasSubscriptionId `
                             -planId $planId -offerId $offerId
    Write-Host "Done" -ForegroundColor Green    
}
Catch {
    Write-Host
    Write-Error -Exception $_.Exception
}
