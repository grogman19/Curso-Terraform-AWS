# Configuramos terraform para guardar los estados en un bucket S3 que hemos creado previamente con el lock en DynamoDB
terraform {
    backend "s3" {
        bucket         = "terraform-backend-cdd-bucket"
        key            = "Ejercicio 2/terraform.tfstate"
        region         = "eu-west-1"
        dynamodb_table = "terraform-up-and-running-locks"
        encrypt        = true
    }
}

# Definimos la variable con el path a la key ssh
variable "ssh_key_path" {}

# Definimos la variable de la zona de la región
variable "region" {}

# Definimos la variable de la zona de disponibilidad
variable "availability_zone" {}

# Definimos el proveedor de cloud como AWS, y la región definida en la variable
provider "aws" {
    region = var.region
}

# Recurso de clave SSH en AWS
resource "aws_key_pair" "deployer" {
    key_name = "aibanez-test-key"
    public_key = file(var.ssh_key_path)
}

# Usamos el módulo VPC para crear un recurso VPC
module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    name = "vpc-main"
    cidr = "10.100.0.0/16"
    azs = [var.availability_zone]
    private_subnets = ["10.100.0.0/24", "10.100.1.0/24"]
    public_subnets = ["10.100.128.0/24", "10.100.129.0/24"]
    enable_dns_hostnames = true
    enable_dns_support = true
    enable_nat_gateway = false
    enable_vpn_gateway = false
    tags = { Terraform = "true", Environment = "dev" }
}

# Definimos un recurso de security group
resource "aws_security_group" "allow_ssh" {
    name = "allow_ssh/web"
    description = "Allow SSH, HTTP, and HTTPS inbound traffic"
    vpc_id = module.vpc.vpc_id
    # egress e ingress
    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
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

# Definimos una estructura data para obtener la info de una imagen AMI RedHat de AWS
data "aws_ami" "rhel_8_5" {
    most_recent = true
    owners = ["309956199498"] // Red Hat's Account ID
    filter {
        name   = "name"
        values = ["RHEL-8.5*"]
    }
    filter {
        name   = "architecture"
        values = ["x86_64"]
    }
    filter {
        name   = "root-device-type"
        values = ["ebs"]
    }
    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

# Creamos una estructura data para referenciar un fichero userdata.sh 
data "template_file" "userdata" {
 template = file("${path.module}/userdata.sh")
}

# Definimos un recurso de instancia EC2
resource "aws_instance" "web" {
    ami = data.aws_ami.rhel_8_5.id
    instance_type = "t2.micro"
    key_name = aws_key_pair.deployer.key_name
    user_data = data.template_file.userdata.rendered
    vpc_security_group_ids = [aws_security_group.allow_ssh.id]
    subnet_id = element(module.vpc.public_subnets,1)
    tags = {
        Name = "Web Server"
    }
}

# Definimos un recurso EBS de storage de bloques
resource "aws_ebs_volume" "web" {
    availability_zone = var.availability_zone
    size = 4
    type = "gp3"
    encrypted = true
    tags = {
        Name = "web-ebs"
    }
}

# Definimos un recurso de volume attachment
resource "aws_volume_attachment" "web" {
    device_name = "/dev/sdh"
    volume_id = aws_ebs_volume.web.id
    instance_id = aws_instance.web.id
}

# Mostramos el VPC ID obtenido como resultado
output "VPC-ID" {
    value = module.vpc.vpc_id
}

# Mostramos la subred de la VM como resultado
output "VPC-Subnet" {
    value = element(module.vpc.public_subnets,1)
}

# Sacamos la IP pública de la instancia desplegada
output "ip_instance" {
    value = aws_instance.web.public_ip
}

# Sacamos el comando directo para conectar por ssh a la instancia
output "ssh" {
    value = "ssh -l ec2-user ${aws_instance.web.public_ip}"
}
