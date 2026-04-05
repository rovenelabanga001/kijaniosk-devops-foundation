terraform {
  required_providers {
    google = {
        source = "hashicorp/google"
        version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "kijanikiosk-terraform-state-kijanikiosk"
    prefix = "staging"
  }
}

provider "google" {
    project= var.project_id
    region= var.region
}

locals {
  servers ={
    api = {
      machine_type = "e2-micro"
      port = 3000
    }
    payments = {
      machine_type = "e2-micro"
      port = 3001
    }
    logs = {
      machine_type = "e2-micro"
      port = 3002
    }
  }
  ssh_public_key = file(pathexpand(var.ssh_pub_key_file))
}

module "app_servers" {
  source = "./modules/app_server"
  for_each = local.servers  

  name = each.key
  machine_type = each.value.machine_type
  environment = var.environment
  project_id = var.project_id
  zone = var.zone
  ssh_user = var.ssh_user
  ssh_pub_key_file = var.ssh_pub_key_file
}
# resource "google_compute_instance" "kk_api" {
#   name = "kijanikiosk-api-staging"
#   machine_type = var.machine_type
#   zone = var.zone

#   tags = ["kijanikiosk", "http-server", "ssh-server"]

#   boot_disk {
#     initialize_params {
#       #image = "projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20260313"
#       image = data.google_compute_image.ubuntu_22_04.self_link
#       size  = 10
#       type  = "pd-standard"
#     }
#   }

#   network_interface {
#     network = "default"
#     access_config {
#       # empheral public IP - leave empty for auto assignment
#     }
#   }

#   metadata = {
#     ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
#   }

#   labels = {
#     environment = var.environment
#     owner = "amina"
#     project = "kijanikiosk"
#   }
# }

resource "google_compute_firewall" "allow_ssh" {
    name = "allow-ssh-kijanikiosk"
    network = "default"

    allow {
      protocol = "tcp"
      ports = ["22"]
    }

    #restrict SSH to engineer's IP only - change this when IP changes
    source_ranges = [var.ssh_source_ip]
    target_tags = ["ssh-server"]

    description = "Allow SSH from engineer IP only - kijanikiosk staging"
  
}

resource "google_compute_firewall" "allow_http" {
    name = "allow-http-kijanikiosk"
    network = "default"

    allow {
      protocol = "tcp"
      ports = ["80"]
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags = ["http-server"]

    description = "Allow HTTP from anywhere - kijanikiosk staging/prod"
  
}

data "google_compute_image" "ubuntu_22_04" {
    family = "ubuntu-2204-lts"
    project = "ubuntu-os-cloud"
}