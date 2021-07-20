terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.50.0"
    }
    gcp = {
      source  = "hashicorp/google"
      version = "~> 3.76.0"
    }
    null-provider = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    local-provider = {
      source  = "hashicorp/local"
      version = "~> 2.1.0"
    }
  }
  required_version = ">= 0.15"
  backend "gcs" {
    bucket = "workshops-tf-state-terraform"
    prefix = "terraform/state"
  }
}

provider "aws" {
  region = var.default_region
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}