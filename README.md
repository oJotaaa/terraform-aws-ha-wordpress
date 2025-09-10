# ☁︎ Terraform AWS - WordPress em Alta Disponibilidade

[![Terraform](https://img.shields.io/badge/Terraform-v1.x-7B42BC?logo=terraform)](https://developer.hashicorp.com/terraform/downloads)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)



Este projeto provisiona uma infraestrutura de **WordPress altamente disponível** na **AWS**, utilizando **Terraform** para gerenciar todos os recursos em nuvem.  
O objetivo é demonstrar **resiliência, escalabilidade e tolerância a falhas**, simulando um ambiente de produção real.

---

## Arquitetura

A infraestrutura é composta pelos seguintes serviços:

- **VPC personalizada**
  - 2 Subnets públicas (Load Balancer)
  - 2 Subnets privadas (RDS, EFS e EC2)
  - Route Tables, Internet Gateway e NAT Gateway
- **Amazon RDS**
  - Banco MySQL
  - Single-AZ
  - Acesso restrito apenas às instâncias EC2
- **Amazon EFS**
  - Sistema de arquivos compartilhado entre as instâncias EC2
- **Auto Scaling Group (EC2)**
  - Baseado em Launch Template
  - User Data instala Docker, WordPress, monta EFS e conecta ao RDS
  - Escalamento automático baseado em CPU
- **Application Load Balancer (ALB)**
  - Distribui tráfego entre as instâncias
  - Health checks configurados
- **Security Groups (SG)**
  - **Internet ➜ Load Balancer:** O grupo de segurança do **ALB** deve permitir tráfego **HTTP** e **HTTPS** da Internet (0.0.0.0/0).
  - **Load Balancer ➜ Instâncias:** O grupo de segurança das **Instâncias** deve permitir tráfego **HTTP** e **HTTPS** apenas do **ALB**.
  - **Instâncias ➜ EFS:** O grupo de segurança do **EFS** deve permitir tráfego **NFS** apenas das **Instâncias EC2**.
  - **Instâncias ➜ RDS:** O grupo de segurança do **RDS** deve permitir tráfego **MySQL/Aurora** apenas das **Instâncias EC2**


## Pré-requisitos

Antes de iniciar, garanta que possui:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.x  
- Conta **AWS** ativa com permissões administrativas  
- [AWS CLI](https://aws.amazon.com/cli/) configurada  
- Chaves de acesso (`AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`)  


## Deploy da Infraestrutura
1. Clone o repositório e execute os comandos abaixo:
    ```bash
    git clone https://github.com/oJotaaa/terraform-aws-ha-wordpress.git
    ```
2. Navegue para a pasta raiz do projeto
    ```
    cd terraform-aws-ha-wordpress
    ```
3. Inicialize o Terraform para carregar os módulos e providers
    ```
    terraform init
    ```
4. Executando o comando abaixo você verá todo o plano de ação da Infraestrutura
    ```
    terraform plan
    ```

**Antes de subir a Infraestrutura para a AWS, siga os passos abaixo...**

## 🛑 Configuração de Variáveis Sensíveis e Apply

Este repositório contém um arquivo de exemplo chamado **`secrets.auto.tfvars.example`**.  
Você deve criar o seu próprio arquivo `secrets.auto.tfvars` na raiz do projeto.

1. Em seu terminal, copie o arquivo de exemplo:
   ```bash
   cp secrets.auto.tfvars.example secrets.auto.tfvars
2. Edite o `secrets.auto.tfvars` e substitua os valores de exemplo pelos seus:
    - Perfil AWS (aws-profile)
    - Usuário e senha do banco de dados
    - Tags que deseja associar aos recursos
3. Suba os recursos para a AWS:
    ```
    terraform apply
    ```

## 🌐 Acesso ao WordPress
Após a finalização do `terraform apply`, o terminal exibirá como saída o **DNS do Load Balancer**.
Esse será o endereço que você deve acessar no navegador para concluir a instalação e configuração inicial do WordPress.

Exemplo de saída:
```
Outputs:

alb_dns_name = "wordpress-alb-1234567890.us-east-1.elb.amazonaws.com"
```
Basta abrir esse endereço no navegador para acessar a página de instalação do WordPress.