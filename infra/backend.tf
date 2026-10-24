terraform {
  backend "s3" {
    bucket  = "fiap-repairshop2"
    key     = "sqs/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
