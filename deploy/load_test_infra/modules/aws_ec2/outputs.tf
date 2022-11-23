output "locust_server_public_ip" {
  value = var.associate_public_ip_address ? aws_instance.locust_server.*.public_ip : aws_instance.locust_server.*.private_ip
}
output "locust_server_private_ip" {
  value = aws_instance.locust_server.*.private_ip
}
output "locust_server_id" {
  value = aws_instance.locust_server.*.id
}