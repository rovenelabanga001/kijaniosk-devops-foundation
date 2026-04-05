variable "project_id" {
  description = "GCP project ID to deploy infrastructure into"
  type        = string
  default     = "kijanikiosk"
}

variable "region" {
  description = "GCP region to deploy infrastructure into"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP zone within the region"
  type        = string
  default     = "europe-west1-b"
}

variable "machine_type" {
  description = "GCP machine type for KijaniKiosk application servers"
  type        = string
  default     = "e2-micro"
}

variable "environment" {
  description = "Deployment environment: staging or production"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "ssh_user" {
  description = "SSH username to add to instance metadata"
  type        = string
}

variable "ssh_pub_key_file" {
  description = "Path to SSH public key file on the control node"
  type        = string
}

variable "ssh_source_ip" {
  description = "Engineer IP address allowed to SSH — format x.x.x.x/32"
  type        = string
}