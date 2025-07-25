# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#######################################4#######################################8
#                                                                              #
#              Firewall subnet - Check if locally provided                     #
#                                                                              #
#######################################4#######################################8
resource "azurerm_subnet" "firewall" {
  count                                      = var.firewall.deployment && !var.infrastructure.virtual_network.management.subnet_firewall.exists ? 1 : 0
  name                                       = local.firewall_subnet_name
  address_prefixes                           = [var.infrastructure.virtual_network.management.subnet_firewall.prefix]
  resource_group_name                        = var.infrastructure.virtual_network.management.exists ? (
                                                 data.azurerm_virtual_network.vnet_mgmt[0].resource_group_name) : (
                                                 azurerm_virtual_network.vnet_mgmt[0].resource_group_name
                                               )
  virtual_network_name                       = var.infrastructure.virtual_network.management.exists ? (
                                                 data.azurerm_virtual_network.vnet_mgmt[0].name) : (
                                                 azurerm_virtual_network.vnet_mgmt[0].name
                                               )
}

data "azurerm_subnet" "firewall" {
  count                                      = var.firewall.deployment && var.infrastructure.virtual_network.management.subnet_firewall.exists ? 1 : 0
  name                                       = split("/", var.infrastructure.virtual_network.management.subnet_firewall.id)[10]
  resource_group_name                        = split("/", var.infrastructure.virtual_network.management.subnet_firewall.id)[4]
  virtual_network_name                       = split("/", var.infrastructure.virtual_network.management.subnet_firewall.id)[8]
}

resource "azurerm_public_ip" "firewall" {
  count                                      = var.firewall.deployment ? 1 : 0
  name                                       = format("%s%s%s%s%s",
                                                 var.naming.resource_prefixes.pip,
                                                 local.prefix,
                                                 var.naming.separator,
                                                 "firewall",
                                                 var.naming.resource_suffixes.pip
                                               )
  allocation_method                          = "Static"
  sku                                        = "Standard"

  location                                   = var.infrastructure.virtual_network.management.exists ? (
                                                 data.azurerm_virtual_network.vnet_mgmt[0].location) : (
                                                 azurerm_virtual_network.vnet_mgmt[0].location
                                               )

  resource_group_name                        = var.infrastructure.virtual_network.management.exists ? (
                                                 data.azurerm_virtual_network.vnet_mgmt[0].resource_group_name) : (
                                                 azurerm_virtual_network.vnet_mgmt[0].resource_group_name
                                               )
  zones                                      = lower(var.infrastructure.region) == "eastus2euap" ? ["1","2","3","4"] : ["1","2","3"]
  ip_tags                                    = try(length(var.firewall.ip_tags) > 0 ? (
                                                 var.firewall.ip_tags) : (
                                                 null
                                               ), null)
  lifecycle                                  {
                                                create_before_destroy = true
                                             }

  tags                                       =  var.infrastructure.tags
}

resource "azurerm_firewall" "firewall" {
  count                                      = var.firewall.deployment ? 1 : 0
  name                                       = format("%s%s%s%s",
                                                var.naming.resource_prefixes.firewall,
                                                local.prefix,
                                                var.naming.separator,
                                                var.naming.resource_suffixes.firewall
                                              )
  sku_tier                                   = "Standard"
  sku_name                                   = "AZFW_VNet"
  resource_group_name                        = var.infrastructure.resource_group.exists ? (
                                                 data.azurerm_resource_group.deployer[0].name) : (
                                                 azurerm_resource_group.deployer[0].name
                                               )
  location                                   = var.infrastructure.resource_group.exists ? (
                                                 data.azurerm_resource_group.deployer[0].location) : (
                                                 azurerm_resource_group.deployer[0].location
                                               )

  ip_configuration                             {
                                                 name                 = "ipconfig1"
                                                 subnet_id            = var.infrastructure.virtual_network.management.subnet_firewall.exists ? (
                                                                          data.azurerm_subnet.firewall[0].id) : (
                                                                          azurerm_subnet.firewall[0].id
                                                                        )
                                                 public_ip_address_id = azurerm_public_ip.firewall[0].id
                                               }
  lifecycle                                    {
                                                  create_before_destroy = true
                                               }
  tags                                 = var.infrastructure.tags

}

