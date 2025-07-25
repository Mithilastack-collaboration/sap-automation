# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#######################################4#######################################8
#                                                                              #
#                       Web NSG - Check if locally provided                    #
#                                                                              #
#######################################4#######################################8

# Creates SAP web subnet nsg
resource "azurerm_network_security_group" "nsg_web" {
  provider                             = azurerm.main
  count                                = local.enable_deployment ? (var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists_in_workload ? 0 : 1) : 0
  name                                 = local.web_subnet_nsg_name
  resource_group_name                  = var.options.nsg_asg_with_vnet ? (
                                           var.network_resource_group) : (
                                           var.resource_group[0].name
                                         )
  location                             = var.options.nsg_asg_with_vnet ? (
                                           var.network_location) : (
                                           var.resource_group[0].location
                                         )
}

# Imports the SAP web subnet nsg data
data "azurerm_network_security_group" "nsg_web" {
  provider                             = azurerm.main
  count                                = local.enable_deployment ? (var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists_in_workload ? 1 : 0) : 0
  name                                 = split("/", coalesce(var.infrastructure.virtual_networks.sap.subnet_web.nsg.id, var.infrastructure.virtual_networks.sap.subnet_web.nsg.id_in_workload))[8]
  resource_group_name                  = split("/", coalesce(var.infrastructure.virtual_networks.sap.subnet_web.nsg.id, var.infrastructure.virtual_networks.sap.subnet_web.nsg.id_in_workload))[4]
}

# Associates SAP web nsg to SAP web subnet
resource "azurerm_subnet_network_security_group_association" "Associate_nsg_web" {
  provider                             = azurerm.main
  depends_on                           = [azurerm_subnet.subnet_sap_web]
  count                                = local.enable_deployment ? (var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists_in_workload ? 0 : 1) : 0
  subnet_id                            = var.infrastructure.virtual_networks.sap.subnet_web.exists ? (
                                           data.azurerm_subnet.subnet_sap_web[0].id) : (
                                           azurerm_subnet.subnet_sap_web[0].id
                                         )
  network_security_group_id            = azurerm_network_security_group.nsg_web[0].id
}

# NSG rule to deny internet access
resource "azurerm_network_security_rule" "webRule_internet" {
  provider                             = azurerm.main
  count                                = local.enable_deployment ? (var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_web.nsg.exists_in_workload ? 0 : 1) : 0
  name                                 = "Internet"
  priority                             = 100
  direction                            = "Inbound"
  access                               = "Deny"
  protocol                             = "*"
  source_address_prefix                = "Internet"
  source_port_range                    = "*"
  destination_address_prefixes         = var.infrastructure.virtual_networks.sap.subnet_web.exists ? (
                                             data.azurerm_subnet.subnet_sap_web[0].address_prefixes) : (
                                             azurerm_subnet.subnet_sap_web[0].address_prefixes
                                         )
  destination_port_range               = "*"
  resource_group_name                  = var.options.nsg_asg_with_vnet ? (
                                           var.network_resource_group) : (
                                           var.resource_group[0].name
                                         )
  network_security_group_name          = azurerm_network_security_group.nsg_web[0].name
}

/*
   Comment out this nsg rule temporarily, because of peering between vnet-mgmt and vnet_sap, mgmt-subnet can access subnet-web by default.
# NSG rule to open ports for Web dispatcher
resource "azurerm_network_security_rule" "web" {
  count                        = local.enable_deployment ? (local.web_subnet_nsg_exists ? 0 : length(local.nsg-ports.web)) : 0
  name                         = local.nsg-ports.web[count.index].name
  priority                     = local.nsg-ports.web[count.index].priority
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_address_prefixes      = var.subnet-mgmt.address_prefixes
  source_port_range            = "*"
  destination_address_prefixes = local.web_subnet_deployed.address_prefixes
  destination_port_range       = local.nsg-ports.web[count.index].port
  resource_group_name          = var.resource_group[0].name
  network_security_group_name  = local.web_subnet_nsg_deployed.name
}
*/
