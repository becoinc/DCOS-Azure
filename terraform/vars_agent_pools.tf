#
# This is a terraform script to set variables for large private agents.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created July-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

variable "agent_private_large_size" {
    default = "Standard_D8s_v3"
}

variable "agent_private_large_count" {
    default     = 2
    description = "The number of large private agent VMs."
}


