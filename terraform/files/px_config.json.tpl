{
  "clusterid": "${portworx_cluster_id}",
  "mgtiface" : "eth1",
  "dataiface" : "eth2",
  "kvdb": [
      "etcd:http://zk-1.zk:2379",
      "etcd:http://zk-2.zk:2379",
      "etcd:http://zk-3.zk:2379",
      "etcd:http://zk-4.zk:2379",
      "etcd:http://zk-5.zk:2379"
    ],
  "storage": {
    "devices": [
      "/dev/sdc"
    ],
    "journal_dev" : "/dev/sdd"
  }
}