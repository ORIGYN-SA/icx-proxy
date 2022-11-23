output "private_key" {
  value     = tls_private_key.temp.private_key_pem
  sensitive = true
}
output "master_web" {
  value = "http://${module.locust_master.locust_server_public_ip[0]}:8089"
}