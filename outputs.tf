# Apresenta o DNS para acesso ao site do wordpress
output "alb_dns_name" {
  description = "O endereço DNS público do Application Load Balancer"
  value       = aws_lb.wordpress_alb.dns_name
}