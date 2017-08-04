#
# This is a terraform script to configure the terraform modules in the example.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

/*
 Declare the instance config for later override.
 In being consistent with our instance Configuration
 Each instance, i.e. dev, staging, production
 has its own configuration file for terraform with
 the relevant instance specific configuration parameters.

 This is used e.g. terraform plan -var-file=../../../instances/azure/dev/dev.tfvars
*/

provider "azurerm" {
  version = "~> 0.1"
}

provider "template" {
  version = "~> 0.1"
}

variable "instance_config" {
   type = "map"
   default = {}
}

module "dcos" {
   source = "../../terraform"
   # Configuration variables for DC/OS on Azure
   dcos_download_url    = "https://downloads.dcos.io/dcos/stable/1.9.2/dcos_generate_config.sh"
   resource_base_name   = "my_dcos_"
   resource_suffix      = "${var.instance_config["instance_name"]}"
   # We use the default stable for v1.9.1 right now.
   #dcos_download_url    = "https://downloads.dcos.io/dcos/stable/dcos_generate_config.sh"
   bootstrap_private_key_path = "${var.instance_config["bootstrap_private_key_path"]}"
   bootstrap_public_key_path  = "${var.instance_config["bootstrap_public_key_path"]}"
   private_key_path     = "${var.instance_config["private_key_path"]}"
   public_key_path      = "${var.instance_config["public_key_path"]}"
   vm_user              = "${var.instance_config["vm_user"]}"
   azure_resource_group = "${var.instance_config["azure_resource_group"]}"
   azure_region         = "${var.instance_config["azure_region"]}"
   owner                = ""
   expiration           = ""
   image                = {
      publisher = "CoreOS",
      offer     = "CoreOS",
      sku       = "Stable",
      version   = "1409.7.0"
   }
   /* Bootstrap - Recommented 2 Cores, 16G Ram, 60GB HDD */
   /* Standard D2 v2 -  2 Cores, 7G Ram, 100GB HDD - $0.1/hr */
   bootstrap_size      = "Standard_D2_v2_Promo"

   /* Masters - Recommended 4 Core, 32G Ram, 120G HDD */
   /* typically we use DS12_v2 size, but you can down size for small clusters */
   master_size          = "${var.instance_config["master_size"]}"

   /* Agents */
   publicAgentFQDN      = "${var.instance_config["publicAgentFQDN"]}"

   /* Private Agents */
   agent_private_count = "${var.instance_config["agent_private_count"]}"
   agent_private_size  = "${var.instance_config["agent_private_size"]}"

   /* Public Agents */
   agent_public_count  = "${var.instance_config["agent_public_count"]}"
   /*
      We typically use - Standard_DS12_v2 -
      4 Core, 28G Ram, 57G HDD - Promo Price $0.266/hr
   */
   agent_public_size   = "${var.instance_config["agent_public_size"]}"
}
/* End Module DCOS */
