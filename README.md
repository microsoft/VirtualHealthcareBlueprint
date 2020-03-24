# Creating automated Healthcare Bot deployment

## Overview

This repo will allow you to automate the deployment of Healthcare Bot instance on your own Azure account and linked to your Azure subscription that will also include the LUIS (Language understanding) resources with a sample LUIS model and Application Insights Instrumnetation key configured.

## Prerequisites

1. Clone this repository to your local drive

```powershell
git clone https://github.com/microsoft/VirtualHealthcareBlueprint
cd VirtualHealthcareBlueprint
```

2. [Install the Azure PowerShell Az module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-3.3.0)

3. Connect to your Azure Subscription

```PowerShell
Login-AzAccount
$account = Set-AzContext -Subscription <Your Subscription Name>
```

## Create Healthcare Bot resources

1. Create the Resource Group to contain the supporting resources.

```PowerShell
$rg = New-AzResourceGroup -Name <service Name> -Location eastus
```

2. Assign Healthcare Bot service name

```PowerShell
$botServiceName = "<healthcare bot service>"
```

3. Load the marketplace script

```powershell
. .\scripts\marketplace.ps1
```

4. Create the Healthcare Bot Azure Marketplace SaaS Application.

```powershell
$saasSubscriptionId =  New-HbsSaaSApplication -name $botServiceName -planId free
```

4. Deploy Healthcare Bot resources for the Marketplace SaaS application you just created or already had before.

```powershell
.\scripts\azuredeploy-healthcarebot.ps1 -ResourceGroup $rg.ResourceGroupName `
    -saasSubscriptionId $saasSubscriptionId  -serviceName $botServiceName `
    -botLocation US -matchingParameters $matchingOutput.Outputs
```
