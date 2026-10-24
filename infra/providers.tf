provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "RepairShop"
      Component   = "SQS-Messaging"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
