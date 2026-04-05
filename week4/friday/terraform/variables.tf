variable "gcp_project" {
  description = "The ID of the google cloud project"
  type = string
}

variable "gcp_region" {
  description = "GCP Region"
  type = string
  default = "europe-west1"
}

variable "gcp_zone" {
  description = "GCP Zone"
  type = string
  default = "europe-west1-b"
}

variable "ssh_user" {
  description = "Local user"
  type = string
}

variable "ssh_pub_key_path" {
  description = "Path to your public SSH key"
  type = string
  default = "~/.ssh/id_rsa.pub"
}