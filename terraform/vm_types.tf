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

/**
 * Define accelerated networking support by VM size.
 */
variable "vm_type_to_an" {
    type = "map"

    /* From: https://docs.microsoft.com/en-us/azure/virtual-network/create-vm-accelerated-networking-cli */
    default = {
        Standard_B4ms    = "false"
        Standard_D8_v3   = "true"
        Standard_D16_v3  = "true"
        Standard_D32_v3  = "true"
        Standard_D64_v3  = "true"
        Standard_D8s_v3  = "true"
        Standard_D16s_v3 = "true"
        Standard_D32s_v3 = "true"
        Standard_D64s_v3 = "true"
        Standard_E8_v3   = "true"
        Standard_E16_v3  = "true"
        Standard_E32_v3  = "true"
        Standard_E64_v3  = "true"
        Standard_E8s_v3  = "true"
        Standard_E16s_v3 = "true"
        Standard_E32s_v3 = "true"
        Standard_E64s_v3 = "true"
        Standard_F8s_v2  = "true"
        Standard_F16s_v2 = "true"
        Standard_F32s_v2 = "true"
        Standard_F64s_v2 = "true"
        Standard_F72s_v2 = "true"
        Standard_F8s     = "true"
        Standard_F16s    = "true"
        Standard_F8      = "true"
        Standard_F16     = "true"
        Standard_M64s    = "true"
        Standard_M64ms   = "true"
        Standard_M128s   = "true"
        Standard_M128ms  = "true"
    }
}