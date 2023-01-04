output "frontend_public_ip" {
  value = aws_eip.homelab_elastic_ip.public_ip
}
