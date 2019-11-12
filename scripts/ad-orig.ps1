<# This script will create a single Azure AD Application in your tenant, apply the appropriate permissions to it and execute a test call against a specified endpoint. Modify the values at the top of this script as required. #>
  
$applicationName = "GCITS Reporting"
  
# Modify the homePage, appIdURI and logoutURI values to whatever valid URI you like. They don't need to be actual addresses.
$homePage = "https://secure.gcits.com"
$appIdURI = "https://secure.gcits.com/reportingapp"
$logoutURI = "http://portal.office.com"
  
# Set this to false to keep the application in your tenant.
$removeApplicationWhenComplete = $true
  
# Set this to false to limit consent for delegated permissions to a single user ($UserForDelegatedPermissions).
$ConsentDelegatedPermissionsForAllUsers = $true
  
# If your initial test call required delegate permissions, set this to true. The script will retrieve an access token using the 'password' grant type instead.
$testCallRequiresDelegatePermissions = $false
  
# This will export information about the application to a CSV located at C:\temp\.
# The CSV will include the Client ID and Secret of the application, so keep it safe.
$exportApplicationInfoToCSV = $true
  
# These endpoints are called using GET method. Please modify the script below as required.
$URIForApplicationPermissionCall = "https://graph.microsoft.com/beta/reports/getTenantSecureScores(period=1)/content"
$URIForDelegatedPermissionCall = "https://graph.microsoft.com/v1.0/users"
  
# If using Delegated Permissions to execute a test call, you can specify username and password info here. 
# I strongly recommend securing these and not including them directly on the script. 
$UserForDelegatedPermissions = "user@domain.com"
$Password = "#########"
  
  
# Enter the required permissions below, separated by spaces eg: "Directory.Read.All Reports.Read.All Group.ReadWrite.All Directory.ReadWrite.All"
$ApplicationPermissions = "Reports.Read.All"
  
# Set DelegatePermissions to $null if you only require application permissions. 
$DelegatedPermissions = $null
# Otherwise, include the required delegated permissions below.
# $DelegatedPermissions = "Directory.Read.All Group.ReadWrite.All"
  
  
Function AddResourcePermission($requiredAccess, $exposedPermissions, $requiredAccesses, $permissionType) {
    foreach ($permission in $requiredAccesses.Trim().Split(" ")) {
        $reqPermission = $null
        $reqPermission = $exposedPermissions | Where-Object {$_.Value -contains $permission}
        Write-Host "Collected information for $($reqPermission.Value) of type $permissionType" -ForegroundColor Green
        $resourceAccess = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
        $resourceAccess.Type = $permissionType
        $resourceAccess.Id = $reqPermission.Id    
        $requiredAccess.ResourceAccess.Add($resourceAccess)
    }
}
  
Function GetRequiredPermissions($requiredDelegatedPermissions, $requiredApplicationPermissions, $reqsp) {
    $sp = $reqsp
    $appid = $sp.AppId
    $requiredAccess = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $requiredAccess.ResourceAppId = $appid
    $requiredAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]
    if ($requiredDelegatedPermissions) {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.Oauth2Permissions -requiredAccesses $requiredDelegatedPermissions -permissionType "Scope"
    } 
    if ($requiredApplicationPermissions) {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.AppRoles -requiredAccesses $requiredApplicationPermissions -permissionType "Role"
    }
    return $requiredAccess
}
  
Function GenerateAppKey ($fromDate, $durationInYears, $pw) {
    $endDate = $fromDate.AddYears($durationInYears) 
    $keyId = (New-Guid).ToString();
    $key = New-Object Microsoft.Open.AzureAD.Model.PasswordCredential($null, $endDate, $keyId, $fromDate, $pw)
    return $key
}
  
Function CreateAppKey($fromDate, $durationInYears, $pw) {
  
    $testKey = GenerateAppKey -fromDate $fromDate -durationInYears $durationInYears -pw $pw
  
    while ($testKey.Value -match "\+" -or $testKey.Value -match "/") {
        Write-Host "Secret contains + or / and may not authenticate correctly. Regenerating..." -ForegroundColor Yellow
        $pw = ComputePassword
        $testKey = GenerateAppKey -fromDate $fromDate -durationInYears $durationInYears -pw $pw
    }
    Write-Host "Secret doesn't contain + or /. Continuing..." -ForegroundColor Green
    $key = $testKey
  
    return $key
}
  
Function ComputePassword {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    $aesManaged.GenerateKey()
    return [System.Convert]::ToBase64String($aesManaged.Key)
}
  
