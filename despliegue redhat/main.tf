# Definimos el proveedor de cloud como AWS, y la región
provider "aws" {
    region = "eu-west-3"
}

# Definimos la variable con el path a la key ssh
variable "ssh_key_path" {}

# Definimos la variable de la zona de disponibilidad
variable "availability_zone" {}

# Recurso de clave SSH en AWS
resource "aws_key_pair" "deployer" {
    key_name = "deployer-key"
    public_key = file(var.ssh_key_path)
}

# Usamos el módulo VPC para crear un recurso VPC
module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    name = "vpc-main"
    cidr = "10.0.0.0/16"
    azs = [var.availability_zone]
    private_subnets = ["10.0.0.0/24", "10.0.1.0/24"]
    public_subnets = ["10.0.100.0/24", "10.0.101.0/24"]
    enable_dns_hostnames = true
    enable_dns_support = true
    enable_nat_gateway = false
    enable_vpn_gateway = false
    tags = { Terraform = "true", Environment = "dev" }
}

# Definimos un recurso de security group
resource "aws_security_group" "allow_ssh" {
    name = "allow_ssh"
    description = "Allow SSH inbound traffic"
    vpc_id = module.vpc.vpc_id
    # egress e ingress
    ingress {
        description = "SSH from VPC"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
     egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "allow_ssh"
    }
}