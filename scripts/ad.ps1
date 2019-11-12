Function ComputePassword {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    $aesManaged.GenerateKey()
    return [System.Convert]::ToBase64String($aesManaged.Key)
}

Function CreateAppKey($fromDate, $durationInYears, $pw) {  
    $testKey = GenerateAppKey -fromDate $fromDate -durationInYears $durationInYears -pw $pw  
    $key = $testKey  
    return $key
}

Function GenerateAppKey ($fromDate, $durationInYears, $pw) {
    $endDate = $fromDate.AddYears($durationInYears) 
    $keyId = (New-Guid).ToString();
    $key = New-Object Microsoft.Open.AzureAD.Model.PasswordCredential($null, $endDate, $keyId, $fromDate, $pw)
    return $key
}

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

Function GetRequiredPermissions($requiredApplicationPermissions, $reqsp) {
    $sp = $reqsp
    $appid = $sp.AppId
    $requiredAccess = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $requiredAccess.ResourceAppId = $appid
    $requiredAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]
    if ($requiredApplicationPermissions) {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.AppRoles -requiredAccesses $requiredApplicationPermissions -permissionType "Role"
    }
    return $requiredAccess
}

function New-HbsADApplication ($displayName) {    
    $pw = ComputePassword
    $fromDate = [System.DateTime]::Now
    $appKey = CreateAppKey -fromDate $fromDate -durationInYears 10 -pw $pw
    $ApplicationPermissions = "Reports.Read.All"

    Connect-AzureAD
    $graphsp = Get-AzureADServicePrincipal -SearchString "Microsoft Graph"
    $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]
    $microsoftGraphRequiredPermissions = GetRequiredPermissions -reqsp $graphsp -requiredApplicationPermissions $ApplicationPermissions 
    $requiredResourcesAccess.Add($microsoftGraphRequiredPermissions)

    
    Write-Host "Creating the AAD application $displayName..." -NoNewline
    $aadApplication = New-AzureADApplication -DisplayName $displayName `
                      -PasswordCredentials $appKey -AvailableToOtherTenants $true `
                      -RequiredResourceAccess $requiredResourcesAccess

    New-AzureADServicePrincipal -AppId $aadApplication.AppId                      
    Write-Host "Done" -ForegroundColor Green                       

    return @{app = $aadApplication 
             creds=$appKey}
}

New-HbsADApplication -displayName "Arie Test 3"


