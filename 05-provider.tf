terraform {
  required_providers {
    aws = {
      version = ">= 4.16.0"
      source = "hashicorp/aws"
    }
  }
  required_version = "~> 1.2.0"
}

provider aws {
    region = "eu-central-1"
}