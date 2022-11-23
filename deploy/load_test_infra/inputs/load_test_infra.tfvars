vps_name                    = "origyn-dev"
cluster_name                = "tf-icx-proxy-qa-load-testing"
locust_master_instance_type = "t3.medium"
locust_slave_instance_type  = "t3.medium"
slave_min_size_count        = 1
slave_max_size_count        = 1
root_volume_size            = "8"
root_volume_type            = "gp2"
root_volume_iops            = "100"
target_host                 = "https://exos-qa.origyn.network"

master_associate_public_ip_address = "true"
