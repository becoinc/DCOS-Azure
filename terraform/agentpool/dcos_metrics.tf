#
# This is a terraform script to setup Ignition on the DC/OS private agent nodes.
#
# Copyright (c) 2018 by Beco, Inc. All rights reserved.
#
# Created Feb-2018 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

resource "null_resource" "dcos_metrics_prometheus" {

    depends_on = [
        "azurerm_virtual_machine.dcosPrivateAgent"
    ]

    count = "${var.agent_count}"

    connection {
        type         = "ssh"
        host         = "${azurerm_network_interface.dcosPrivateAgentPri.*.private_ip_address[ count.index ]}"
        user         = "${var.vm_user}"
        timeout      = "120s"
        private_key  = "${file(var.private_key_path)}"
        # Configuration for the Jumpbox
        bastion_host        = "${var.bastion_host_ip}"
        bastion_user        = "${var.vm_user}"
        bastion_private_key = "${file(var.bootstrap_private_key_path)}"
    }

    # provisioners execute in order.
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /opt/dcos",
            "sudo chown ${var.vm_user} /opt/dcos",
            "sudo chmod 755 -R /opt/dcos"
        ]
    }

    # Provision the files.
    provisioner "file" {
        source      = "${path.module}/../files/dcos-metrics-prometheus.env"
        destination = "/opt/dcos/dcos-metrics-prometheus.env"
    }

    provisioner "file" {
        source      = "${path.module}/../files/dcos-metrics-prometheus-agent.service"
        destination = "/opt/dcos/dcos-metrics-prometheus-agent.service"
    }

    provisioner "file" {
        source      = "${path.module}/../files/dcos-metrics-prometheus-plugin_1.10.2"
        destination = "/opt/dcos/dcos-metrics-prometheus-plugin"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo mv /opt/dcos/dcos-metrics-prometheus.env /opt/mesosphere/etc",
            "sudo mv /opt/dcos/dcos-metrics-prometheus-agent.service /etc/systemd/system",
            "sudo mv /opt/dcos/dcos-metrics-prometheus-plugin /opt/mesosphere/bin",
            "sudo chmod 755 /opt/mesosphere/bin/dcos-metrics-prometheus-plugin",
            "sudo systemctl daemon-reload",
            "sudo systemctl start dcos-metrics-prometheus-agent"
        ]
    }

}