Function AddOAuth2PermissionGrants($DelegatedPermissions) {
    $resource = "https://graph.windows.net/"
    $client_id = $aadApplication.AppId
    $client_secret = $appkey.Value
    $authority = "https://login.microsoftonline.com/$tenant_id"
    $tokenEndpointUri = "$authority/oauth2/token"
    $content = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&resource=$resource"
  
    $Stoploop = $false
    [int]$Retrycount = "0"
  
    do {
        try {
            $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing
            Write-Host "Retrieved Access Token for Azure AD Graph API" -ForegroundColor Green
            # Assign access token
            $access_token = $response.access_token
  
            $headers = @{
                Authorization = "Bearer $access_token"
            }
  
            if ($ConsentDelegatedPermissionsForAllUsers) {
                $principal = "AllPrincipals"
                $principalId = $null
            }
            else {
                $principal = "Principal"
                $principalId = (Get-AzureADUser -ObjectId $UserForDelegatedPermissions).ObjectId
            }
  
            $postbody = @{
                clientId    = $serviceprincipal.ObjectId
                consentType = $principal
                startTime   = ((get-date).AddDays(-1)).ToString("yyyy-MM-dd")
                principalId = $principalId
                resourceId  = $graphsp.ObjectId
                scope       = $DelegatedPermissions
                expiryTime  = ((get-date).AddYears(99)).ToString("yyyy-MM-dd")
            }
  
            $postbody = $postbody | ConvertTo-Json
  
            $body = Invoke-RestMethod -Uri "https://graph.windows.net/myorganization/oauth2PermissionGrants?api-version=1.6" -Body $postbody -Method POST -Headers $headers -ContentType "application/json"
            Write-Host "Created OAuth2PermissionGrants for $DelegatedPermissions" -ForegroundColor Green
  
            $Stoploop = $true
        }
        catch {
            if ($Retrycount -gt 5) {
                Write-Host "Could not get create OAuth2PermissionGrants after 6 retries." -ForegroundColor Red
                $Stoploop = $true
            }
            else {
                Write-Host "Could not create OAuth2PermissionGrants yet. Retrying in 5 seconds..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds 5
                $Retrycount ++
            }
        }
    }
    While ($Stoploop -eq $false)
}
  
  
function GetOrCreateMicrosoftGraphServicePrincipal {
    $graphsp = Get-AzureADServicePrincipal -SearchString "Microsoft Graph"
    if (!$graphsp) {
        $graphsp = Get-AzureADServicePrincipal -SearchString "Microsoft.Azure.AgregatorService"
    }
    if (!$graphsp) {
        Login-AzureRmAccount
        New-AzureRmADServicePrincipal -ApplicationId "00000003-0000-0000-c000-000000000000"
        $graphsp = Get-AzureADServicePrincipal -SearchString "Microsoft Graph"
    }
  
    return $graphsp
}
  
Connect-AzureAd
Write-Host (Get-AzureADTenantDetail).displayName
  
# Check for a Microsoft Graph Service Principal. If it doesn't exist already, create it.
$graphsp = GetOrCreateMicrosoftGraphServicePrincipal
  
$existingapp = $null
$existingapp = get-azureadapplication -SearchString $applicationName
if ($existingapp) {
    Remove-Azureadapplication -ObjectId $existingApp.objectId
}
 
