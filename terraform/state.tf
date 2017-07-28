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
