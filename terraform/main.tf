#
# This is a terraform script to provision the DC/OS basic resources.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

/*
  JZ - We don't allow terraforming the actual resource group
  because that's the permssions control unit, but other
  users may choose to allow this.
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

resource "azurerm_storage_container" "dcos" {
  name                  = "dcos1dot9"
  resource_group_name   = "${azurerm_resource_group.dcos.name}"
  storage_account_name  = "${azurerm_storage_account.dcos.name}"
  container_access_type = "private"
}
