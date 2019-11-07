$onboardingEndpoint = "http://localhost:8083/api"

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
        $location,
        $instrumentationKey
    )

    $body = @{
        name               = $tenantId
        friendly_name      = $name
        app_id             = $appId
        app_secret         = $appSecret
        email              = (Get-AzContext).Account.Id
        webchat_secret     = $webchatSecret
        usermanagement     = "portal"
        saasSubscriptionId = $saasSubscriptionId
        planId             = $planId
        offerId            = $offerId
        subscriptionId     = $subscriptionId
        resourceGroup      = $resourceGroup
        location           = $location
        instrumentationKey = $instrumentationKey
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

function Restore-HbsTenant($tenant, $location, $data) {

    $body = @{
        account = $tenant
        location = $location
        data = $data | ConvertFrom-Json
        email = (Get-AzContext).Account.Id
    } | ConvertTo-Json -Depth 10

    $headers = @{
        Authorization = Get-AzBearerToken
    }

    $result = Invoke-WebRequest -Uri $onboardingEndpoint/saas/restore/?api-version=2019-07-01 `
        -Method "post" `
        -ContentType "application/json" `
        -Headers $headers `
        -Body $body
    $tenant = ConvertFrom-Json $result.Content                
    return $tenant
}
