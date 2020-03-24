
## Creating Healthcare Bot Deployment

### Requirements
Clone this repository to your local drive

```powershell
git clone https://github.com/microsoft/VirtualHealthcareBlueprint
cd VirtualHealthcareBlueprint
```

[Install the Azure PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-3.3.0)

### Connect to Azure Subscription

```PowerShell
Login-AzAccount
$account = Set-AzContext -Subscription <Your Subscription Name>
```

### Create Healthcare Bot and supporting Resources

```PowerShell
$rg = New-AzResourceGroup -Name <service Name> -Location eastus
```

Set Healthcare Bot name

```PowerShell
$botServiceName = "<healthcare bot service>"
```

Load the marketplace script

```powershell
. .\scripts\marketplace.ps1
```

Create the Healthcare Bot Azure Marketplace SaaS Application

```powershell
$saasSubscriptionId =  New-HbsSaaSApplication -name $botServiceName -planId free
```

You can also see all your existing SaaS applications by running this command. 

```Powershell
Get-HbsSaaSApplication
```

Deploy Healthcare Bot resources for the Marketplace SaaS application you just created or already had before.

```powershell
.\scripts\azuredeploy-healthcarebot.ps1 -ResourceGroup $rg.ResourceGroupName `
    -saasSubscriptionId $saasSubscriptionId  -serviceName $botServiceName `
    -botLocation US -matchingParameters $matchingOutput.Outputs
```

This command can take few minutes to complete
