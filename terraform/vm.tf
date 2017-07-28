########################## VM AVAILABILITY SETs
resource "azurerm_availability_set" "masterVMAvailSet" {
    name                = "dcosMasterVmAvailSet"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    managed             = true
}

resource "azurerm_availability_set" "publicAgentVMAvailSet" {
    name                = "dcosPublicAgentVmAvailSet"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    managed             = true
}

resource "azurerm_availability_set" "privateAgentVMAvailSet" {
    name                = "dcosPrivateAgentVmAvailSet"
    location            = "${azurerm_resource_group.dcos.location}"
    resource_group_name = "${azurerm_resource_group.dcos.name}"
    managed             = true
}
