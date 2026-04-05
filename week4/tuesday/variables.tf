variable "project_id"{
    description = "GCP project id to deploy infrastructure to"
    type = string
    default = "kijanikiosk" 
}

variable "region"{
    description = "GCP region to deploy infrastructure to"
    type = string
    default = "europe-west1"
}

variable "zone"{
    description = "GCP zone within the region"
    type = string
    default = "europe-west1-b"
}

variable "machine_type" {
    description = "GCP machine for Kijanikiosk application servers"
    type = string
    default = "e2-micro"
}

variable "environment" {
  description = "Deployment environment: staging or production"
  type = string
  default = "staging"

  validation {
    condition = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production"
  }
}

variable "ssh_user" {
  description = "SSH username to add to the instance metadata"
  type = string

  # No default must be provided explicitly per environment
  # On GCP this is the username that will be created on the VM
}

variable "ssh_pub_key_file" {
    description = "Path to SSH public key file to authorize on the instance"
    type = string
  # No default — must be provided explicitly
  # Example: ~/.ssh/kijanikiosk-key.pub
}

variable "ssh_source_ip" {
    description = "Engineer IP adress allowed to SSH - format: x.x.x.x/32 "
    type = string
    # No default - Must be provided explicitly, changes per network
}