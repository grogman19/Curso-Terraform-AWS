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

# Definimos un recurso de instancia EC2
resource "aws_instance" "sftp1" {
    ami = "ami-09e310d4361a3b13a"
    instance_type = "t2.micro"
    key_name = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.instance.id]
    subnet_id = element(data.aws_subnets.default.ids,0)
    tags = {
        Name = "SFTP Server 01"
    }
}

# Definimos un recurso EBS de storage de bloques
resource "aws_ebs_volume" "sftp" {
    availability_zone = var.availability_zone
    size = 4
    type = "gp3"
    encrypted = true
    tags = {
        Name = "sftp-ebs"
    }
}

# Definimos un recurso de volume attachment
resource "aws_volume_attachment" "sftp01" {
    device_name = "/dev/sdh"
    volume_id = aws_ebs_volume.sftp.id
    instance_id = aws_instance.sftp1.id
}

# Sacamos el comando directo para conectar por ssh a la instancia 01
output "sftp_server_01" {
    value = "ssh -l ec2-user ${aws_instance.sftp1.public_ip}"
}

/*

# Definimos un recurso de instancia EC2
resource "aws_instance" "sftp2" {
    ami = "ami-09e310d4361a3b13a"
    instance_type = "t2.micro"
    key_name = aws_key_pair.deployer.key_name
    vpc_security_group_ids = [aws_security_group.instance.id]
    subnet_id = element(data.aws_subnets.default.ids,1)
    tags = {
        Name = "SFTP Server 02"
    }
}

# Definimos un recurso load balancer
resource "aws_lb" "example" {
    name = "terraform-asgexample"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb.id]
}

# Definimos un recurso de target_group (equivalente a un pool de real servers)
resource "aws_lb_target_group" "asg" {
    name = "terraform-asg-example"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id
    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

# Recurso listener que define el servicio de escucha del balanceador lb_listener (virtual server) y respuesta en caso de fallo
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = 80
    protocol = "HTTP"
    # By default, return a simple 404 page
    default_action {
        type = "fixed-response"
        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code = 404
        }
    }
}

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

# Recurso launch_configuration que define como se lanza una instancia en un autoscaling group
resource "aws_launch_configuration" "example" {
    image_id = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance.id]
    user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF
    # Required when using a launch configuration with an ASG.
    lifecycle {
        create_before_destroy = true
    }
}

# Recurso autoscaling group para crear y destruir instancias de forma automática, de acuerdo a la demanda
resource "aws_autoscaling_group" "example" {
    launch_configuration = aws_launch_configuration.example.name
    vpc_zone_identifier = data.aws_subnets.default.ids
    # Lo metemos en el target_group que hemos creado para el balanceador
    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"
    min_size = 2
    max_size = 10
    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }
}

# Output para saber la url del balanceo
output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "The domain name of the load balancer"
}
*/