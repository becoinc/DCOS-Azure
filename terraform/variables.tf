variable "instance_name" {
    type        = "string"
    default     = "dev"
    description = "An instance name used to identify this setup. Typically, dev, staging or production."
}

variable "azure_resource_group" {}

variable "resource_base_name" {}

variable "resource_suffix" {}

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

variable "azure_region" {}

variable "owner" {}

variable "expiration" {}

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

/* Masters */
variable "master_count" {
    default     = 5
    description = <<EOF
    The number of DC/OS master nodes.
    Must be 1, 3 or 5. Do not use 1 for a real cluster.
    If you change this number to something other than 5,
    you must also change the bootstrap.sh script master_list
    to reflect that proper IP list.
EOF
}

variable "master_port" {
    default = {
        "1" = 2200
        "2" = 2201
        "3" = 2202
        "4" = 2203
        "5" = 2204
        "6" = 2205
        "7" = 2206
        "8" = 2207
        "9" = 2208
        "10" = 2209
    }
}

/* Agents */

variable "publicAgentFQDN" {}

/* Bootstrap */
variable "bootstrap_size" {
    default = "Standard_A2"
}

variable "bootstrap_private_ip_address_index" {
    default = "8"
}

variable "master_size" {
    default = "Standard_D2_v2_Promo"
}

variable "master_private_ip_address_index" {
    default = "10"
}

variable "masterFQDN" {
    default = "mastervip"
}

variable "agent_private_count" {
    default     = 6
    description = "The number of private agent VMs."
}

variable os_disk_size {
    default = 64
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

variable px_journal_disk_size {
    default = 512
    description = "The size in GB of the Attached Portworx Journal Disk - Only Private Agents have this data disk."
}

variable "agent_private_size" {
    default = "Standard_D2_v2_Promo"
}

/* Public Agents */
variable "agent_public_count" {
    default = 2
}

variable "agent_public_size" {
    default = "Standard_D2_v2_Promo"
}

variable "portworx_cluster_id" {
    type        = "string"
    description = "The UUID of the Portworx Cluster."
}

variable "portworx_license_key" {
    type        = "string"
    description = "The License Key for the Portworx Cluster."
}
