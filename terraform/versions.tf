terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.48.0"
    }
    helm = {
      source  = "hashicorp/google"
      version = "~> 3.74.0"
    }
    kubernetes = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    mysql = {
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