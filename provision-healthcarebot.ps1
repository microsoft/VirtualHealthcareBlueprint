
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
        $resourceGroup,
        $planId
    )
    
    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $sku = "F0"
    $endpoint = "https://bot-api-us.healthbot-$env.microsoft.com/bot/dynabot/$botId"
    if ($planId -ne "free") {
        $sku = "S1"
        $endpoint = "https://bot-api-us.healthbot-$env.microsoft.com/bot-premium/dynabot/$botId"
    }

    $body = @{
            location = "global"
            sku = @{
                name = $sku
            }
            kind = "bot"
            properties = @{
                name = $botId
                displayName = $displayName
                endpoint = $endpoint
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
        $offerId,
        $subscriptionId,
        $resourceGroup,
        $location
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
        subscriptionId = $subscriptionId
        resourceGroup = $resourceGroup
        location = $location
    } | ConvertTo-Json

    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $result = Invoke-WebRequest -Uri $onboardingEndpoint/saas/tenants/?api-version=2019-07-01 `
                      -Method "post" `
                      -ContentType "application/json" `
                      -Headers $headers `
                      -Body $body
    $tenant = ConvertFrom-Json $result.Content                
    return $tenant
}

$Name="Arie ## Schwartzman Demo Bot"
$tenantId = Get-HbsUniqueTenantId -Name $Name
$resourceGroup = "MarketplaceBot"
$subscriptionId = "eabec01e-cbfe-4695-9ad8-4211c2495782"
$planId = "free"
$offerId = "microsofthealthcarebot"
$onboardingEndpoint = "http://localhost:8083/api"
$location = "US"
$env = "dev"

Try {
    Write-Host "Creating SaaS Marketplace offering $offerId..." -NoNewline
    $marketplaceApp = New-HbsSaaSApplication -ResourceName $Name -planId $planId -offerId $offerId -SubscriptionId $subscriptionId
    Write-Host "Done" -ForegroundColor Green
    $appSecret = Get-RandomCharacters -length 30 -characters 'abcdefghiklmnoprstuvwxyz1234567890!"§$%&/()=?}][{@#*+'
    Write-Host "Creating MSA Appliction $tenantId..." -NoNewline
    $app = New-HbsConvergedApplication -displayName $tenantId -appSecret $appSecret
    Write-Host "Done" -ForegroundColor Green
    Write-Host "Creating Bot Registration $tenantId..." -NoNewline
    $bot = New-HbsBotRegistration -displayName $Name -botId $tenantId -subscriptionId $subscriptionId -resourceGroup $resourceGroup -appId $app.appId -planId $planId
    Write-Host "Done" -ForegroundColor Green
    Write-Host "Getting Webchat secret..." -NoNewline
    $webchatSecret = Get-HbsWebchatSecret -resourceId $bot.id
    Write-Host "Done" -ForegroundColor Green
    $saasSubscriptionId = Split-Path $marketplaceApp.id -Leaf
    Write-Host "Creating HBS Tenant $tenantId..." -NoNewline
    $saasApplication = New-HbsTenant -name $Name -tenantId $tenantId -appId $app.appId -appSecret $appSecret -webchatSecret $webchatSecret `
                             -saasSubscriptionId $saasSubscriptionId `
                             -planId $planId -offerId $offerId `
                             -subscriptionId $subscriptionId `
                             -resourceGRoup $resourceGroup `
                             -location $location
    return $saasApplication 
}
Catch {
    Write-Host
    Write-Error -Exception $_.Exception
}
