terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "kijanikiosk-terraform-state-kijanikiosk"
    prefix = "friday-staging"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Data source: Ubuntu 22.04 LTS image ──────────────────────────────────────
data "google_compute_image" "ubuntu_22_04" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

# ── Server definitions ────────────────────────────────────────────────────────
locals {
  servers = {
    api = {
      machine_type = var.machine_type
      port         = 3000
    }
    payments = {
      machine_type = var.machine_type
      port         = 3001
    }
    logs = {
      machine_type = var.machine_type
      port         = 3002
    }
  }
}

# ── App server module — one instance per server definition ────────────────────
module "app_servers" {
  source   = "./modules/app_server"
  for_each = local.servers

  name             = each.key
  machine_type     = each.value.machine_type
  environment      = var.environment
  project_id       = var.project_id
  zone             = var.zone
  image            = data.google_compute_image.ubuntu_22_04.self_link
  ssh_user         = var.ssh_user
  ssh_pub_key_file = var.ssh_pub_key_file
  ssh_source_ip    = var.ssh_source_ip
}

# ── Firewall: Allow SSH from engineer IP only ─────────────────────────────────
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-kijanikiosk-friday"
  network = "default"
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.ssh_source_ip]
  target_tags   = ["ssh-server"]
  description   = "Allow SSH from engineer IP only — kijanikiosk friday"
}

# ── Firewall: Allow HTTP from anywhere ───────────────────────────────────────
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-kijanikiosk-friday"
  network = "default"
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
  description   = "Allow HTTP from anywhere — kijanikiosk friday"
}