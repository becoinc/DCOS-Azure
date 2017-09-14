{
  "ignition": {
    "version": "2.0.0",
    "config": {}
  },
  "storage": {
    "files" : [
      {
        "filesystem": "root",
        "path": "/etc/profile.env",
        "contents": {
          "source": "data:,export%20ENABLE_CHECK_TIME%3Dtrue",
          "verification": {}
        },
        "mode": 420,
        "user": {},
        "group": {}
      },
      {
        "filesystem": "root",
        "path": "/etc/hosts",
        "contents": {
            "source": "data:,127.0.0.1%09localhost%0A%3A%3A1%09%09localhost%0A${my_ip}%20${vm_hostname}%0A",
            "verification": {}
        },
        "mode": 420,
        "user": {},
        "group": {}
      }
    ]
  },
  "systemd": {
     "units": [
        {
          "name": "etcd-member.service",
          "enable": true,
          "dropins": [
            {
              "name": "20-clct-etcd-member.conf",
              "contents": "[Service]\nExecStart=\nExecStart=/usr/lib/coreos/etcd-wrapper $ETCD_OPTS \\\n  --name=\"${cluster_name}-etcd-${master_num}\" \\\n  --listen-peer-urls=\"https://${my_ip}:2380\" \\\n  --listen-client-urls=\"https://${my_ip}:2379\" \\\n  --initial-advertise-peer-urls=\"https://${my_ip}:2380\" \\\n  --initial-cluster=\"${cluster_name}-etcd-0=https://172.16.0.10:2380,${cluster_name}-etcd-1=https://172.16.0.11:2380,${cluster_name}-etcd-2=https://172.16.0.12:2380,${cluster_name}-etcd-3=https://172.16.0.13:2380,${cluster_name}-etcd-4=https://172.16.0.14:2380\" \\\n  --initial-cluster-state=\"new\" \\\n  --initial-cluster-token=\"${cluster_name}-etcd-token\" \\\n  --advertise-client-urls=\"https://${my_ip}:2379\" \\\n --auto-tls \\\n --peer-auto-tls \\\n "
            }
          ]
        },
        {
           "name": "update-engine.service",
           "mask": true
        },
        {
           "name" : "locksmithd.service",
           "mask" : true
        }
     ]
  },
  "networkd": {},
  "passwd": {}
}
