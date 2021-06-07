terraform {
  backend "gcs" {
    bucket = "workshops-tf-state-terraform"
    prefix = "terraform/state"
  }
}