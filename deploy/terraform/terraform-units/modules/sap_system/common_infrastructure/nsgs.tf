# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

/*-----------------------------------------------------------------------------8
|                                                                              |
|                                 NSG                                   |
|                                                                              |
+--------------------------------------4--------------------------------------*/

# Creates SAP db subnet nsg
resource "azurerm_network_security_group" "db" {
  provider                             = azurerm.main
  count                                = local.enable_db_deployment ? (var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists ? 0 : 1) : 0
  name                                 = local.database_subnet_nsg_name
  resource_group_name                  = var.options.nsg_asg_with_vnet ? (
                                           data.azurerm_virtual_network.vnet_sap.resource_group_name) : (
                                           local.resource_group_exists ? (
                                             data.azurerm_resource_group.resource_group[0].name) : (
                                             azurerm_resource_group.resource_group[0].name
                                           )
                                         )
  location                             = var.options.nsg_asg_with_vnet ? (
                                           data.azurerm_virtual_network.vnet_sap.location) : (
                                           local.resource_group_exists ? (
                                             data.azurerm_resource_group.resource_group[0].location) : (
                                             azurerm_resource_group.resource_group[0].location
                                           )
                                         )
  tags                                 = var.tags
}

# Imports the SAP db subnet nsg data
data "azurerm_network_security_group" "db" {
  provider                             = azurerm.main
  count                                = local.enable_db_deployment ? (var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists ? 1 : 0) : 0
  name                                 = local.database_subnet_nsg_name
  resource_group_name                  = split("/", coalesce(var.infrastructure.virtual_networks.sap.subnet_db.nsg.id, var.infrastructure.virtual_networks.sap.subnet_db.nsg.id_in_workload))[4]
}

# Associates SAP db nsg to SAP db subnet
resource "azurerm_subnet_network_security_group_association" "db" {
  provider                             = azurerm.main
  count                                = local.enable_db_deployment ? (var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists_in_workload ? 0 : 1) : 0
  subnet_id                            = azurerm_subnet.db[0].id
  network_security_group_id            = azurerm_network_security_group.db[0].id
}

# Creates SAP admin subnet nsg
resource "azurerm_network_security_group" "admin" {
  provider                             = azurerm.main
  count                                = local.enable_admin_subnet ? (var.infrastructure.virtual_networks.sap.subnet_admin.nsg.exists ? 0 : 1) : 0
  name                                 = local.admin_subnet_nsg_name
  resource_group_name                  = var.options.nsg_asg_with_vnet ? (
                                           data.azurerm_virtual_network.vnet_sap.resource_group_name) : (
                                           local.resource_group_exists ? (
                                             data.azurerm_resource_group.resource_group[0].name) : (
                                             azurerm_resource_group.resource_group[0].name
                                           )
                                         )
  location                             = var.options.nsg_asg_with_vnet ? (
                                           data.azurerm_virtual_network.vnet_sap.location) : (
                                           local.resource_group_exists ? (
                                             data.azurerm_resource_group.resource_group[0].location) : (
                                             azurerm_resource_group.resource_group[0].location
                                           )
                                         )
  tags                                 = var.tags
}

// Imports the SAP admin subnet nsg data
data "azurerm_network_security_group" "admin" {
  provider                             = azurerm.main
  count                                = local.enable_admin_subnet ? (var.infrastructure.virtual_networks.sap.subnet_admin.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_admin.nsg.exists_in_workload ? 1 : 0) : 0
  name                                 = local.admin_subnet_nsg_name
  resource_group_name                  = split("/", coalesce(var.infrastructure.virtual_networks.sap.subnet_admin.nsg.id, var.infrastructure.virtual_networks.sap.subnet_admin.nsg.id_in_workload))[4]
}

// Associates SAP admin nsg to SAP admin subnet
resource "azurerm_subnet_network_security_group_association" "admin" {
  provider                             = azurerm.main
  count                                = local.enable_admin_subnet ? (var.infrastructure.virtual_networks.sap.subnet_admin.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_admin.nsg.exists_in_workload ? 0 : 1) : 0
  subnet_id                            = azurerm_subnet.admin[0].id
  network_security_group_id            = azurerm_network_security_group.admin[0].id
}

# Creates network security rule to allow internal traffic for SAP db subnet
resource "azurerm_network_security_rule" "nsr_internal_db" {
  provider                             = azurerm.main
  count                                = local.enable_db_deployment ? (var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_admin.nsg.exists_in_workload ? 0 : 1) : 0
  name                                 = "allow-internal-traffic"
  resource_group_name                  = var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists ? (
                                           data.azurerm_network_security_group.db[0].resource_group_name) : (
                                           azurerm_network_security_group.db[0].resource_group_name
                                         )
  network_security_group_name          = azurerm_network_security_group.db[0].name
  priority                             = 101
  direction                            = "Inbound"
  access                               = "Allow"
  protocol                             = "Tcp"
  source_port_range                    = "*"
  destination_port_range               = "*"
  source_address_prefixes              = data.azurerm_virtual_network.vnet_sap.address_space
  destination_address_prefixes         = azurerm_subnet.db[0].address_prefixes
}

# Creates network security rule to deny external traffic for SAP db subnet
# ToDo: Check if this rule is needed
resource "azurerm_network_security_rule" "nsr_external_db" {
  provider                             = azurerm.main
  count                                = local.enable_db_deployment ? (var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists || var.infrastructure.virtual_networks.sap.subnet_admin.nsg.exists_in_workload ? 0 : 0) : 0
  name                                 = "deny-inbound-traffic"
  resource_group_name                  = var.infrastructure.virtual_networks.sap.subnet_db.nsg.exists ? (
                                           data.azurerm_network_security_group.db[0].resource_group_name) : (
                                           azurerm_network_security_group.db[0].resource_group_name
                                         )
  network_security_group_name          = azurerm_network_security_group.db[0].name
  priority                             = 102
  direction                            = "Inbound"
  access                               = "Deny"
  protocol                             = "Tcp"
  source_port_range                    = "*"
  destination_port_range               = "*"
  source_address_prefix                = "*"
  destination_address_prefixes         = azurerm_subnet.db[0].address_prefixes
}
