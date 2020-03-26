# Automated Healthcare Bot deployment

![HealthCare bot](./images/logo.png)

## Overview

This repo will allow you to automate the deployment of Healthcare Bot instance on your own Azure account and linked to your Azure subscription that will also include the LUIS (Language understanding) resources with a [sample LUIS model](./lu/Booking.j) and Application Insights Instrumentation key configured.

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
Set-AzContext -Subscription <Your Subscription Name>
```

## Create Healthcare Bot resources

1. Create the Resource Group that will contain the supporting resources. These will include:
    * Application Insights
    * LUIS Authoring account
    * LUIS Prediction account

```PowerShell
$rg = New-AzResourceGroup -Name <service Name> -Location eastus
```

2. Assign Healthcare Bot service name. This will be used to derive all the other resource names.

```PowerShell
$botServiceName = "<healthcare bot service>"
```

3. Load the marketplace script

```powershell
. .\scripts\marketplace.ps1
```

4. Create the Healthcare Bot Azure Marketplace SaaS Application. Available plans are:

* free
* s1 - s5 (paid plans)

```powershell
$saasSubscriptionId =  New-HbsSaaSApplication -name $botServiceName -planId free
```


4. Deploy Healthcare Bot resources for the Marketplace SaaS application you just created in previous step. Available locations are US and EU

```powershell
.\scripts\azuredeploy-healthcarebot.ps1 -ResourceGroup $rg.ResourceGroupName `
    -saasSubscriptionId $saasSubscriptionId  -serviceName $botServiceName `
    -botLocation US
```
