output "id_master" {
  value = aws_security_group.locust_master.id
}

output "id_slave" {
  value = aws_security_group.locust_slave.id
}