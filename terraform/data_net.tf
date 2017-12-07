#
# This is a terraform script to control the cluster networking.
#
# Here we configure the subnet for the storage data plane.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created Sept-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

resource "azurerm_network_security_group" "dcosstoragedata" {
    name                = "dcos-storagedata-nsg"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
}

resource "azurerm_subnet" "dcosStorageData" {
    name                      = "dcos-agentStorageDataSubnet"
    resource_group_name       = "${azurerm_resource_group.dcos.name}"
    virtual_network_name      = "${azurerm_virtual_network.dcos.name}"
    network_security_group_id = "${azurerm_network_security_group.dcosstoragedata.id}"
    address_prefix            = "10.96.0.0/11"
}

