function New-HbsConvergedApplication {
    param (
        $displayName
    )

    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $body = @{
        displayName = $displayName
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
        location   = "global"
        sku        = @{
            name = $sku
        }
        kind       = "bot"
        properties = @{
            name               = $botId
            displayName        = $displayName
            endpoint           = $endpoint
            msaAppId           = $appId
            enabledChannels    = @("webchat", "directline")
            configuredChannels = @("webchat", "directline")
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
