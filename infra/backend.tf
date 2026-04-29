terraform {
  backend "s3" {
    bucket         = "capstone-sre-tfstate-591316258137"
    key            = "phase-01/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "capstone-sre-tflock"
    encrypt        = true
  }
}
