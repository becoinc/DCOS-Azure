Deploy DC/OS 1.10.4 running CoreOS on Microsoft Azure using Terraform
==================

![](./resources/imgs/ninjaterracat.png)

This script allows you to deploy a DC/OS cluster on Microsoft Azure.

This repository is based on the initial work found in
[DCOS-Azure](https://github.com/julienstroheker/DCOS-Azure).

See [License](./LICENSE.md) for license terms and conditions.

# Introduction & Quick Start #

* Read this entire readme. You need to understand the project structure setup
herein. This will ensure the quickest path to success.

* This package is setup for a small, but production-ready
just works out of the box.
That means that it is _not_ the cheapest cluster configuration in terms of
VM size and/or VM count.

## Prereqs - Do this first ##

* It is assumed that you have a functioning Azure client installed. You can do so [here](https://github.com/Azure/azure-cli)

* Install [Terraform](https://www.terraform.io/downloads.html). This was
tested with `v0.11.1` on macOS Sierra. Using `v1.1.1` of the AzureRM provider.

* Create credentials for Terraform to access Azure.
To do so, you will need to following environment variables :

  * ARM_SUBSCRIPTION_ID=<subscription id>
  * ARM_CLIENT_ID=<client id>
  * ARM_CLIENT_SECRET=<cient secret>
  * ARM_TENANT_ID=<tenant id>

See [Azure CLI Setup](#setting-up-the-azure-cli-and-credentials) for full details.

* Ensure that your subscription and region have a sufficient CPU quota for
the size of the cluster you are creating. You can file an Azure helpdesk ticket
to get your quota increased.

## Dev/Deploy Environment Setup ##

This package is intended to be used as a [terraform module](https://www.terraform.io/docs/configuration/modules.html).

Modules are declared in a higher level project configuration, which is setup for
the particular deployment scenario. This allows the DC/OS terraform module
to function as just one piece of a more complicated multi-module cloud
infrastructure deployment.

* Setup a `main.tf` file that creates an instance of the DC/OS Azure module
with appropriate variables. See the `dcos_only` example project included herein.
This sets up a basic common configuration for how you want the cluster to operate.
Most of these variables can be overridden by a `tfvars` file.
The real purpose for this extra layer of abstraction is that this _project_
layer functions as a place to glue together multi-module systems in a convenient
place.

For example, we've used this setup to create a DC/OS cluster and then a
separate terraform module is also instantiated in the `main.tf` which is
used to create other hosted Azure services, such as Event Hubs and Data Lakes,
that form a full cloud system.

*Note:* You can get this terraform module directly from github without cloning
the whole repo. See the docs for [terraform get](https://www.terraform.io/docs/commands/get.html).

* Ensure your `main.tf` calls out compatible versions of the providers
for this module. See the example `main.tf` for the relevant provider blocks.

* Setup a `instancename.tfvars` file that overrides the appropriate project variables
for the particular instance you are creating. This allows you to have
different instances of your cluster for dev, staging, production, and
individual developers.

# Major changes from the original terraform script package.

* Switched from UMDs (unmanaged disks) to managed disks. This allows for the
option of Premium_LRS as a disk storage type. Also simplifies the terraform
scripting.
* Reorganized the file breakdown to separate more of the system elements.
* Switched from VMSS for the Public and Private agents to terraform
instantiated VMs, which allows for more flexibility in configuration of the
machines.
* Switched to terraform generated static IP addresses for predictable behavior
in terms of node names and addresses.
* Removed use of Azure VM Extensions for install and instead use the bootstrap
node as a bastion (jumpbox) host to provision using terraform `remote-exec`
instead. This leads to much more well documented provisioning behavior and
semantics. Specifically, terraform runs the provisioning
scripting only-once at creation. Azure VM Extensions require experimentation
to determine the idempotence requirements of your scripts.
* Add CoreOS ignition scripts to disable auto-reboot updates of the VMs. The
last thing anyone needs is a master node "randomly" resetting.
* Made sure to size the instance and disk defaults per the [dcos.io
recommended values](https://dcos.io/docs/1.9/installing/custom/system-requirements/),
with appropriate inline notes on size and costs.
* Added full example, more documentation and
a large number of inline notes on the configuration decision points and
reasoning behind the setup of the scripts and use of the variables.
* Bake in operational and management features, such as etcd, node Exporter
and cAdvisor.
* Make it possible to scope down the Azure Service Principal to just
the resource group for the DC/OS cluster and manually pre-create the
resource group and assign the IAM sp to apply principle of least privilege
to the Azure SP account. (Refer to [Azure RBAC documentation](https://docs.microsoft.com/en-us/azure/active-directory/role-based-access-control-configure).)

# TODO and Works in Progress #

- [ ] Setup Rexray so that you can attach Azure UMDs into the VMs.
- [ ] Use one of the created Azure Blob Storage Accounts to store the terraform state files.
- [ ] More documentation clean up.
- [ ] Packer has not been touched from the original and likely does not work.
- [ ] Better understanding/recovery handling for partial deployments.
- [ ] Support a number of masters other than 5 more cleanly.

# Contributing #

* Contributions welcome.
* We use Atom as our editor with soft tabs (i.e. spaces)
set to a width of *2* for the `.tf` files. Please follow this.

# Known Issues #

* If the deployment fails in the middle, depending on what was created, the
Azure load balancers may end up with empty rules. This manifests as a failure to
provision the masters via ssh as the LB won't route the traffic. Recovery can be
as simple as creating proper rules in the Azure UI. I've not been able to get
terraform to recreate them in the middle of a deployment in a way that works.
I believe this to be an Azure API side-effect or similar and not specifically
a terraform problem. More trials needed.

* Changing the number of masters requires editing of the bootstrap.sh script.
This really should be a parameter.

# Design Notes #

These machines are configured with a number of attached disks. These
are mostly tested with `Premium_SSDs`. The OS disks are assumed to be
on LUN0 and attached disks start after that.

Azure has a number of idiosyncrasies with its disk setup that make it
hard to get well-defined disk names early in the boot process. 

# Operations and Maintenance #

This section discusses running your cluster once it has been terraformed.

## Time Sync ##

Maintaining cluster time synchronization is a core requirement of DC/OS
and its components.
We _do not_ enable NTP and instead leave `systemd-timesync` enabled with the
understanding the Azure's VM hypervisor pushes down time on the nodes
by default.

## Orchestration ##

DC/OS uses zookeeper as a distributed, leader elected key-value store for
cluster management. Another popular one is [etcd](https://coreos.com/etcd/docs/latest/getting-started-with-etcd.html),
which is the CoreOS native distributed k-v store.
As the VMs for the cluster are using CoreOS, we've elected to install etcd by default
on each of the masters. This can facilitate things like rolling OS
updates with distributed locking (which we disable by default).

## Performance Monitoring ##

All the nodes, including the masters, run [cAdvisor](https://github.com/google/cadvisor) (port 63000)
and [Node Exporter](https://github.com/prometheus/node_exporter) (port 63001) by default
at the coreos level. Docker is set to automatically restart them if the
service dies.
This is to facilitate scraping with something like
[Prometheus](https://www.prometheus.io) for monitoring and metrics.

# Terraform Usage #

#### WARNING: Be sure that you are not overriding existing Azure resources that are in use. This Terraform process will create a resource group to contain all dependent resources within. This makes it easy to cleanup.

#### NOTE: This deployment is not meant to obviate the need to understand the install process or read the docs. Please spend some time to understand both [DC/OS](https://docs.mesosphere.com/1.9/overview/) and the [install process](https://docs.mesosphere.com/1.9/administration/installing/).

# Setting up the Azure CLI and Credentials
<a name="azure_cli"></a>

*NOTE:* This Service Principal has *complete* access to your entire Azure
subscription by default. We recommend that you scope down access to just
the appropriate resource groups.

* The values for the above environment variables can be obtained through the Azure CLI commands below.

*NOTE: A more detailed overview can be found on the [Terraform Site](https://www.terraform.io/docs/providers/azurerm/index.html)*

```bash
$ az login
```

* Run the following commands. This will print 2 lines, the first is the tenant ID and the second is the subscription ID.

```bash
$ az account show

{
  "environmentName": "AzureCloud",
  "id": "a97d7ca2-18ca-426f-b7c4-1a2cdaa4d9d1",
  "isDefault": true,
  "name": "My_Azure_Subscription",
  "state": "Enabled",
  "tenantId": "34a934ff-86a1-34af-34cd-2d7cd0134bd34",
  "user": {
    "name": "juliens@microsoft.com",
    "type": "user"
  }
}

export SUBSCRIPTIONID=`az account show --output tsv | cut -f2`

```

* Create an Azure application

```bash
$ export PASSWORD=`openssl rand -base64 24`

$ az ad app create --display-name dcosterraform--identifier-uris http://docs.mesosphere.com --homepage http://www.mesosphere.com --password $PASSWORD

$ unset PASSWORD
```

* Create A Service Principal

```bash
$ APPID=`az ad app list --display-name dcosterraform -o tsv --out tsv | grep dcos | cut -f1`

$ az ad sp create --id $APPID
```

* Grant Permissions To Your Application

```bash
$ az role assignment create --assignee http://docs.mesosphere.com --role "Owner" --scope /subscriptions/$SUBSCRIPTIONID

```

* Print the Client ID

```bash
$ az ad app list --display-name dcosterraform
```

*NOTE: A more detailed overview can be found on the [Terraform Site](https://www.terraform.io/docs/providers/azurerm/index.html)*

## Deploy the Azure infrastructure and DC/OS

* First, review the default configuratiion. Most common options are available in `terraform/dcos/terraform.tfvars`. The full list of available options are in `terraform/dcos/variables.tf`. CoreOS is the default as it has pre-requirements built in.

* Update `dcos/terraform.tfvars` with the path to your passwordless SSH public and private keys.

* Change `resource_suffix` (and optionally `resource_base_name`) to something unique

* Make sure that the `bootstrap_script_url`, `install_script_url` and `dcos_download_url` variables are updated with the correct public URL that you want to use.

* Optionally, customize the `agent_private_count` (default 10), the `agent_public_count` (default 1) and `master_count` for master (default 3), the agents size is Standard_D2_V2 per default, but you can change it for your need in  `dcos/variables.tf`.

* Create the DC/OS cluster by executing:
```bash
$ EXPORT ARM_SUBSCRIPTION_ID=<your subscription id>
$ EXPORT ARM_CLIENT_ID=<your client id>
$ EXPORT ARM_CLIENT_SECRET=<your cient secret>
$ EXPORT ARM_TENANT_ID=<your tenant id>

$ cd <repo>/terraform && terraform apply
```
### Connection to the cluster

* Initiate a SSH tunnel to `<masterVIP>.<location>.cloudapp.azure.com` and you should be able to reach the DC/OS UI.
```bash
$ sudo ssh core@<masterVIP>.<location>.cloudapp.azure.com -p 2200 -L 8080:localhost:443 -k <sshPrivateKey>
```
* The default username/password is `admin/Passw0rd`.

## ADDITIONAL ##

### Customize DC/OS Install ###

#### Default Security & Telemetry ####

Is off by default, that can be changed by modifying the `dcos/files/bootstrap.sh` file and following the install docs [here](https://docs.mesosphere.com/1.9/administration/installing/custom/advanced/)

### Cleanup ###

To restart and cleanup the Azure assets run the following commands from the <repo>/terraform directory

```bash
$ az group delete dcosterraform
info:    Executing command group delete
Delete resource group dcosterraform? [y/n] y
+ Deleting resource group dcosterraform                                        
info:    group delete command OK

$ cd <repo>/terraform && rm ./*/*terraform.tfstate && rm -rf ./*/.terraform*

```

### Troubleshooting ###

If the deployment gets in an inconsistent state (repeated `terraform apply` commands fail, or output references to leases that no longer exist), you may need to manually reconcile. Destroy the `<dcosterrform>` resource group, run `terraform remote config -disable` and delete all `terraform.tfstate*` files from `dcos`, follow the above instructions again.


# Baked your base image with Packer and Ansible

More to come
