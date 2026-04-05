terraform {
  backend "gcs" {
    bucket = "kijanikiosk-terraform-state-kijanikiosk"
    prefix = "staging/terraform.tfstate"
  }
}