terraform {
  backend "s3" {
    key     = "sqs/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
