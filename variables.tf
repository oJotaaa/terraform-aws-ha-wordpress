# Profile do SSO
variable "aws_profile" {
  description = "Nome do perfil AWS no ~/.aws/credentials"
  type = string
  default = ""
}

# Tags padrões
variable "default_tags" {
  description = "Tags padrões para os serviços"
  type = map(string)
  default = {}
}

# Nome para o user do RDS
variable "db_username" {
  description = "Nome do utilizador para a instância RDS"
  type = string
  default = "admin"
}

# Senha para o RDS
variable "db_password" {
  description = "Senha para o RDS"
  type = string
  sensitive = true
  default = ""
}

