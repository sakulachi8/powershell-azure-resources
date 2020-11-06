# Subscription ID
$subID = ""

# RG and Location 
$rgName = "RG-app-test-02"
$location =  "EastUS"

#Virtual network and Subnet Name
$vnetName = "Vnet"
$subnetName = "app-subnet"

#webplan and App service name
$aspname = "webappplan"
$webappname = "testapp" 

#Azure redis name
$redisName = "rediscache"

# Create a unique name for front door 
$fdname = "frontend-$(Get-Random)"


#Create a New RG
New-AzResourceGroup -Name $rgName -Location $location


#Create VNET
$virtualNetwork = New-AzVirtualNetwork `
  -ResourceGroupName $rgName `
  -Location $location `
  -Name $vnetName `
  -AddressPrefix 10.0.0.0/16

$subnetConfig = Add-AzVirtualNetworkSubnetConfig `
  -Name $subnetName `
  -AddressPrefix 10.0.1.0/24 `
  -VirtualNetwork $virtualNetwork

$virtualNetwork | Set-AzVirtualNetwork


New-AzAppServicePlan -Name $aspname -Location $location -ResourceGroupName $rgName -Tier "Standard"

$webapp1 = New-AzWebApp -Name "$webappname-$(Get-Random)" -Location $location -AppServicePlan $aspname -ResourceGroupName $rgName
$webapp2 = New-AzWebApp -Name "$webappname-$(Get-Random)" -Location $location -AppServicePlan $aspname -ResourceGroupName $rgName



# Az Cli for vnet config with Webapps
Set-AzContext -SubscriptionId $subID
az account set --subscription $subID
az webapp vnet-integration add -g $rgName -n $webapp1.Name --vnet $vnetName --subnet $subnetName
az webapp vnet-integration add -g $rgName -n $webapp2.Name --vnet $vnetName --subnet $subnetName




# Create a unique name for front door 
$fdname = "frontend-$(Get-Random)"

#Create the frontend object
$FrontendEndObject = New-AzFrontDoorFrontendEndpointObject `
-Name "frontendEndpoint1" `
-HostName $fdname".azurefd.net"


# Create backend objects that points to the hostname of the web apps
$backendObject1 = New-AzFrontDoorBackendObject `
-Address $webapp1.DefaultHostName

$backendObject2 = New-AzFrontDoorBackendObject `
-Address $webapp2.DefaultHostName

# Create a health probe object
$HealthProbeObject = New-AzFrontDoorHealthProbeSettingObject `
-Name "HealthProbeSetting"

# Create the load balancing setting object
$LoadBalancingSettingObject = New-AzFrontDoorLoadBalancingSettingObject `
-Name "Loadbalancingsetting" `
-SampleSize "4" `
-SuccessfulSamplesRequired "2" `
-AdditionalLatencyInMilliseconds "0"

# Create a backend pool using the backend objects, health probe, and load balancing settings
$BackendPoolObjectA = New-AzFrontDoorBackendPoolObject `
-Name "myBackendPoolA" `
-FrontDoorName $fdname `
-ResourceGroupName $rgName `
-Backend $backendObject1 `
-HealthProbeSettingsName "HealthProbeSetting" `
-LoadBalancingSettingsName "Loadbalancingsetting"

$BackendPoolObjectB = New-AzFrontDoorBackendPoolObject `
-Name "myBackendPoolB" `
-FrontDoorName $fdname `
-ResourceGroupName $rgName `
-Backend $backendObject2 `
-HealthProbeSettingsName "HealthProbeSetting" `
-LoadBalancingSettingsName "Loadbalancingsetting"


# Create a routing rule mapping the frontend host to the backend pool
$RoutingRuleObjectA = New-AzFrontDoorRoutingRuleObject `
-Name RuleA `
-FrontDoorName $fdname `
-ResourceGroupName $rgName `
-FrontendEndpointName "frontendEndpoint1" `
-BackendPoolName "myBackendPoolA" `
-PatternToMatch "/*"

$RoutingRuleObjectB = New-AzFrontDoorRoutingRuleObject `
-Name RuleB `
-FrontDoorName $fdname `
-ResourceGroupName $rgName `
-FrontendEndpointName "frontendEndpoint1" `
-BackendPoolName "myBackendPoolB" `
-PatternToMatch "/appb/*" `
-CustomForwardingPath "/"


New-AzFrontDoor `
-Name $fdname `
-ResourceGroupName $rgName `
-RoutingRule $RoutingRuleObjectA,$RoutingRuleObjectB `
-BackendPool $BackendPoolObjectA,$BackendPoolObjectB `
-FrontendEndpoint $FrontendEndObject `
-LoadBalancingSetting $LoadBalancingSettingObject `
-HealthProbeSetting $HealthProbeObject