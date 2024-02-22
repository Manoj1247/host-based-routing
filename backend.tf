terraform {
  backend "s3" {
    bucket  = "host-based-routing" # Adjust the bucket name
    key     = "terraform.tfstate"
    region  = "us-east-1" # Adjust the region as needed
    encrypt = true
  }
}