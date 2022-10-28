# Configuramos terraform para guardar los estados en un bucket S3 que hemos creado previamente con el lock en DynamoDB
terraform {
    backend "s3" {
        bucket         = "terraform-backend-cdd-bucket"
        key            = "Ejercicio 3/terraform.tfstate"
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

# Definimos la variable del puerto del balanceador de carga
variable "server_port" {
    description = "The port the server will use for SFTP requests"
    type = number
}

# Definimos el proveedor de cloud como AWS, y la región definida en la variable
provider "aws" {
    region = var.region
}

# Recurso de clave SSH en AWS
resource "aws_key_pair" "deployer" {
    key_name = "aibanez-terraform-key"
    public_key = file(var.ssh_key_path)
}

# Definimos recursos de security group para las instancias y para el balanceador
resource "aws_security_group" "instance" {
    name = "terraform-sftp-instance"
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # Allow all outbound requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "alb" {
    name = "terraform-sftp-alb"
    # Allow inbound HTTP requests
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Definimos datas para obtener info del VPC y subredes por defecto
data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

# Creamos una estructura data para referenciar un fichero userdata.sh 
data "template_file" "userdata" {
 template = file("${path.module}/userdata.sh")
}

# Definimos un recurso de instancia EC2
resource "aws_instance" "sftp1" {
    ami = "ami-09e310d4361a3b13a"
    instance_type = "t2.micro"
    key_name = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.instance.id]
    subnet_id = element(data.aws_subnets.default.ids,0)
    user_data = data.template_file.userdata.rendered
    tags = {
        Name = "SFTP Server 01"
    }
}

# Creamos una segunda instancia EC2
resource "aws_instance" "sftp2" {
    ami = "ami-09e310d4361a3b13a"
    instance_type = "t2.micro"
    key_name = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.instance.id]
    subnet_id = element(data.aws_subnets.default.ids,0)
    user_data = data.template_file.userdata.rendered
    tags = {
        Name = "SFTP Server 02"
    }
}

# Definimos un recurso EBS de storage de bloques
resource "aws_ebs_volume" "sftp1" {
    availability_zone = var.availability_zone
    size = 4
    type = "gp3"
    encrypted = true
    tags = {
        Name = "sftp-ebs"
    }
}

# Definimos un recurso EBS de storage de bloques
resource "aws_ebs_volume" "sftp2" {
    availability_zone = var.availability_zone
    size = 4
    type = "gp3"
    encrypted = true
    tags = {
        Name = "sftp-ebs"
    }
}

# Definimos un recurso de volume attachment a las máquinas
resource "aws_volume_attachment" "sftp01" {
    device_name = "/dev/sdh"
    volume_id = aws_ebs_volume.sftp1.id
    instance_id = aws_instance.sftp1.id
}

# Definimos un recurso de volume attachment a las máquinas
resource "aws_volume_attachment" "sftp02" {
    device_name = "/dev/sdh"
    volume_id = aws_ebs_volume.sftp2.id
    instance_id = aws_instance.sftp2.id
}

# Definimos un recurso load balancer de tipo network
resource "aws_lb" "example" {
    name = "terraform-asgexample"
    load_balancer_type = "network"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb.id]
}

# Definimos un recurso de target_group (equivalente a un pool de real servers)
resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "TCP"
    vpc_id = data.aws_vpc.default.id
}

# Recurso listener que define el servicio de escucha del balanceador lb_listener (virtual server) y respuesta en caso de fallo
resource "aws_lb_listener" "sftp" {
    load_balancer_arn = aws_lb.example.arn
    port = 22
    protocol = "TCP"
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
        }
}

/*


# Recurso listener_rule que asocia el lb_listener con el target_group
resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100
    condition {
        path_pattern {
            values = ["*"]
        }
    }
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}

# Output para saber la url del balanceo
output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "The domain name of the load balancer"
}
*/

# Sacamos el comando directo para conectar por ssh a la instancia 01
output "sftp_server_01" {
    value = "ssh -l ec2-user ${aws_instance.sftp1.public_ip}"
}

# Sacamos el comando directo para conectar por ssh a la instancia 02
output "sftp_server_02" {
    value = "ssh -l ec2-user ${aws_instance.sftp2.public_ip}"
}