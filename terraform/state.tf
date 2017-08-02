#
# This is a terraform script to provision the DC/OS state storage.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

/*
  JZ - We don't allow terraforming the actual resource group
  because that's the permssions control unit
 */
resource "azurerm_resource_group" "dcos" {
  name     = "${var.azure_resource_group}"
  location = "${var.azure_region}"

  tags {
    owner = "${var.owner}"
    expiration = "${var.expiration}"
  }

  lifecycle {
     prevent_destroy = true
  }
}

resource "azurerm_storage_account" "dcos" {
  name                = "${replace("sa${var.resource_base_name}${var.resource_suffix}","_",0)}"
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  location            = "${azurerm_resource_group.dcos.location}"
  account_type        = "Standard_LRS"
}

resource "azurerm_storage_container" "state" {
  name                  = "terraform-state"
  resource_group_name   = "${azurerm_resource_group.dcos.name}"
  storage_account_name  = "${azurerm_storage_account.dcos.name}"
  container_access_type = "private"
}

/*
 * This is a storage account for putting the Linux Azure Diagnostics
 * JZ - On HOLD b/c of Terraform missing SAS generation feature.
 */
 /*
resource "azurerm_storage_account" "dcosAzureLinuxDiag" {
  name                = "${replace("dcosAzureLinuxDiag${var.resource_base_name}${var.resource_suffix}","_",0)}"
  resource_group_name = "${azurerm_resource_group.dcos.name}"
  location            = "${azurerm_resource_group.dcos.location}"
  account_type        = "Standard_LRS"

  tags = {
    environment = "${var.instance_name}"
  }
}
*/
