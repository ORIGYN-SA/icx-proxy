environment              = "qa"
application_name         = "icx-proxy"
vps_name                 = "origyn-dev"
container_port           = 5000
task_definition_cpu      = null
task_definition_memory   = null
icx_container_cpu        = 256
icx_container_memory     = 512
enable_varnish           = false
varnish_container_cpu    = 128
varnish_container_memory = 256
service_desired_count    = 1