//Route table
resource "azurerm_route_table" "rt" {
  count                                      = var.firewall.deployment ? 1 : 0
  name                                       = format("%s%s%s%s",
                                                 var.naming.resource_prefixes.routetable,
                                                 local.prefix,
                                                 var.naming.separator,
                                                 var.naming.resource_suffixes.routetable
                                               )
  bgp_route_propagation_enabled              = false
  resource_group_name                        = var.infrastructure.resource_group.exists ? (
                                                 data.azurerm_resource_group.deployer[0].name) : (
                                                 azurerm_resource_group.deployer[0].name
                                               )
  location                                   = var.infrastructure.resource_group.exists ? (
                                                 data.azurerm_resource_group.deployer[0].location) : (
                                                 azurerm_resource_group.deployer[0].location
                                               )
  tags                                 = var.infrastructure.tags
}

resource "azurerm_route" "admin" {
  count                                      = var.firewall.deployment && !var.infrastructure.virtual_network.management.subnet_firewall.exists ? 1 : 0
  name                                       = format("%s%s%s%s",
                                                 var.naming.resource_prefixes.fw_route,
                                                 local.prefix,
                                                 var.naming.separator,
                                                 var.naming.resource_suffixes.fw_route
                                               )
  route_table_name                           = azurerm_route_table.rt[0].name
  address_prefix                             = "0.0.0.0/0"
  next_hop_type                              = "VirtualAppliance"
  next_hop_in_ip_address                     = azurerm_firewall.firewall[0].ip_configuration[0].private_ip_address
  resource_group_name                        = var.infrastructure.resource_group.exists ? (
                                                 data.azurerm_resource_group.deployer[0].name) : (
                                                 azurerm_resource_group.deployer[0].name
                                               )
}

########################################################################################################
#
# Create a Azure Firewall Network Rule for Azure Management API and Outbound Internet
#
########################################################################################################

resource "random_integer" "priority" {
  min                                        = 3000
  max                                        = 3999
  keepers                                    = {
                                                 # Generate a new ID only when a new resource group is defined
                                                 resource_group = var.infrastructure.resource_group.exists ? (
                                                  data.azurerm_resource_group.deployer[0].name) : (
                                                  azurerm_resource_group.deployer[0].name
                                                )
                                               }
}

resource "azurerm_firewall_network_rule_collection" "firewall-azure" {
  count                                      = var.firewall.deployment ? 1 : 0
  name                                       = format("%s%s%s%s",
                                                 var.naming.resource_prefixes.firewall_rule_app,
                                                 local.prefix,
                                                 var.naming.separator,
                                                 var.naming.resource_suffixes.firewall_rule_app
                                               )
  azure_firewall_name                        = azurerm_firewall.firewall[0].name
  resource_group_name                        = var.infrastructure.resource_group.exists ? (
                                                 data.azurerm_resource_group.deployer[0].name) : (
                                                 azurerm_resource_group.deployer[0].name
                                               )
  priority                                   = random_integer.priority.result
  action                                     = "Allow"

  rule                                         {
                                                 name                  = "Azure-Cloud"
                                                 source_addresses      = ["*"]
                                                 destination_ports     = ["*"]
                                                 destination_addresses = [local.firewall_service_tags]
                                                 protocols             = ["Any"]
                                               }
  rule                                         {
                                                 name                  = "ToInternet"
                                                 source_addresses      = ["*"]
                                                 destination_ports     = ["*"]
                                                 destination_addresses = ["*"]
                                                 protocols             = ["Any"]
                                               }
  dynamic "rule"                               {
                                                 for_each = range(length(try(var.firewall.rule_subnets, [])) > 0 ? 1 : 0)
                                                 content {
                                                             name                  = "CustomSubnets"
                                                             source_addresses      = var.firewall.rule_subnets
                                                             destination_ports     = ["*"]
                                                             destination_addresses = ["*"]
                                                             protocols             = ["Any"]
                                                         }
                                               }

  dynamic "rule"                               {
                                                 for_each = range(length(try(var.firewall.allowed_ipaddresses, [])) > 0 ? 1 : 0)
                                                 content {
                                                             name                  = "CustomIpAddresses"
                                                             source_addresses      = var.firewall.allowed_ipaddresses
                                                             destination_ports     = ["*"]
                                                             destination_addresses = ["*"]
                                                             protocols             = ["Any"]
                                                         }
                                               }

}
