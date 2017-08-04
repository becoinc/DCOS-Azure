# This file contains dev instance specific variables for Terraform
# This is a smaller, lower cost cluster than our staging or production clusters
instance_config = {
   # ------------------------------------------------------
   /* Parameters for all modules */
   # ------------------------------------------------------
   instance_name        = "dev"
   # The Azure Region where the cluster is created.
   # See: http://azure.microsoft.com/en-us/regions/
   azure_region         = "East US"

   # ------------------------------------------------------
   /* Parameters for DC/OS module */
   # ------------------------------------------------------
   # You must manually pre-create a resource group for the DC/OS cluster
   # and assign appropriate permssions to a service Principal
   azure_resource_group    = "my_dev_dcos"
   vm_user                 = "my-dev-user"
   # Normally you'll want to separate these out... and tightly control them
   # What you do is then put per-user key pairs on the jumpbox
   # so they can access what they need to and its still revokable.
   bootstrap_private_key_path = "./instance_cfg/dev.ssh_private"
   bootstrap_public_key_path  = "./instance_cfg/dev.ssh_public"
   private_key_path        = "./instance_cfg/dev.ssh_private"
   public_key_path         = "./instance_cfg/dev.ssh_public"
   # Only 5 is valid here.
   master_count            = 5
   /*
      typically we use DS12_v2 size, but you can down size for
      small clusters ... or lightly loaded clusters.
   */
   /* Standard_DS12_v2 - 4 Core, 28G Ram, 57G HDD - Promo Price $0.266/hr */
   /* Standard_DS11_v2 - 2 Core, 14G Ram, 100G HDD - Promo Price $0.133/hr */
   master_size          = "Standard_DS11_v2_Promo"
   publicAgentFQDN      = "pub-agent"
   agent_private_count  = 3
   /* Standard_DS12_v2 - 4 Core, 28G Ram, 57G HDD - Promo Price $0.266/hr */
   /* Standard_DS13_v2_Promo - 8 core, 56G ram, 400GB SSD - Promo Price $0.532/hr */
   agent_private_size   = "Standard_DS12_v2_Promo"
   agent_public_count   = 1
   /* Standard_DS11_v2 - 2 Core, 14G Ram, 100G HDD - Promo Price $0.133/hr */
   agent_public_size    = "Standard_DS11_v2_Promo"

}
