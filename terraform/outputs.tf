output "Resource Group Name" {
  value = "${azurerm_resource_group.dcos.name}"
}

output "Resource Group Location" {
  value = "${azurerm_resource_group.dcos.location}"
}

output "Storage Account Name" {
  value = "${azurerm_storage_account.dcos.name}"
}

output "Account Blob Endpoint" {
  value = "${azurerm_storage_account.dcos.primary_blob_endpoint}"
}

output "Virtual Network Name" {
  value = "${azurerm_virtual_network.dcos.name}"
}

output "Master Load Balancer IP" {
  value = "${azurerm_public_ip.master_lb.ip_address}"
}

output "Public Agent Load Balancer IP" {
  value = "${azurerm_public_ip.agent_public_lb.ip_address}"
}

output "Public Agent Load Balancer FQDN" {
  value = "${azurerm_public_ip.agent_public_lb.fqdn}"
}

output "Boostrap Node Public IP" {
  value = "${azurerm_public_ip.dcosBootstrapNodePublicIp.ip_address}"
}

output "Primary Access Key" {
  value = "${azurerm_storage_account.dcos.primary_access_key}"
}
