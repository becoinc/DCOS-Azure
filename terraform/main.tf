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
    owner       = "${var.owner}"
    expiration  = "${var.expiration}"
    environment = "${var.instance_name}" 
  }

  lifecycle {
     prevent_destroy = true
  }
}
