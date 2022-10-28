# Definimos la variable de la zona de la región
variable "region" {}

# Definimos el proveedor de cloud como AWS, y la región definida en la variable
provider "aws" {
    region = var.region
}

# Definimos la variable del nombre del bucket S3
variable "bucket_name" {
    default = "My bucket"
}

# Definimos la variable del valor de la lista de acceso
variable "acl_value" {
    default = "private"
}

# Recurso de Bucket S3
resource "aws_s3_bucket" "b" {
    bucket = var.bucket_name
    tags = {
        Name        = "Terraform Bucket"
        Environment = "Test"
    }
}

# Recurso de versionado de bucket S3
resource "aws_s3_bucket_versioning" "versioning_example" {
    bucket = aws_s3_bucket.b.id
    versioning_configuration {
        status = "Enabled"
    }
}

# Recurso de encriptación de bucket S3
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
    bucket = aws_s3_bucket.b.id
    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
        }
    }
}

# Recurso de bloqueo de acceso público al bucket S3
resource "aws_s3_bucket_public_access_block" "public_access" {
    bucket                  = aws_s3_bucket.b.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# Recurso de tabla de DynamoDB para el almacenar el locking
resource "aws_dynamodb_table" "terraform_locks" {
    name         = "terraform-up-and-running-locks"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "LockID"
    attribute {
        name = "LockID"
        type = "S"
    }
}

# Output del nombre de recurso del bucket S3
output "s3_bucket_arn" {
    value       = aws_s3_bucket.b.arn
    description = "The ARN of the S3 bucket"
}

# Output del nombre de la tabla de DynamoDB 
output "dynamodb_table_name" {
    value       = aws_dynamodb_table.terraform_locks.name
    description = "The name of the DynamoDB table"
}
