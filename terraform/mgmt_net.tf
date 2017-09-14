#
# This is a terraform script to control the cluster networking.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created Sept-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

resource "azurerm_subnet" "dcosMgmt" {
    name                      = "dcos-agentMgmtSubnet"
    resource_group_name       = "${azurerm_resource_group.dcos.name}"
    virtual_network_name      = "${azurerm_virtual_network.dcos.name}"
    network_security_group_id = "${azurerm_network_security_group.dcosmgmt.id}"
    address_prefix            = "10.224.0.0/11"
}

resource "azurerm_network_security_group" "dcosmgmt" {
    name                = "dcos-mgmt-nsg"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
}
