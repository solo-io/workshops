terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.32.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 4.38.0"
    }
    null-provider = {
      source  = "hashicorp/null"
      version = "~> 3.1.1"
    }
    local-provider = {
      source  = "hashicorp/local"
      version = "~> 2.2.3"
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