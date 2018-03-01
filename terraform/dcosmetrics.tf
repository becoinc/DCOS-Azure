#
# This is a terraform script to provision the DC/OS prometheus metrics.
#
# Copyright (c) 2017 by Beco, Inc. All rights reserved.
#
# Created 2-Dec-2017 by Jeffrey Zampieron <jeff@beco.io>
#
# License: See included LICENSE.md
#

resource "null_resource" "dcos_metrics_prometheus_master" {

    depends_on = [
        "azurerm_virtual_machine.master"
    ]

    count = "${var.master_count}"

    connection {
        type         = "ssh"
        host         = "${element( azurerm_network_interface.master.*.private_ip_address, count.index )}"
        user         = "${var.vm_user}"
        timeout      = "120s"
        private_key  = "${file(var.private_key_path)}"
        # Configuration for the Jumpbox
        bastion_host        = "${azurerm_public_ip.dcosBootstrapNodePublicIp.ip_address}"
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
        source      = "${path.module}/files/dcos-metrics-prometheus.env"
        destination = "/opt/dcos/dcos-metrics-prometheus.env"
    }

    provisioner "file" {
        source      = "${path.module}/files/dcos-metrics-prometheus-master.service"
        destination = "/opt/dcos/dcos-metrics-prometheus-master.service"
    }

    provisioner "file" {
        source      = "${path.module}/files/dcos-metrics-prometheus-plugin_1.10.2"
        destination = "/opt/dcos/dcos-metrics-prometheus-plugin"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo mv /opt/dcos/dcos-metrics-prometheus.env /opt/mesosphere/etc",
            "sudo mv /opt/dcos/dcos-metrics-prometheus-master.service /etc/systemd/system",
            "sudo mv /opt/dcos/dcos-metrics-prometheus-plugin /opt/mesosphere/bin",
            "sudo chmod 755 /opt/mesosphere/bin/dcos-metrics-prometheus-plugin",
            "sudo systemctl daemon-reload",
            "sudo systemctl start dcos-metrics-prometheus-master"
        ]
    }

}

resource "null_resource" "dcos_metrics_prometheus_public" {

    depends_on = [
        "azurerm_virtual_machine.dcosPublicAgent"
    ]

    count = "${azurerm_virtual_machine.dcosPublicAgent.count}"

    connection {
        type         = "ssh"
        host         = "${element( azurerm_network_interface.dcosPublicAgentIF0.*.private_ip_address, count.index )}"
        user         = "${var.vm_user}"
        timeout      = "120s"
        private_key  = "${file(var.private_key_path)}"
        # Configuration for the Jumpbox
        bastion_host        = "${azurerm_public_ip.dcosBootstrapNodePublicIp.ip_address}"
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
        source      = "${path.module}/files/dcos-metrics-prometheus.env"
        destination = "/opt/dcos/dcos-metrics-prometheus.env"
    }

    provisioner "file" {
        source      = "${path.module}/files/dcos-metrics-prometheus-agent.service"
        destination = "/opt/dcos/dcos-metrics-prometheus-agent.service"
    }

    provisioner "file" {
        source      = "${path.module}/files/dcos-metrics-prometheus-plugin_1.10.2"
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

resource "null_resource" "dcos_metrics_prometheus_private" {

    depends_on = [
        "azurerm_virtual_machine.dcosPrivateAgent"
    ]

    count = "${azurerm_virtual_machine.dcosPrivateAgent.count}"

    connection {
        type         = "ssh"
        host         = "${element( azurerm_network_interface.dcosPrivateAgentIF0.*.private_ip_address, count.index )}"
        user         = "${var.vm_user}"
        timeout      = "120s"
        private_key  = "${file(var.private_key_path)}"
        # Configuration for the Jumpbox
        bastion_host        = "${azurerm_public_ip.dcosBootstrapNodePublicIp.ip_address}"
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
        source      = "${path.module}/files/dcos-metrics-prometheus.env"
        destination = "/opt/dcos/dcos-metrics-prometheus.env"
    }

    provisioner "file" {
        source      = "${path.module}/files/dcos-metrics-prometheus-agent.service"
        destination = "/opt/dcos/dcos-metrics-prometheus-agent.service"
    }

    provisioner "file" {
        source      = "${path.module}/files/dcos-metrics-prometheus-plugin_1.10.2"
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
