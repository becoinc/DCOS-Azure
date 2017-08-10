#
# This is a terraform script to control per VM type configuration.
#
# e.g. A Standard_A1_v2 can't accept Premium_LRS
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

/* Looks up a Disk type for OS Disks based on the VM type. */
variable "vm_type_to_os_disk_type" {
  type    = "map"
  default = {
    Standard_A1_v2         = "Standard_LRS",
    Standard_D2s_v3        = "Premium_LRS",
    Standard_DS2_v2_Promo  = "Premium_LRS",
    Standard_DS11_v2_Promo = "Premium_LRS"
  }
}
