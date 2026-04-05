variable "name" {
  description = "Service name: api, payments, or logs"
  type = string
}

variable "environment" {
  description = "Deployment environment: Staging or production"
  type = string
}

variable "project_id" {
    description = "GCP project id"
    type = string
}
variable "zone" {
    description = "GCP zone to deploy into"
    type = string
    default = "europe-west1-b"
}

variable "machine_type" {
    description = "GCP machine type"
    type = string
    default = "e2-micro"
}
variable "ssh_user" {
    description = "SSH user to add to instance metadata"
    type = string
}

variable "ssh_pub_key_file" {
  description = "Path to SSH public key file"
  type = string
}
