#
# This is a terraform script to declare outputs from the DC/OS module.
#
# Copyright (c) 2018 by Beco, Inc. All rights reserved.
#
# Created 27-Feb-2018 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

variable "modname" {
    type        = "string"
    description = "The name of this module. Used to create various resources. Must be unique in the res group."
}

variable "mod_instance_id" {
    type        = "string"
    description = "A count of what instance number of this module this thing is. Used to compute subnet ips. Must be unique in your terraform code."
}

variable "agent_size" {
    type        = "string"
    default     = "Standard_D4s_v3"
    description = "The size of the VM for this agent pool."
}

variable "agent_count" {
    type = "string"
    description = "The number of agents in this pool."
}

variable "include_in_default_pool" {
    type        = "string"
    default     = "true"
    description = "Does the MESOS_ATTRIBUTE list include `agentpool:default`"
}

variable "extra_pool_names" {
    type        = "list"
    default     = []
    description = "Mesos Attributes: Converted to: agentpool:XXXX,agentpool:YYYY always include the 'name' as well."
}

//
variable "extra_attributes" {
    type        = "list"
    default     = []
    description = "Extra Mesos Attributes"
}

// ----------------------------------
// Deps from the main dcos module
// ----------------------------------
variable "bastion_host_ip" {
    type        = "string"
    description = "Public IP address of the Jumpbox."
}

variable "primary_subnet" {
    type        = "string"
    description = "The Azure subnet identifier of the primary subnet."
}

variable "secondary_subnet" {
    type        = "string"
    description = "The Azure subnet identifier of the secondary subnet."
}

variable "vnet_id" {
    type = "string"
    description = "The Azure identifier for the virtual network."
}

variable "vnet_name" {
    type        = "string"
    description = "The name of the virtual network."
}

variable "instance_name" {
    type        = "string"
    default     = "dev"
    description = "An instance name used to identify this setup. Typically, dev, staging or production."
}

variable "azure_region" {}

variable "azure_resource_group" {}

variable "resource_base_name" {}

# You can force a particular version:
# https://downloads.dcos.io/dcos/stable/1.9.2/dcos_generate_config.sh
variable "dcos_download_url" {
    type = "string"
    default = "https://downloads.dcos.io/dcos/stable/dcos_generate_config.sh"
}

variable "bootstrap_private_key_path" {
    description = "A separate SSH private key for the bootstrap node as a bastion host."
}

variable "bootstrap_public_key_path" {
    description = "A separate SSH public key for the bootstrap node as a bastion host."
}

variable "private_key_path" {}

variable "public_key_path" {}

variable "vm_user" {}

# You can get an exhaustive list of available images using the Azure CLI:
# az vm image list --offer CoreOS --all
variable "image" {
    type = "map"

    default = {
        publisher = "CoreOS"
        offer     = "CoreOS"
        sku       = "Stable"
        version   = "1465.7.0"
    }
}

/* Agents */

/**
 * We use a default P20 for the OS disk in order to get 2300 IOPS
 *
 * Otherwise logging and other system tasks that use small (4k)
 * block sizes seem to drag everything else down.
 *
 */
variable os_disk_size {
    default = 512
    description = "The size in GB of the Operating System Disks."
}

/**
 * Azure Managed Disks
 *
 * These are typically premium tier disks. Anything smaller than 512GB (P20)
 * will have pretty dismal performance for serious i/o loads.
 *
 * See https://docs.microsoft.com/en-us/azure/storage/common/storage-premium-storage
 *
 */
variable data_disk_size {
    default = 512
    description = "The size in GB of the Attached Data Disk. - Only Private Agents have this data disk."
}

variable io_offload_disk_size {
    default     = 128
    description = "The disk size used for disks which are attached to offload the os disk"
}

variable mesos_slave_disk_size {
    default     = 512
    description = "The disk size used for disks which are attached to offload the os disk - Mesos Slave path (/var/lib/mesos/slave)."
}

variable "boot_diag_blob_endpoint" {
    description = "The end point of the Azure storage account to store debug blobs."
}