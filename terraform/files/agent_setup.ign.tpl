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
        "path": "/etc/sysctl.d/sysctl.conf",
        "contents": {
          "source": "data:,net.ipv4.tcp_keepalive_time%3D3600",
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
          "source": "data:,127.0.0.1%09localhost%0A%3A%3A1%09%09localhost%0A${my_ip}%20${vm_hostname}",
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