$rsps = @()
if ($graphsp) {
    $rsps += $graphsp
    $tenant_id = (Get-AzureADTenantDetail).ObjectId
    $tenantName = (Get-AzureADTenantDetail).DisplayName
    $azureadsp = Get-AzureADServicePrincipal -SearchString "Windows Azure Active Directory"
    $rsps += $azureadsp
  
    # Add Required Resources Access (Microsoft Graph)
    $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]
    $microsoftGraphRequiredPermissions = GetRequiredPermissions -reqsp $graphsp -requiredApplicationPermissions $ApplicationPermissions -requiredDelegatedPermissions $DelegatedPermissions
    $requiredResourcesAccess.Add($microsoftGraphRequiredPermissions)
  
    if ($DelegatedPermissions) {
        Write-Host "Delegated Permissions specified, preparing permissions for Azure AD Graph API"
        # Add Required Resources Access (Azure AD Graph)
        $AzureADGraphRequiredPermissions = GetRequiredPermissions -reqsp $azureadsp -requiredApplicationPermissions "Directory.ReadWrite.All"
        $requiredResourcesAccess.Add($AzureADGraphRequiredPermissions)
    }
  
  
    # Get an application key
    $pw = ComputePassword
    $fromDate = [System.DateTime]::Now
    $appKey = CreateAppKey -fromDate $fromDate -durationInYears 2 -pw $pw
  
    Write-Host "Creating the AAD application $applicationName" -ForegroundColor Blue
    $aadApplication = New-AzureADApplication -DisplayName $applicationName `
        -HomePage $homePage `
        -ReplyUrls $homePage `
        -IdentifierUris $appIdURI `
        -LogoutUrl $logoutURI `
        -RequiredResourceAccess $requiredResourcesAccess `
        -PasswordCredentials $appKey
      
    # Creating the Service Principal for the application
    $servicePrincipal = New-AzureADServicePrincipal -AppId $aadApplication.AppId
  
    Write-Host "Assigning Permissions" -ForegroundColor Yellow
    
    # Assign application permissions to the application
    foreach ($app in $requiredResourcesAccess) {
  
        $reqAppSP = $rsps | Where-Object {$_.appid -contains $app.ResourceAppId}
        Write-Host "Assigning Application permissions for $($reqAppSP.displayName)" -ForegroundColor DarkYellow
  
        foreach ($resource in $app.ResourceAccess) {
            if ($resource.Type -match "Role") {
                New-AzureADServiceAppRoleAssignment -ObjectId $serviceprincipal.ObjectId `
                    -PrincipalId $serviceprincipal.ObjectId -ResourceId $reqAppSP.ObjectId -Id $resource.Id
            }
        }
     
    }
  
    # Assign delegated permissions to the application
    if ($requiredResourcesAccess.ResourceAccess -match "Scope") {
        Write-Host "Delegated Permissions found. Assigning permissions to required user"  -ForegroundColor DarkYellow
          
        foreach ($app in $requiredResourcesAccess) {
            $appDP = @()
            $reqAppSP = $rsps | Where-Object {$_.appid -contains $app.ResourceAppId}
  
            foreach ($resource in $app.ResourceAccess) {
                if ($resource.Type -match "Scope") {
                    $permission = $graphsp.oauth2permissions | Where-Object {$_.id -contains $resource.Id}
                    $appDP += $permission.Value
                }
            }
            if ($appDP) {
                Write-Host "Adding $appDP to user" -ForegroundColor DarkYellow
                $appDPString = $appDp -join " "
                AddOAuth2PermissionGrants -DelegatedPermissions $appDPString
            }
        }
    }
      
    Write-Host "App Created" -ForegroundColor Green
    
    # Define parameters for Microsoft Graph access token retrieval
    $client_id = $aadApplication.AppId;
    $client_secret = $appkey.Value
    $tenant_id = (Get-AzureADTenantDetail).ObjectId
    $resource = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$tenant_id"
    $tokenEndpointUri = "$authority/oauth2/token"
  
    # Get the access token using grant type password for Delegated Permissions or grant type client_credentials for Application Permissions
    if ($DelegatedPermissions -and $testCallRequiresDelegatePermissions) { 
        $content = "grant_type=password&client_id=$client_id&client_secret=$client_secret&username=$UserForDelegatedPermissions&password=$Password&resource=$resource";
        $testCallUri = $UriForDelegatedPermissionCall
    }
    else {
        $content = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&resource=$resource"
        $testCallUri = $UriForApplicationPermissionCall
    }
      
      
    # Try to execute the API call 6 times
  
    $Stoploop = $false
    [int]$Retrycount = "0"
    do {
        try {
            $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing
            Write-Host "Retrieved Access Token" -ForegroundColor Green
            # Assign access token
            $access_token = $response.access_token
            $body = $null
  
            $body = Invoke-RestMethod `
                -Uri $testCallUri `
                -Headers @{"Authorization" = "Bearer $access_token"} `
                -ContentType "application/json" `
                -Method GET
                  
            Write-Host "Retrieved Graph content" -ForegroundColor Green
            $Stoploop = $true
        }
        catch {
            if ($Retrycount -gt 6) {
                Write-Host "Could not get Graph content after 7 retries." -ForegroundColor Red
                $Stoploop = $true
            }
            else {
                Write-Host "Could not get Graph content. Retrying in 5 seconds..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds 5
                $Retrycount ++
            }
        }
    }
    While ($Stoploop -eq $false)
  
    if ($exportApplicationInfoToCSV) {
        $appProperties = @{
            ApplicationName        = $ApplicationName
            TenantName             = $tenantName
            TenantId               = $tenant_id
            clientId               = $client_id
            clientSecret           = $client_secret
            ApplicationPermissions = $ApplicationPermissions
            DelegatedPermissions   = $DelegatedPermissions
        }
      
        $AppInfo = New-Object PSObject -Property $appProperties
        $AppInfo | Select-Object ApplicationName, TenantName, TenantId, clientId, clientSecret, `
            ApplicationPermissions, DelegatedPermissions | Export-Csv C:\temp\AzureADApps.csv -Append -NoTypeInformation
    }
      
    if ($removeApplicationWhenComplete) {
        Remove-AzureADApplication -ObjectId $aadApplication.ObjectId
        $confirmRemoval = $null
        try {
            $confirmRemoval = Get-AzureADApplication -ObjectId $aadApplication.ObjectId
        }
        catch {
            Write-Host "Application Removed" -ForegroundColor Green
        }
    }
}
else {
    Write-Host "Microsoft Graph Service Principal could not be found or created" -ForegroundColor Red
}
  
# Export CSV of Secure Score
if ($body.secureScore) {
    Write-Host "Exporting Secure Score to CSV" -ForegroundColor Green
    $createdDateString = "$($body.createdDate.Year)-$($body.createdDate.Month)-$($body.createdDate.Day)"
    $body | Add-Member TenantName $tenantName
    $body | Add-Member dateCreated $createdDateString
    $createdDateString = $body | Select-Object @{n = "createdDate"; e = {"$($_.createdDate.Year)-$($_.createdDate.Month)-$($_.createdDate.Day)"}}
    $body | Select-Object TenantName, TenantId, DateCreated, secureScore, maxSecureScore, accountScore, dataScore, deviceScore, averageSecureScore `
        | Export-Csv C:\temp\SecureScore.csv -NoTypeInformation -Append
}