#
# This is a terraform script to declare outputs from the DC/OS module.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

output "Resource_Group_Name" {
  value = "${azurerm_resource_group.dcos.name}"
}

output "Resource_Group_Location" {
  value = "${azurerm_resource_group.dcos.location}"
}

output "Storage_Account_Name" {
  value = "${azurerm_storage_account.dcos.name}"
}

output "Account_Blob_Endpoint" {
  value = "${azurerm_storage_account.dcos.primary_blob_endpoint}"
}

output "Virtual_Network_Name" {
  value = "${azurerm_virtual_network.dcos.name}"
}

output "Master_Load_Balancer_IP" {
  value = "${azurerm_public_ip.master_lb.ip_address}"
}

output "Public_Agent_Load_Balancer_IP" {
  value = "${azurerm_public_ip.agent_public_lb.ip_address}"
}

output "Public_Agent_Load_Balancer_FQDN" {
  value = "${azurerm_public_ip.agent_public_lb.fqdn}"
}

output "Boostrap_Node_Public_IP" {
  value = "${azurerm_public_ip.dcosBootstrapNodePublicIp.ip_address}"
}

output "Primary_Access_Key" {
  value = "${azurerm_storage_account.dcos.primary_access_key}"
}

# This is output so you can hook on to it and add "special" new agent nodes
# to the existing subnet.
output "private_agent_subnet" {
  value = "${azurerm_subnet.dcosprivate.id}"
}

# This is the output for the management subnet.
output "management_subnet" {
  value = "${azurerm_subnet.dcosMgmt.id}"
}
