variable "name" {
  description = "Service name: api, payments or logs"
  type = string
}

variable "environment" {
  description = "Deployment environment: Staging or Production"
  type = string
}

variable "project_id" {
  description = "GCP project ID to deploy into"
  type = string
}

variable "zone" {
  description = "GCP zone to deploy the instance to"
  type = string
}

variable "machine_type" {
  description = "GCP machine type for the instance"
  type = string
  default = "e2-micro"
}

variable "image" {
  description = "Boot disk image self_link from data source"
  type = string
}

variable "ssh_user" {
  description = "SSH username to add to instance metadata"
  type = string
}

variable "ssh_pub_key_file" {
  description = "Path to SSH public key file on the control node"
  type = string
}

variable "ssh_source_ip" {
  description = "Engineer IP allowed to SSH -format x.x.x.x/32"
  type = string
}